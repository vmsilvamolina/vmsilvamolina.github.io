---
title: "Getting started with Bicep: Azure IaC beyond ARM templates"
author: Victor Silva
date: 2021-09-07T16:31:55+00:00
layout: post
permalink: /getting-started-bicep-azure-iac/
excerpt: "Bicep went GA in March 2021 as a cleaner alternative to ARM templates. This post walks through the core syntax, your first deployment, and why it's worth switching from raw JSON."
categories:
  - Azure
  - DevOps
tags:
  - Azure
  - Bicep
  - IaC
  - ARM Templates
  - PowerShell
  - Azure CLI
---

ARM templates work. Nobody disputes that — they've been the backbone of Azure infrastructure-as-code since the Resource Manager model launched back in 2014. But if you've ever had to write 300 lines of JSON to deploy three resources, you know the experience isn't exactly pleasant. The schema declarations, the `[parameters()]` function noise, the deeply nested objects — ARM JSON has a way of burying your actual intent under a pile of boilerplate.

Bicep is Microsoft's answer to that problem. It's a domain-specific language that compiles down to ARM JSON, which means you get the full power and native ARM API coverage without having to author the verbose JSON yourself. It went GA in March 2021 with v0.3, and by v0.4 (mid-2021) the tooling was solid enough for production use. I've been using it on real projects for a few months now and the difference in authoring experience is dramatic.

This post covers the essentials: the Bicep vs ARM comparison you need to see to believe it, the five core language constructs, a practical deployment example, and a few honest notes about where the tooling still has gaps as of September 2021. If you're still writing raw ARM JSON, I want to convince you there's a better way.

## ARM vs Bicep — the same deployment, two very different experiences

The best way to understand what Bicep does is to see the same resource declared in both languages. Let's deploy a Storage Account — probably the most common Azure resource in any project.

Here's the ARM JSON template:

{% highlight json %}
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "storageAccountName": {
      "type": "string"
    },
    "location": {
      "type": "string",
      "defaultValue": "[resourceGroup().location]"
    }
  },
  "resources": [
    {
      "type": "Microsoft.Storage/storageAccounts",
      "apiVersion": "2021-02-01",
      "name": "[parameters('storageAccountName')]",
      "location": "[parameters('location')]",
      "sku": {
        "name": "Standard_LRS"
      },
      "kind": "StorageV2"
    }
  ]
}
{% endhighlight %}

Now here's the exact same resource in Bicep:

{% highlight bicep %}
param storageAccountName string
param location string = resourceGroup().location

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}
{% endhighlight %}

That's roughly 60% less code, and it reads like what it is: a resource declaration with parameters. No schema URI. No `contentVersion`. No `[parameters('...')]` wrapper syntax everywhere. The resource type and API version are right there in the resource declaration itself, not scattered across a nested object structure.

This is what I mean when I say Bicep removes *accidental* complexity. The JSON format was never the goal — it was just the medium. Bicep is what Azure IaC should have looked like from the start.

## Installing Bicep

Bicep support comes through the Azure CLI, and it's as simple as one command:

{% highlight bash %}
# Install the Bicep CLI via Azure CLI (requires az 2.20+)
az bicep install

# Verify the installed version
az bicep version

# Upgrade if you already have it installed
az bicep upgrade
{% endhighlight %}

On the PowerShell side, the `Az` module (6.0+) can invoke Bicep deployments natively — it calls the ARM API under the hood, same as the CLI. Make sure you're on a recent enough version:

{% highlight posh %}
# Verify Az module version
Get-InstalledModule -Name Az | Select-Object Name, Version

# Update if needed
Update-Module -Name Az
{% endhighlight %}

For editor support, install the **Bicep** extension for VS Code by Microsoft. By mid-2021 it already has solid IntelliSense — autocomplete for resource types, API versions, and property names, plus inline error highlighting. It makes writing Bicep significantly faster because you're not hunting through docs to find the right property names.

## Core Bicep syntax: the five constructs you need

Bicep has a small surface area. You really only need to understand five constructs to write production-quality templates.

### 1. Parameters

Parameters are how you make templates reusable. Bicep supports decorators that replace the verbose ARM parameter metadata:

