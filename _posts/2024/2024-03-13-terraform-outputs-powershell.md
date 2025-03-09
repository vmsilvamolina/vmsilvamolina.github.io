---
title: 'Leveraging Terraform outputs in your build pipeline with Python [English]'
author: Victor Silva
date: 2024-03-13T19:25:47+00:00
layout: post
permalink: /terraform-outputs-python/
excerpt: 'After working with Terraform for several years, I recently encountered a scenario where I needed to access Terraform outputs within my CI/CD pipeline. Despite my extensive experience with infrastructure as code, I had never needed to programmatically consume Terraform outputs until now.'
categories:
  - Terraform
  - Python
tags:
  - Terraform
  - Python
  - IaC
---

After working with Terraform for several years, I recently encountered a scenario where I needed to access Terraform outputs within my CI/CD pipeline. Despite my extensive experience with infrastructure as code, I had never needed to programmatically consume Terraform outputs until now.

## The Challenge

My team has been using Python for our deployment scripts. We faced a situation where we needed to reference resources created by Terraform with dynamically generated names. Specifically, we needed to access auto-generated Kubernetes namespace names and service endpoints for subsequent deployment steps.

In the past, our naming conventions were deterministic and passed as variables, but our new multi-tenant architecture required unique, entropy-based naming for isolation purposes.

## Project Setup

Let's walk through creating a simple example to demonstrate the solution:

{% highlight bash %}
# Create a new project directory
mkdir terraform-python-demo
cd terraform-python-demo

# Set up a Python virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install necessary packages
pip install fabric pyyaml
{% endhighlight %}

Next, let's create a simple `requirements.txt` file:

{% highlight plaintext %}
fabric==3.1.0
pyyaml==6.0.1
{% endhighlight %}

## Creating Our Terraform Configuration

Now, let's create a basic Terraform configuration that generates random identifiers:

{% highlight bash %}
# Create Terraform files
touch main.tf
{% endhighlight %}

In our `main.tf`, we'll use the random provider to generate unique names:

{% highlight hcl %}
terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
  }
}

provider "random" {}

resource "random_id" "namespace_suffix" {
  byte_length = 4
  prefix      = "namespace-"
}

resource "random_id" "endpoint_name" {
  byte_length = 6
  prefix      = "api-"
}

output "k8s_namespace" {
  value = random_id.namespace_suffix.hex
}

output "service_endpoint" {
  value = "https://${random_id.endpoint_name.hex}.example.com"
}
{% endhighlight %}

## Building Our Python Deployment Script

Now for the key part - creating a Python script that can run Terraform and use its outputs. Let's create a file called `deploy.py`:

{% highlight python %}
#!/usr/bin/env python3
import subprocess
import json
import sys
from fabric import Connection

def run_terraform():
    """Initialize and apply Terraform configuration"""
    print("Initializing Terraform...")
    subprocess.run(["terraform", "init"], check=True)
    
    print("Validating Terraform configuration...")
    subprocess.run(["terraform", "validate"], check=True)
    
    print("Applying Terraform configuration...")
    subprocess.run(["terraform", "apply", "-auto-approve"], check=True)

def get_terraform_outputs():
    """Get outputs from Terraform as a Python dictionary"""
    result = subprocess.run(
        ["terraform", "output", "-json"],
        capture_output=True,
        text=True,
        check=True
    )
    return json.loads(result.stdout)

def deploy_application(namespace, endpoint):
    """Deploy application using the Terraform outputs"""
    print(f"Deploying to Kubernetes namespace: {namespace}")
    print(f"Configuring to use service endpoint: {endpoint}")
    
    # This would typically connect to your server or Kubernetes cluster
    # and perform the actual deployment
    # For demonstration, we'll just print the commands
    
    print(f"kubectl config set-context --current --namespace={namespace}")
    print(f"kubectl apply -f ./k8s/deployment.yaml")
    print(f"curl -X POST {endpoint}/register -d 'deployment=complete'")

def main():
    # Run Terraform to create infrastructure
    run_terraform()
    
    # Get Terraform outputs
    outputs = get_terraform_outputs()
    
    # Extract values from the outputs
    namespace = outputs["k8s_namespace"]["value"]
    endpoint = outputs["service_endpoint"]["value"]
    
    print("\n--- Terraform Outputs ---")
    print(f"Kubernetes Namespace: {namespace}")
    print(f"Service Endpoint: {endpoint}")
    print("------------------------\n")
    
    # Use these values for deployment
    deploy_application(namespace, endpoint)

if __name__ == "__main__":
    main()
{% endhighlight %}

## Running the Deployment

With our files in place, we can now run the deployment script:

{% highlight bash %}
# Make the script executable
chmod +x deploy.py

# Run the deployment
./deploy.py
{% endhighlight %}

The script will initialize Terraform, apply the configuration, extract the outputs, and use them in our simulated deployment steps.

## Enhancing for Production Use

For a production environment, you might want to add more robust error handling and make the script more configurable:

1. Add command-line arguments for different environments
2. Support for different Terraform workspaces
3. Add proper logging
4. Implement retry logic for API calls
5. Include authentication for Kubernetes

## Conclusion

The ability to programmatically access Terraform outputs opens up many possibilities for automation. By combining Terraform's infrastructure provisioning capabilities with Python's flexibility, we can create powerful, integrated deployment pipelines.

This approach eliminates the need to hardcode resource names or manually copy values between systems. Instead, we have a single source of truth (Terraform state) and can build reliable automation around it.

The key insight here is that Terraform's `output -json` command provides a structured format that's easy to parse in any programming language. While I've demonstrated this with Python and Fabric, the same approach works with any scripting language or CI/CD tool that can parse JSON.

Have you integrated Terraform outputs into your deployment process? What approaches have you found most effective?

Happy scripting!