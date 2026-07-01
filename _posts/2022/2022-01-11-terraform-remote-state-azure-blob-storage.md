---
title: "Terraform remote state with Azure Blob Storage"
author: Victor Silva
date: 2022-01-11T09:33:47+00:00
layout: post
permalink: /terraform-remote-state-azure-blob-storage/
excerpt: "How to configure Terraform remote state backend using Azure Blob Storage — including state locking, workspace patterns, and securing the backend with managed identity."
categories:
  - Terraform
  - Azure
tags:
  - Terraform
  - Azure
  - IaC
  - Azure Storage
  - DevOps
---

Local Terraform state works perfectly fine when you're learning the tool or building something by yourself. You run `terraform apply`, the state file lands in your working directory as `terraform.tfstate`, and life is simple. The moment you introduce a second team member or a CI/CD pipeline into the picture, that setup breaks immediately. Two people run `terraform apply` at the same time, both read the same stale state file, both believe they're the sole owner of the world, and the results range from a failed apply to genuinely corrupted infrastructure state. That's not a theoretical risk — it's the first production incident most teams have with Terraform.

Remote state in Azure Blob Storage solves this cleanly. The state file lives in a shared, durable location that everyone — teammates, pipelines, automation — reads and writes from. Azure Blob Storage provides a native lease mechanism that acts as a distributed lock: only one `terraform apply` can hold the lease at a time, and any concurrent attempt is blocked until the lock is released. You also get versioning at the storage layer, so every state mutation is a recoverable point in time. And since Terraform state files frequently contain sensitive values — connection strings, passwords, private keys — keeping that file in a properly configured storage account (private access, encryption at rest, network controls) is a significant security improvement over checking it into a git repository.

This post walks through the complete setup: creating the storage backend, configuring the Terraform `azurerm` backend block, the authentication options available as of early 2022, the workspace pattern for managing multiple environments, and the security hardening steps you should apply to any production state backend.

## Why remote state matters

Before diving into the implementation, let's be specific about what you're getting with each remote state capability.

**Shared access** means that every member of the team and every pipeline job reads from and writes to the same file. There's no "sync my state" step, no copying files around, no risk of someone working from a stale local copy. The state is the canonical truth about what Terraform last applied.

**State locking** via Azure Blob Storage lease is particularly elegant. When Terraform starts an operation that modifies state (plan with `-out`, apply, destroy), it acquires a lease on the blob. Any other process that tries to acquire a lease on the same blob gets an error immediately. The lock is automatically released when the operation finishes or if the process crashes (leases have a TTL). This is the same guarantee you'd get from DynamoDB state locking in AWS, but Azure Blob leases handle it natively — there's no separate locking table to manage.

**State versioning** gives you point-in-time recovery. Azure Blob Storage versioning keeps every previous version of the blob when a new one is written. If a bad apply leaves your state in a broken state, you can restore the previous version directly from the Azure portal or CLI without any Terraform-specific tooling.

**Sensitive data protection** matters more than people realize until they look at a state file for the first time. Terraform stores everything it creates in state, including the plaintext values of resource attributes that happen to be sensitive — database passwords, storage access keys, private key material. A storage account with private access disabled, encryption at rest enabled, and network access restricted to your CI/CD environment is a much safer home for that data than a git repository.

## Creating the storage backend

You can provision the storage account and container with either Azure CLI or PowerShell. Pick whichever matches your existing automation.

### With Azure CLI

{% highlight bash %}
# Variables
RESOURCE_GROUP="rg-terraform-state"
STORAGE_ACCOUNT="tfstate$RANDOM"   # must be globally unique
CONTAINER_NAME="tfstate"
LOCATION="eastus"

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create storage account
az storage account create \
    --name $STORAGE_ACCOUNT \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --sku Standard_LRS \
    --encryption-services blob \
    --https-only true \
    --min-tls-version TLS1_2

# Create blob container
az storage container create \
    --name $CONTAINER_NAME \
    --account-name $STORAGE_ACCOUNT \
    --auth-mode login

echo "Storage account: $STORAGE_ACCOUNT"
{% endhighlight %}

The `$RANDOM` suffix on the storage account name handles the global uniqueness constraint — storage account names must be unique across all of Azure. Note that `$RANDOM` is a shell variable and not a fixed value, so capture the output of that `echo` command and record your actual storage account name before moving on.

### With PowerShell

{% highlight posh %}
$resourceGroup = "rg-terraform-state"
$location = "eastus"
$storageAccount = "tfstate$(Get-Random -Maximum 9999)"
$containerName = "tfstate"

New-AzResourceGroup -Name $resourceGroup -Location $location

$storage = New-AzStorageAccount `
    -ResourceGroupName $resourceGroup `
    -Name $storageAccount `
    -Location $location `
    -SkuName Standard_LRS `
    -EnableHttpsTrafficOnly $true `
    -MinimumTlsVersion TLS1_2

