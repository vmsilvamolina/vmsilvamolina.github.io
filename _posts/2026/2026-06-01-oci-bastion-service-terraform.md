---
title: 'OCI Bastion Service with Terraform: SSH and Port Forwarding'
author: Victor Silva
date: 2026-06-01T17:32:00+00:00
layout: post
permalink: /oci-bastion-service-terraform/
excerpt: "OCI Bastion Service with Terraform: Bastion plugin setup, managed SSH and port forwarding sessions, and security list rules scoped to the bastion's /32 IP."
categories:
  - OCI
  - Security
tags:
  - oci-bastion
  - terraform
  - oracle-cloud
  - security
  - ssh
  - iac
  - cloud-security
  - oci-bastion-plugin
  - oci-port-forwarding
  - oracle-cloud-infrastructure
---

You've just deployed a private compute instance — no public IP, sits in a private subnet, exactly as it should be. Now you need to SSH in to run a diagnostic or deploy a hotfix. The standard answers are a VPN, a self-managed jump host, or a bastion VM you're responsible for hardening, patching, and keeping alive. Every one of them is either slow to set up or a permanent operational burden. This post covers the OCI Bastion Service with Terraform as the managed alternative to all of them.

The jump host problem is the one nobody talks about until the on-call engineer at 2am realizes the bastion VM is the instance that's down.

OCI Bastion Service is Oracle's fully managed answer to this. No compute to provision or maintain. No VM to patch. Sessions are time-limited (30 minutes to 3 hours maximum), every session creation and deletion lands in OCI Audit, and the service integrates natively with IAM and Cloud Guard. The cost is zero beyond the resources you already have.

This post builds the entire setup with Terraform, end to end: a private compute instance with the Bastion plugin enabled at launch, the bastion resource, both a Managed SSH session and a Port Forwarding session for a MySQL endpoint, and security list rules scoped precisely to the bastion's private endpoint IP. We will also cover the gaps that the official documentation leaves open — the `agent_config` block that the OCI Terraform examples omit, the security list rule that must reference `private_endpoint_ip_address` rather than a subnet CIDR, and the `output` blocks that generate the exact SSH commands you need so you never have to construct them manually.

## How OCI Bastion Service Works

Before writing a single line of Terraform it's worth understanding the architecture clearly, because the session types have different requirements and different failure modes.

OCI Bastion creates a managed host inside Oracle's infrastructure, injected into the private subnet you specify via a private endpoint. That endpoint gets an IP address inside your VCN — the `private_endpoint_ip_address` attribute in Terraform. Traffic from your workstation goes to `host.bastion.<region>.oci.oraclecloud.com` over port 22, reaches the managed bastion host, and is relayed to the target.

{% highlight text %}
[Engineer Laptop] ──SSH (port 22)──► host.bastion.<region>.oci.oraclecloud.com
                                                  │
                                        [OCI Managed Bastion Host]
                                        private_endpoint_ip: 10.0.0.X
                                                  │
                                ┌─────────────────┴───────────────────┐
                                ▼                                     ▼
                      [Private Instance]                 [Private DB / Service]
                      (Managed SSH)                      (Port Forwarding)
                      10.0.1.X:22                        10.0.2.X:3306
{% endhighlight %}

One bastion maps to one VCN. The maximum concurrent active sessions is 20. Sessions have a hard TTL cap of 3 hours — there is no extension mechanism, which is by design.

### Session Types

There are three session types. This post implements the two that cover the vast majority of real-world use cases.

**Managed SSH** is for direct SSH access to a compute instance. The bastion temporarily injects your public key into the `authorized_keys` file on the target instance, establishes the session, and removes the key when the TTL expires. This requires the Oracle Cloud Agent with the Bastion plugin running on the target. The target must have PubkeyAuthentication enabled in `sshd_config` (it is by default on Oracle Linux images). No permanent key material is left on the instance.

**Port Forwarding** opens a TCP relay from a local port on your workstation to any IP and port reachable from inside the VCN — a MySQL endpoint, an RDP listener, an Autonomous Database private endpoint, another instance's SSH port. No agent required on the target. This is the session type for databases, Windows hosts, and anything that isn't a Linux compute instance managed by the Oracle Cloud Agent.

**Dynamic Port Forwarding (SOCKS5)** turns the bastion into a full SOCKS5 proxy for the VCN. It is a valid advanced use case but out of scope for this post.

## Prerequisites

You will need:

- OCI CLI installed and configured (`oci --version` should return 3.x or higher)
- Terraform >= 1.5 with the OCI provider (`hashicorp/oci >= 6.0`)
- Permissions to create compute instances, bastions, and security lists in the target compartment
- An SSH key pair. Generate a dedicated one for bastion use rather than reusing your compute key:

{% highlight bash %}
ssh-keygen -t rsa -b 4096 -f ~/.ssh/bastion_key -C "oci-bastion"
{% endhighlight %}

Verify the OCI CLI is working and that you can reach the bastion API:

{% highlight bash %}
oci --version
oci bastion bastion list --compartment-id $COMPARTMENT_ID
{% endhighlight %}

A critical note on OpenSSH version compatibility. OpenSSH 8.8 (released October 2021) deprecated RSA-SHA1 signatures. OCI Bastion's managed host still presents RSA-SHA1 in its host key negotiation. If you are on macOS Monterey or later, or any modern Linux distribution, your SSH client will refuse the connection with a `no matching host key type found` error.

Add the following block to your `~/.ssh/config` before attempting any bastion connections:

{% highlight text %}
Host host.bastion.*.oci.oraclecloud.com
    HostKeyAlgorithms +ssh-rsa
    PubkeyAcceptedAlgorithms +ssh-rsa
    ServerAliveInterval 120
    ServerAliveCountMax 3
{% endhighlight %}

The `ServerAliveInterval` setting prevents the bastion from disconnecting idle sessions after approximately five minutes, which is the default TCP idle timeout. Without it, a long-running `kubectl exec` or `scp` through the tunnel will drop silently.

## IAM Policies

The bastion service requires two sets of policies: permissions for the humans creating and using sessions, and `instance-agent-plugins` read access to allow session creation to verify the Bastion plugin state. If you are building these from scratch, the post on [OCI IAM with Terraform: compartments, dynamic groups, and instance principals](/oci-iam-terraform/) covers the foundation you need before writing bastion-specific policies.

{% highlight text %}
Allow group BastionUsers to use bastion in compartment Production
Allow group BastionUsers to read instances in compartment Production
Allow group BastionUsers to manage bastion-session in compartment Production
Allow group BastionUsers to read subnets in compartment Production
Allow group BastionUsers to read instance-agent-plugins in compartment Production
Allow group BastionUsers to read vnic-attachments in compartment Production
Allow group BastionUsers to read vnics in compartment Production
{% endhighlight %}

The `instance-agent-plugins` read permission is the one most commonly omitted, and its absence produces a confusing error when creating Managed SSH sessions: the session creation API call fails to validate the plugin state and returns a generic permissions error. Include it from the start.

For high-privilege targets — production databases, financial backends — scope the session management permission to specific instance OCIDs and OS usernames rather than the entire compartment:

{% highlight text %}
Allow group SalesAdmins to manage bastion-session in compartment SalesApps
  where ALL {
    target.resource.ocid = '<specific_instance_ocid>',
    target.bastion-session.username = 'opc'
  }
{% endhighlight %}

This policy allows `SalesAdmins` to create sessions only to a named instance and only as `opc`. Any attempt to create a session targeting a different instance or using a different username is denied at the IAM layer.

## Implementing the Full Stack with Terraform

Let's implement everything. We will build a `bastion.tf` for the bastion resource and sessions, an `instance.tf` for the compute target, a `security.tf` for the network rules, and `outputs.tf` for the SSH commands.

### Variables

Start with `variables.tf`:

{% highlight hcl %}
variable "compartment_id" {
  description = "Compartment where bastion and compute resources are created"
  type        = string
}

variable "vcn_id" {
  description = "VCN OCID"
  type        = string
}

variable "private_subnet_id" {
  description = "Private subnet where the bastion endpoint and target instance will be placed"
  type        = string
}

variable "availability_domain" {
  description = "Availability domain for the compute instance"
  type        = string
}

variable "oracle_linux_image_ocid" {
  description = "Oracle Linux image OCID for the region"
  type        = string
}

variable "region" {
  description = "OCI region identifier (e.g. us-phoenix-1)"
  type        = string
}

variable "admin_cidr_allowlist" {
  description = "List of CIDR blocks allowed to connect to the bastion (never use 0.0.0.0/0)"
  type        = list(string)
}