{% highlight bicep %}
@description('Name of the storage account. Must be globally unique.')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('SKU for the storage account.')
@allowed(['Standard_LRS', 'Standard_GRS', 'Premium_LRS'])
param storageSku string = 'Standard_LRS'

@description('Azure region for all resources.')
param location string = resourceGroup().location
{% endhighlight %}

The `@description()`, `@minLength()`, `@maxLength()`, and `@allowed()` decorators replace what ARM required inside the parameter object itself. The result is much easier to read and self-documents the constraints inline.

### 2. Variables

Variables let you compute or alias values that you'll reuse across the template:

{% highlight bicep %}
var storageKind = 'StorageV2'
var tags = {
  environment: 'production'
  managedBy: 'bicep'
  deployedAt: '2021-09'
}
{% endhighlight %}

Variables are resolved at deployment time, not passed in. Use them to avoid duplicating expressions or magic strings across multiple resource declarations.

### 3. Resource declarations

This is the heart of every Bicep file. The syntax is `resource <symbolicName> '<type>@<apiVersion>' = { ... }`:

{% highlight bicep %}
resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: storageSku
  }
  kind: storageKind
}
{% endhighlight %}

The symbolic name (`storageAccount` here) is how you reference this resource elsewhere in the same template — for outputs, for parent-child relationships, for dependency ordering. Bicep infers implicit dependencies from symbolic references, so you don't need `dependsOn` in most cases.

### 4. Outputs

Outputs expose values from your deployment for use in pipelines or subsequent deployments:

{% highlight bicep %}
output storageAccountId string = storageAccount.id
output storageAccountEndpoint string = storageAccount.properties.primaryEndpoints.blob
{% endhighlight %}

Notice that you access resource properties through the symbolic name (`storageAccount.id`, `storageAccount.properties...`). Bicep knows the full type definition of the resource, so IntelliSense will suggest available properties as you type.

### 5. String interpolation

Bicep uses `'${expression}'` syntax for building strings from variables and parameters — clean and familiar if you've used any modern scripting language:

{% highlight bicep %}
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage}'

var resourceName = 'st${toLower(storageAccountName)}prod'
{% endhighlight %}

This replaces the `[concat(...)]` calls you'd write in ARM JSON, which were one of the most common sources of template errors.

## A practical example: storage account with a blob container

Let's implement something you'd actually deploy in a real project — a storage account with a private blob container, hardened with HTTPS-only and TLS 1.2 minimum. This is a realistic baseline for any project that needs blob storage.

{% highlight bicep %}
@description('Name of the storage account. Must be 3-24 lowercase alphanumeric characters.')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Name of the blob container to create.')
param containerName string = 'data'

@description('Azure region for the storage account.')
param location string = resourceGroup().location

@description('Storage account SKU.')
@allowed(['Standard_LRS', 'Standard_GRS'])
param sku string = 'Standard_LRS'

var tags = {
  managedBy: 'bicep'
  environment: 'demo'
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-02-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: sku
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
  name: '${storageAccount.name}/default/${containerName}'
  properties: {
    publicAccess: 'None'
  }
}

output storageId string = storageAccount.id
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
{% endhighlight %}

A few things worth noting in this example. The `blobContainer` resource uses string interpolation with `storageAccount.name` to build its ARM resource ID path — and because it references the symbolic name `storageAccount`, Bicep automatically infers that the container depends on the storage account and will deploy them in the right order. No explicit `dependsOn` needed.

The security hardening properties (`supportsHttpsTrafficOnly: true` and `minimumTlsVersion: 'TLS1_2'`) are defaults I add to every storage account — they're not the platform defaults, but they should be. Save this as `storage.bicep` and let's deploy it.

## Deploying your Bicep file

Since Bicep compiles to ARM JSON, you deploy it exactly the same way you'd deploy an ARM template. The CLI and PowerShell commands accept `.bicep` files directly — the compilation step happens transparently:

{% highlight bash %}
# Create a resource group first if needed
az group create --name rg-demo --location eastus

# Deploy the Bicep file
az deployment group create \
  --resource-group rg-demo \
  --template-file storage.bicep \
  --parameters storageAccountName=stdemobicep2021