$ctx = $storage.Context
New-AzStorageContainer -Name $containerName -Context $ctx

Write-Host "Backend ready: $storageAccount / $containerName"
{% endhighlight %}

Both approaches create the same thing: a Standard LRS storage account with HTTPS-only access, TLS 1.2 minimum, and a blob container named `tfstate`. The storage account name is the value you'll need for your backend configuration in the next step.

## Configuring the Terraform backend block

Now that we have a storage account, let's configure Terraform to use it. The backend configuration goes in your `terraform` block — I like to put it in a dedicated `backend.tf` file to keep the configuration concerns separated from the resource definitions.

{% highlight hcl %}
# backend.tf
terraform {
  required_version = ">= 1.1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.90"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstate1234"       # your storage account name
    container_name       = "tfstate"
    key                  = "prod.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}
{% endhighlight %}

The `key` attribute is the blob name within the container. I use a descriptive naming convention — `prod.terraform.tfstate`, `dev.terraform.tfstate` — so that if you look at the container in the Azure portal, the contents are immediately meaningful. Once you've added this configuration, initialize the backend:

{% highlight bash %}
terraform init
{% endhighlight %}

If you were previously using local state, Terraform will detect the existing `terraform.tfstate` file and ask if you want to migrate it to the remote backend. Answer yes, and your state moves up to Blob Storage. From that point on, every `plan` and `apply` reads and writes the remote file and manages the blob lease automatically.

## Authentication options for the backend

The backend block tells Terraform *where* the state lives, but authentication is handled separately — through environment variables, so that credentials never appear in your `.tf` files or version control. As of early 2022, there are three realistic options.

### Option A — Access key (simplest, not recommended for production)

{% highlight bash %}
export ARM_ACCESS_KEY=$(az storage account keys list \
    --resource-group rg-terraform-state \
    --account-name tfstate1234 \
    --query '[0].value' -o tsv)
{% endhighlight %}

This exports the storage account access key and Terraform picks it up automatically. It works everywhere, requires no additional configuration, and is fine for local development. The downside is that access keys are long-lived, have full storage account control, and need to be rotated manually. Avoid this for pipelines.

### Option B — Service principal (most common in CI/CD)

{% highlight bash %}
export ARM_CLIENT_ID="<application-id>"
export ARM_CLIENT_SECRET="<client-secret>"
export ARM_TENANT_ID="<tenant-id>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
{% endhighlight %}

This is the pattern you'll see in most Azure DevOps and GitHub Actions setups in 2022. The service principal needs at minimum `Storage Blob Data Contributor` on the storage account (or on the specific container). Use `Storage Blob Data Contributor` rather than `Contributor` or `Owner` — it's the principle of least privilege applied to the state backend specifically.

### Option C — Managed Identity (for Azure-hosted agents)

{% highlight hcl %}
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "tfstate1234"
  container_name       = "tfstate"
  key                  = "prod.terraform.tfstate"
  use_msi              = true
}
{% endhighlight %}

If your CI/CD agent runs inside Azure — an Azure DevOps self-hosted agent on a VM, or a GitHub Actions runner using OIDC — you can use Managed Identity instead of a client secret. Set `use_msi = true` in the backend block and assign `Storage Blob Data Contributor` to the managed identity. No credentials to rotate, no secrets to store in your pipeline variables. This is the emerging best practice and worth setting up if your pipeline infrastructure already runs in Azure.

## Managing multiple environments with workspaces

Terraform workspaces let you maintain separate state files for different environments — dev, staging, production — using the same backend configuration. This is the pattern I reach for when the infrastructure shape is identical across environments but the values (instance sizes, replica counts, domain names) differ.

{% highlight bash %}
# Create workspaces for each environment
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch to the dev workspace
terraform workspace select dev

# Show the current workspace
terraform workspace show
{% endhighlight %}

Each workspace gets its own state file in the same container. With the backend key set to `prod.terraform.tfstate`, workspaces store their state at `env:/dev/prod.terraform.tfstate`, `env:/staging/prod.terraform.tfstate`, and so on. You can verify this in the Azure portal by browsing the container contents after your first apply per workspace.

The real power comes when you reference `terraform.workspace` in your resource definitions:

{% highlight hcl %}
resource "azurerm_resource_group" "main" {
  name     = "rg-app-${terraform.workspace}"
  location = "eastus"
}

resource "azurerm_app_service_plan" "main" {
  name                = "asp-app-${terraform.workspace}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = terraform.workspace == "prod" ? "Standard" : "Free"
    size = terraform.workspace == "prod" ? "S1" : "F1"
  }
}
{% endhighlight %}

This is where the workspace pattern really earns its place. The conditional expression on the SKU means production gets a Standard tier plan while dev and staging use the free tier — same configuration file, same workspace mechanism, dramatically different cost profile.

## Enabling blob versioning for state history

Blob versioning is not enabled by default on new storage accounts. You should turn it on before your team starts writing state — it's much easier to enable upfront than to wish you had it after a bad apply.