variable "compute_ssh_public_key_path" {
  description = "Path to the SSH public key for the compute instance OS user"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "bastion_ssh_public_key_path" {
  description = "Path to the SSH public key for bastion sessions (use a dedicated key)"
  type        = string
  default     = "~/.ssh/bastion_key.pub"
}

variable "mysql_private_endpoint_fqdn" {
  description = "Private FQDN of the MySQL endpoint for port forwarding"
  type        = string
}
{% endhighlight %}

### Compute Instance with the Bastion Plugin

This is where most existing Terraform examples fall short. Creating a compute instance without the `agent_config` block means the Bastion plugin starts in a disabled state. You can enable it manually in the console later, but then you have drift between your Terraform state and the actual instance configuration, and you will wait 10 minutes for the plugin to activate before your first Managed SSH session can work.

The correct approach is to declare the plugin as `ENABLED` at instance creation time:

{% highlight hcl %}
resource "oci_core_instance" "private_instance" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  shape               = "VM.Standard.E4.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 8
  }

  source_details {
    source_type = "image"
    source_id   = var.oracle_linux_image_ocid
  }

  display_name = "private-app-server"

  create_vnic_details {
    assign_public_ip = false
    subnet_id        = var.private_subnet_id
  }

  metadata = {
    ssh_authorized_keys = file(var.compute_ssh_public_key_path)
  }

  agent_config {
    plugins_config {
      desired_state = "ENABLED"
      name          = "Bastion"
    }
  }

  freeform_tags = {
    "managed-by" = "terraform"
    "team"       = "devsecops"
  }
}
{% endhighlight %}

The `agent_config` block with `plugins_config` is documented but absent from virtually every Terraform example you will find in the OCI documentation. Without it, `terraform apply` creates the instance without enabling the plugin, and when you try to create a Managed SSH session you get a `PLUGIN_NOT_RUNNING` error that points you back to the console.

The instance must also have a route to OCI service endpoints so the Oracle Cloud Agent can communicate with the bastion API. For instances in a private subnet, this means a Service Gateway configured with "All OCI Services" in the route table — not just "Object Storage". If the agent cannot reach the API, the plugin status will appear as `STOPPED` even after the correct `agent_config` is set.

### Bastion Resource

{% highlight hcl %}
resource "oci_bastion_bastion" "main" {
  bastion_type     = "STANDARD"
  compartment_id   = var.compartment_id
  target_subnet_id = var.private_subnet_id
  name             = "prod-bastion"

  client_cidr_block_allow_list = var.admin_cidr_allowlist
  max_session_ttl_in_seconds   = 3600
  dns_proxy_status             = "ENABLED"

  freeform_tags = {
    "managed-by" = "terraform"
    "team"       = "devsecops"
  }
}
{% endhighlight %}

`client_cidr_block_allow_list` restricts which source IPs can connect to the bastion. This is your first line of defense — restrict it to the known IP ranges of your administrators. We will return to this in the best practices section.

`dns_proxy_status = "ENABLED"` is required for port forwarding sessions that use a FQDN as the target (`target_resource_fqdn`) rather than a raw private IP. MySQL DB systems and Autonomous Databases expose private endpoints by FQDN, not IP. If you need to tunnel to those endpoints and `dns_proxy_status` is `DISABLED`, the FQDN target will fail.

### Managed SSH Session

{% highlight hcl %}
resource "oci_bastion_session" "managed_ssh" {
  bastion_id   = oci_bastion_bastion.main.id
  display_name = "admin-ssh-session"

  key_details {
    public_key_content = file(var.bastion_ssh_public_key_path)
  }

  target_resource_details {
    session_type                               = "MANAGED_SSH"
    target_resource_id                         = oci_core_instance.private_instance.id
    target_resource_operating_system_user_name = "opc"
    target_resource_port                       = 22
  }

  session_ttl_in_seconds = 3600
}
{% endhighlight %}

The `public_key_content` here is the public key that will be injected into the instance's `authorized_keys`. You should use a dedicated key pair for bastion sessions, not the same key you used in `compute_ssh_public_key_path`. This way, if you need to revoke bastion access you rotate the bastion key without affecting the instance's permanent key configuration.

### Port Forwarding Session — MySQL

{% highlight hcl %}
resource "oci_bastion_session" "mysql_tunnel" {
  bastion_id   = oci_bastion_bastion.main.id
  display_name = "mysql-port-forward"

  key_details {
    public_key_content = file(var.bastion_ssh_public_key_path)
  }

  target_resource_details {
    session_type             = "PORT_FORWARDING"
    target_resource_fqdn     = var.mysql_private_endpoint_fqdn
    target_resource_port     = 3306
  }

  session_ttl_in_seconds = 1800
}
{% endhighlight %}