# To preview what will be deployed (what-if)
az deployment group what-if \
  --resource-group rg-demo \
  --template-file storage.bicep \
  --parameters storageAccountName=stdemobicep2021
{% endhighlight %}

{% highlight posh %}
# PowerShell equivalent
New-AzResourceGroupDeployment `
  -ResourceGroupName "rg-demo" `
  -TemplateFile "storage.bicep" `
  -storageAccountName "stdemobicep2021"

# What-if preview in PowerShell
New-AzDeploymentWhatIfResult `
  -ResourceGroupName "rg-demo" `
  -TemplateFile "storage.bicep" `
  -storageAccountName "stdemobicep2021"
{% endhighlight %}

The what-if flag is something I always recommend running before any production deployment. It shows you exactly what changes ARM will make — resources added, modified, or deleted — without actually making them. It's available for both Bicep and ARM templates and works the same way.

## Migrating from ARM: decompile your existing templates

If you have existing ARM JSON templates you want to migrate, Bicep gives you a head start with the `decompile` command:

{% highlight bash %}
az bicep decompile --file existing-template.json
{% endhighlight %}

This generates a `.bicep` file from your ARM JSON. Fair warning: the output is a starting point, not production-ready Bicep. It faithfully converts the structure but won't add decorators, simplify expressions, or reorganize parameters in a meaningful way. Think of it as doing 80% of the migration work — you'll still want to clean up the output and add `@description()` decorators, but it's a much better starting point than a blank file.

## Where Bicep still has gaps in September 2021

I want to be honest about the current limitations, because the tooling is still maturing.

The biggest gap right now is **module sharing**. Bicep modules (the `module` keyword) work and are genuinely useful for composing larger templates from smaller ones. But there's no public module registry yet — if you want to share modules across teams or projects, you're rolling your own solution with Azure Container Registry or a storage account. The public Bicep module registry is on the roadmap but hasn't shipped.

Loops (`for`) and conditions (`if`) are fully supported, which covers most dynamic template scenarios. The `existing` keyword is also available for referencing resources that already exist outside your template — useful for things like pulling a Key Vault reference without deploying it yourself.

The VS Code extension occasionally lags behind the CLI on newer resource type definitions, so you might see IntelliSense miss a property that's actually valid. When in doubt, the [ARM template reference](https://docs.microsoft.com/en-us/azure/templates/) is still the authoritative source for resource properties and API versions.

## Best practices

A few things I've settled on from real-world Bicep usage:

**Always pin API versions explicitly.** The resource declaration format (`'Microsoft.Storage/storageAccounts@2021-02-01'`) makes this natural. Don't use `latest` or rely on defaults — lock to a specific API version so your templates are reproducible months later.

**Add `@description()` to every parameter.** It costs two lines and pays back enormously when someone else (or future-you) has to understand the template. The decorator is right there at the top of the parameter — no digging into a JSON `metadata` block.

**Use `what-if` before every production deployment.** Make it a habit, not an afterthought. It catches drift between what you expect and what ARM will actually do.

**Keep Bicep files focused.** One `.bicep` file per logical unit of infrastructure — don't try to cram everything into one file. Use modules to compose them. Even without a public registry, local modules (a folder of `.bicep` files in your repo) work well for organizing larger projects.

**Store outputs.** Every Bicep file that creates a resource should output the resource ID and any relevant endpoints. This makes it easy to wire deployments together in a pipeline without hard-coding resource names across templates.

## Wrapping up

Bicep removes the accidental complexity of ARM JSON — the schema declarations, the `[parameters()]` function syntax, the deeply nested resource objects. What's left is intentional complexity: the actual structure of your infrastructure, expressed clearly. The compilation to ARM JSON is transparent, which means you're not trading away any ARM capabilities. You're just getting a better way to express them.

If you're managing Azure infrastructure in late 2021 and still writing raw ARM JSON, there's no good reason not to make the switch. The tooling is production-ready, the VS Code extension makes it pleasant to write, and the migration path via `az bicep decompile` means you don't have to start from scratch. Give it one project, and I doubt you'll go back.

Happy scripting!