{% highlight bash %}
az storage account blob-service-properties update \
    --account-name tfstate1234 \
    --resource-group rg-terraform-state \
    --enable-versioning true
{% endhighlight %}

With versioning enabled, every `terraform apply` that writes a new state file creates a new blob version rather than overwriting the previous one. You can see the full version history in the Azure portal by selecting any blob in your container and clicking the **Versions** tab. To restore a previous version you just promote it to the current version — no Terraform commands needed, just a blob copy operation.

## Security hardening for the state backend

The defaults when you create a storage account are not enough for a production state backend. These four settings are worth applying before you start writing production state to the account.

**Disable public blob access.** By default, new storage accounts in 2022 still allow public blob access at the account level (even if no container is configured with public access). Explicitly disable it:

{% highlight bash %}
az storage account update \
    --name tfstate1234 \
    --resource-group rg-terraform-state \
    --allow-blob-public-access false
{% endhighlight %}

**Enable soft delete for blobs.** Soft delete keeps deleted blobs for a retention period before permanently removing them. This is your safety net for accidental `terraform state rm` operations or manual blob deletions:

{% highlight bash %}
az storage account blob-service-properties update \
    --account-name tfstate1234 \
    --resource-group rg-terraform-state \
    --enable-delete-retention true \
    --delete-retention-days 30
{% endhighlight %}

**Restrict network access.** If your CI/CD agents run from known IP ranges or from within a VNet, restrict the storage account's network access to only those sources. This prevents the state file from being accessible from arbitrary internet addresses even with a valid access key:

{% highlight bash %}
# Default to deny all network access
az storage account update \
    --name tfstate1234 \
    --resource-group rg-terraform-state \
    --default-action Deny

# Allow access from a specific IP range (your CI/CD agents)
az storage account network-rule add \
    --account-name tfstate1234 \
    --resource-group rg-terraform-state \
    --ip-address "203.0.113.0/24"
{% endhighlight %}

**Use RBAC over access keys.** Assign `Storage Blob Data Contributor` to your service principals and managed identities instead of distributing access keys. RBAC assignments are auditable, can be scoped narrowly, and can be revoked instantly without rotating a key that might be embedded in multiple pipeline configurations.

## Testing and validating the backend setup

Once you've run `terraform init` with the backend configured, there are a few quick checks worth doing before your first apply.

Verify that the state lock works correctly by running two concurrent applies in separate terminals. The second should fail immediately with a message like `Error acquiring the state lock` and show the lock information from the first process. This confirms the blob lease mechanism is working.

Check the Azure portal after your first `terraform apply` to confirm the state file landed where you expected it. Navigate to your storage account, select **Containers**, open `tfstate`, and you should see the blob with the key name you specified. The blob metadata will show the last modified time and, if versioning is enabled, a **Versions** tab with the initial version.

Run `terraform state list` after a successful apply. If it returns your resources without error, the backend is reading state correctly and you're in good shape.

## Best practices

A few things I've found worth following consistently for remote state backends.

**One state file per environment, per application.** The key naming convention (`prod.terraform.tfstate`, `dev.terraform.tfstate`) works better if you extend it to include the application or service name: `payments-prod.terraform.tfstate`. As the number of Terraform configurations in your organization grows, this naming prevents collisions and makes the container contents navigable.

**Never store the backend configuration in `tfvars` files.** The backend block doesn't support variable references — it's evaluated before variables are loaded. Keep the backend configuration in a dedicated `backend.tf` file, committed to version control, with only non-sensitive values (resource group name, container name, key). Credentials go in environment variables.

**Use partial configuration for sensitive backend values.** If your storage account name is considered sensitive (unlikely, but possible in highly regulated environments), you can omit fields from the backend block and pass them at `terraform init` time: `terraform init -backend-config="storage_account_name=tfstate1234"`. This keeps sensitive values out of committed code while still allowing the rest of the backend block to live in version control.

**Enable diagnostic logging on the storage account.** Route storage access logs to a Log Analytics workspace. This gives you an audit trail of every read and write operation on your state files — useful for compliance and for diagnosing unexpected state mutations.

**Document the backend in your repository README.** When a new team member joins or a new pipeline is set up, the first question is always "where's the state?" A one-paragraph section in the README describing the storage account name, container, and key naming convention saves the conversation every time.

## Wrapping up

Remote state is a prerequisite for using Terraform in any team or CI/CD context. Getting the backend right at the start — proper storage account, locking, authentication model, and security hardening — is far less painful than migrating from local state after you've already built up a meaningful amount of infrastructure managed by Terraform.

Azure Blob Storage is a solid backend for this: native lease-based locking means there's no separate infrastructure to manage, versioning gives you a built-in state history, encryption at rest is on by default, and RBAC integration means you can apply the principle of least privilege without custom tooling. Set it up once, harden it properly, and then let it disappear into the background while you focus on the actual infrastructure you're building.

Happy scripting!