Port Forwarding sessions do not require `target_resource_id` — you can target any IP or FQDN reachable from within the VCN, not just compute instances. You can use either `target_resource_fqdn` or `target_resource_private_ip_address` depending on what you have available. Autonomous Databases require FQDN. MySQL DB systems can use either.

The 1800-second TTL (30 minutes) is intentional for a database tunnel. You should not leave an open database port forwarding tunnel alive longer than your working session requires.

### Security List Scoped to the Bastion Private Endpoint

This is the second gap in most Terraform examples. Tutorials typically show a security list rule with `source = "0.0.0.0/0"` for SSH ingress, or a rule sourced from the entire subnet CIDR. The correct rule uses the bastion's `private_endpoint_ip_address` — a `/32` from the specific IP the bastion was assigned inside your VCN.

The beauty of this approach is that Terraform can reference the attribute directly on the bastion resource, keeping the rule tight without you needing to know or hardcode the IP:

{% highlight hcl %}
resource "oci_core_security_list" "target_subnet_sl" {
  compartment_id = var.compartment_id
  vcn_id         = var.vcn_id
  display_name   = "target-subnet-sl"

  # Allow SSH from bastion private endpoint only
  ingress_security_rules {
    protocol    = "6"
    source      = "${oci_bastion_bastion.main.private_endpoint_ip_address}/32"
    source_type = "CIDR_BLOCK"
    description = "Allow SSH from OCI Bastion private endpoint"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # Allow MySQL tunnel from bastion private endpoint
  ingress_security_rules {
    protocol    = "6"
    source      = "${oci_bastion_bastion.main.private_endpoint_ip_address}/32"
    source_type = "CIDR_BLOCK"
    description = "Allow MySQL tunnel from OCI Bastion private endpoint"

    tcp_options {
      min = 3306
      max = 3306
    }
  }

  freeform_tags = {
    "managed-by" = "terraform"
  }
}
{% endhighlight %}

The `private_endpoint_ip_address` attribute is populated by OCI after the bastion reaches `ACTIVE` state. Terraform handles the dependency automatically — the security list will not be created until the bastion is active and the attribute is available.

If you use NSGs instead of security lists, the same `/32` source approach applies to the `oci_core_network_security_group_security_rule` resource.

### Outputs — Ready-to-Run SSH Commands

This is the third gap. The bastion session OCID is the username in the SSH command to the bastion host. Without an output block you need to navigate to the console to copy it. With outputs, `terraform output` hands you the complete command, ready to paste.

{% highlight hcl %}
output "managed_ssh_command" {
  description = "SSH command to connect to the private instance via Managed SSH session"
  value = <<-EOT
    ssh -i <private_key_path> \
      -o ProxyCommand="ssh -i <private_key_path> -W %h:%p -p 22 ${oci_bastion_session.managed_ssh.id}@host.bastion.${var.region}.oci.oraclecloud.com" \
      -p 22 opc@${oci_core_instance.private_instance.private_ip}
  EOT
}

output "mysql_tunnel_command" {
  description = "SSH command to open the MySQL port forwarding tunnel (use 127.0.0.1:3306 after running)"
  value = <<-EOT
    ssh -i <private_key_path> -N \
      -L 127.0.0.1:3306:${var.mysql_private_endpoint_fqdn}:3306 \
      -p 22 ${oci_bastion_session.mysql_tunnel.id}@host.bastion.${var.region}.oci.oraclecloud.com
  EOT
}

output "bastion_private_endpoint_ip" {
  description = "Bastion private endpoint IP — used in security list rules"
  value       = oci_bastion_bastion.main.private_endpoint_ip_address
}
{% endhighlight %}

Replace `<private_key_path>` with the path to the private key matching the public key you passed in `bastion_ssh_public_key_path`. In a production setup you would template this with the actual path, but outputting the literal string is safer than outputting a file path that only works on your specific machine.

## Testing and Validation

### Verify the Bastion Plugin is Running

After `terraform apply` completes, wait approximately 10 minutes for the Oracle Cloud Agent to register the Bastion plugin with the service. This is not a Terraform state issue — the agent needs time to pull its configuration and start the plugin process. Running `terraform apply` successfully does not mean the plugin is ready.

{% highlight bash %}
export INSTANCE_ID=$(terraform output -raw instance_ocid 2>/dev/null || echo "ocid1.instance.oc1....")
export COMPARTMENT_ID=ocid1.compartment.oc1..aaaa...

oci instance-agent plugin get \
  --instanceagent-id $INSTANCE_ID \
  --compartment-id $COMPARTMENT_ID \
  --plugin-name Bastion \
  --query 'data.{status: "status", name: name}'
{% endhighlight %}

The expected response is `"status": "RUNNING"`. If it shows `STOPPED` after 15 minutes, verify that the instance route table has a Service Gateway route for "All OCI Services". Connectivity to OCI API endpoints is what the agent needs; without it the plugin cannot register.

### Verify the Bastion is Active

{% highlight bash %}
export BASTION_ID=$(terraform output -raw bastion_id 2>/dev/null || echo "ocid1.bastion.oc1....")

oci bastion bastion get \
  --bastion-id $BASTION_ID \
  --query 'data.{"lifecycle-state": "lifecycle-state", name: name}'
{% endhighlight %}

Expected: `"lifecycle-state": "ACTIVE"`. The bastion takes 2–3 minutes to reach ACTIVE state after creation. Terraform waits for this automatically.

### Verify Sessions are Active Before Connecting

{% highlight bash %}
export MANAGED_SSH_SESSION_ID=ocid1.bastionsession.oc1....
export MYSQL_SESSION_ID=ocid1.bastionsession.oc1....

# Check Managed SSH session state
oci bastion session get \
  --session-id $MANAGED_SSH_SESSION_ID \
  --query 'data.{"lifecycle-state": "lifecycle-state", "display-name": "display-name"}'

# Check Port Forwarding session state
oci bastion session get \
  --session-id $MYSQL_SESSION_ID \
  --query 'data.{"lifecycle-state": "lifecycle-state"}'
{% endhighlight %}

Expected: `"lifecycle-state": "ACTIVE"`. A session in `CREATING` state will not yet accept connections — wait for it to transition. Sessions in `DELETED` or `EXPIRED` state are past their TTL.

### Connecting via Managed SSH

Once the plugin is RUNNING and the session is ACTIVE, run the output from `terraform output managed_ssh_command` with your private key path substituted:

{% highlight bash %}
ssh -i ~/.ssh/bastion_key \
  -o ProxyCommand="ssh -i ~/.ssh/bastion_key -W %h:%p -p 22 ocid1.bastionsession.oc1...@host.bastion.us-phoenix-1.oci.oraclecloud.com" \
  -p 22 opc@10.0.1.23
{% endhighlight %}

The ProxyCommand establishes the outer connection to the bastion host using the session OCID as the username. The bastion then relays the inner connection to the private instance.

### Opening the MySQL Port Forwarding Tunnel

{% highlight bash %}
# Run in background or a separate terminal — this command does not return
ssh -i ~/.ssh/bastion_key -N \
  -L 127.0.0.1:3306:my-db.private.mysql.database.oci.oraclecloud.com:3306 \
  -p 22 ocid1.bastionsession.oc1...@host.bastion.us-phoenix-1.oci.oraclecloud.com
{% endhighlight %}

Once the tunnel is open, your MySQL client connects to `127.0.0.1:3306` as if it were a local port. The bastion relays the traffic to the private endpoint inside the VCN.

{% highlight bash %}
mysql -h 127.0.0.1 -P 3306 -u admin -p
{% endhighlight %}

For SSH two-hop access (when you need to reach an instance that is not managed by the Oracle Cloud Agent, for example a Windows instance via RDP), use a local port other than 22 — port 22 is already in use by your SSH client:

{% highlight bash %}
# Open tunnel: local port 7100 → instance port 22
ssh -i ~/.ssh/bastion_key -N \
  -L 127.0.0.1:7100:10.0.1.23:22 \
  -p 22 ocid1.bastionsession.oc1...@host.bastion.us-phoenix-1.oci.oraclecloud.com

# In another terminal, SSH through the tunnel
ssh -i ~/.ssh/compute_key -p 7100 opc@127.0.0.1
{% endhighlight %}

### Using OCI CLI to Create Sessions on Demand

After the bastion is provisioned with Terraform, individual sessions can be created with the OCI CLI rather than through Terraform — particularly useful for short-lived ad-hoc access:

{% highlight bash %}
export BASTION_ID=ocid1.bastion.oc1....

# Create a Managed SSH session
oci bastion session create-managed-ssh \
  --bastion-id $BASTION_ID \
  --display-name admin-debug-session \
  --target-resource-id $INSTANCE_ID \
  --target-os-username opc \
  --target-port 22 \
  --ssh-public-key-file ~/.ssh/bastion_key.pub \
  --session-ttl-in-seconds 3600

# Create a Port Forwarding session
oci bastion session create-port-forwarding \
  --bastion-id $BASTION_ID \
  --display-name mysql-tunnel \
  --target-private-ip 10.0.2.50 \
  --target-port 3306 \
  --ssh-public-key-file ~/.ssh/bastion_key.pub \
  --session-ttl-in-seconds 1800
{% endhighlight %}

The OCI CLI approach works well in automation scripts and CI/CD pipelines where you need to open a session, run a command, and let the session expire — without managing it as long-lived Terraform state.

## Best Practices

**Scope the security list rule to `private_endpoint_ip_address/32`, not the subnet CIDR.** The bastion's private endpoint IP is a specific /32. A rule that permits ingress from the entire private subnet (`10.0.0.0/24`) allows any instance in that subnet to connect to port 22 on your target — that is not what you want. Reference `oci_bastion_bastion.main.private_endpoint_ip_address` directly in Terraform and you get a tight rule automatically, no manual IP lookup required.

**Never use `0.0.0.0/0` in `client_cidr_block_allow_list`.** The CIDR allowlist is the first hop restriction — it controls which source IPs the bastion will even accept connections from. Setting it to `0.0.0.0/0` means anyone on the internet who knows a valid session OCID can attempt to connect. Restrict it to the known IP ranges of your administrators, or to your organization's VPN exit IPs.

**Generate a dedicated SSH key pair per session for sensitive targets.** For routine admin access, a shared team bastion key is acceptable. For production databases, financial systems, or any target that carries PCI/SOC2 scope, generate a fresh key pair per session. The private key is used once and discarded. This eliminates the risk of a stolen bastion key being used to open unauthorized sessions.

**Set `dns_proxy_status = "ENABLED"` from the start.** Even if your first use case targets a raw private IP, you will eventually need to tunnel to a MySQL DB system or Autonomous Database that only exposes a FQDN endpoint. Changing `dns_proxy_status` after bastion creation requires destroying and recreating the bastion, which means all existing sessions are lost. Enable it on day one.

**Monitor `CreateSession` and `DeleteSession` audit events.** OCI Audit captures every bastion session lifecycle event. Route these to OCI Events or Logging Analytics and alert on session creation outside business hours, sessions created by service accounts that normally only use APIs, or sessions targeting high-value instances. This is the most useful signal for detecting abuse — OCI Bastion is built for access, so the audit trail of who accessed what and when is your primary detective control. For broader detection coverage on top of bastion audit events, [OCI Cloud Guard custom detection rules](/oci-cloud-guard-detection-rules/) let you build responder rules that fire on specific audit conditions across the tenancy.

**Keep the plugin activation delay in mind for automation.** If you use Terraform to provision an instance and immediately try to create a Managed SSH session to it in the same apply or a subsequent pipeline step, you will hit the plugin activation delay. The Oracle Cloud Agent needs approximately 10 minutes after the `agent_config` is applied before the Bastion plugin registers as RUNNING. Build this wait into your pipeline with a `oci instance-agent plugin get` polling loop, or use Port Forwarding sessions for the initial provisioning phase.

**Add SSH config entries before your first connection attempt.** The `~/.ssh/config` block for `HostKeyAlgorithms +ssh-rsa` and `ServerAliveInterval 120` is not optional on modern systems — it is a prerequisite. Without it, every engineer on the team will hit the RSA-SHA1 rejection error at least once, and it is not obvious from the error message what the fix is.

## Conclusion

With the Terraform configuration in this post you have the complete OCI Bastion stack managed as code: a private compute instance with the Bastion plugin declared at launch, a bastion resource with a scoped client CIDR allowlist, Managed SSH and Port Forwarding sessions, and security list rules locked down to the bastion's `/32` private endpoint IP. The output blocks give you the exact SSH commands for both session types immediately after `terraform apply`, with no manual console navigation required.

The three gaps this post fills — the `agent_config` block at instance creation, the security list rule scoped to `private_endpoint_ip_address` rather than a subnet CIDR, and the SSH command output blocks — are the difference between a bastion setup that works the first time and one that requires two hours of debugging before the first connection goes through.

The natural next step is integrating session creation into your incident response runbooks: a short OCI CLI script that provisions a session, outputs the SSH command, and schedules its own expiry notification via OCI Events. Zero standing access, full audit trail, no jump host to maintain. For the instances this bastion protects, pairing with [OCI Vulnerability Scanning Service with Terraform](/oci-vulnerability-scanning-terraform/) closes the loop on both access control and CVE visibility for your private compute fleet.

Happy scripting!
