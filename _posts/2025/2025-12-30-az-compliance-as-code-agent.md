---
title: 'Building a Compliance-as-Code agent'
author: Victor Silva
date: 2025-12-30T06:15:31+00:00
layout: post
permalink: /compliance-as-code-agent/
excerpt: "Manual compliance reviews are the bottleneck nobody talks about. Your infrastructure code sits in a pull request, waiting for someone to verify naming conventions, check security policies, and ensure resource configurations align with company standards. Hours or even days pass before deployment can proceed."
categories:
  - Azure
tags:
  - Azure

---
Manual compliance reviews are the bottleneck nobody talks about. Your infrastructure code sits in a pull request, waiting for someone to verify naming conventions, check security policies, and ensure resource configurations align with company standards. Hours or even days pass before deployment can proceed.

There's a better way: intelligent automation that understands your policies and validates infrastructure code before it ever reaches production.

## The Challenge with Traditional Compliance

Most organizations handle infrastructure compliance through one of two approaches, both flawed:

**Manual code reviews** consume significant engineering time and introduce human error. Reviewers might miss subtle violations or apply policies inconsistently across teams.

**Static linting tools** catch syntax issues but lack contextual understanding. They can't interpret nuanced business rules or explain *why* something violates policy.

What we need is something that combines the intelligence of human review with the consistency and speed of automation.

## Enter: Policy-Aware AI Agents

The solution leverages an AI agent specifically trained on your organization's compliance documentation. Rather than relying on generic best practices, this agent evaluates infrastructure code against your actual internal policies.

Here's what makes this approach powerful:

**Context-aware analysis** - The agent understands not just Terraform syntax, but your specific requirements around naming, tagging, regions, and resource configurations.

**Structured output** - Every compliance check returns a clear verdict with detailed violation descriptions and policy references.

**No hallucinations** - By constraining the AI to only reference provided documentation through RAG, you eliminate unreliable suggestions based on general internet knowledge.

## Architecture Overview

The system consists of two primary components working together:

### The Compliance Agent

Built on [Microsoft Foundry](https://ai.azure.com/), this agent serves as your automated auditor. It receives Terraform code as input and returns structured compliance verdicts.

The agent's behavior is controlled through a carefully designed system prompt that:

- Defines its role as a compliance auditor
- Restricts it to only using provided policy documents
- Enforces a specific JSON output format
- Handles edge cases like invalid input or missing rules

Here's a sample of what the policy documentation might include:

```
Resource Naming Standards:
Format: <type>-<identifier>-<environment>
Example: rg-webapp-prod

Required Tags:
- Environment: must be dev, stg, or prod
- Cost-center: must match approved list

Approved Regions:
- Primary: eastus
- Secondary: westus
```

### The CI/CD Integration

The agent plugs directly into your deployment pipeline. When developers push Terraform code, the pipeline automatically:

1. Extracts the infrastructure definitions
2. Sends them to the compliance agent
3. Receives a structured verdict
4. Blocks or approves the deployment based on results

This happens in seconds, providing immediate feedback to developers while maintaining consistent policy enforcement.

## Implementation Walkthrough

### Setting Up the AI Agent

Start by creating a new AI agent project in Microsoft Foundry. Select an appropriate language model variants work well for code analysis, though gpt-4.1 suffices for simpler use cases.

The critical step is crafting your system prompt. This prompt must be explicit about:

- What constitutes valid input
- How to structure responses
- What to do when rules are ambiguous
- How to cite policy violations

Your prompt should enforce a consistent output schema. Something like:

```json
{
  "verdict": "COMPLIANT | NON-COMPLIANT | UNKNOWN | INVALID_INPUT",
  "analysis": "detailed explanation here",
  "violations": [
    {
      "description": "what's wrong",
      "policy_source": "which rule was violated"
    }
  ]
}
```

### Connecting Policy Documents

The agent needs access to your compliance documentation. Azure AI Search provides the infrastructure for this through RAG implementation.

Upload your policy documents—security guidelines, naming conventions, network topology requirements—to Azure AI Search. These become the knowledge base the agent queries when evaluating code.

The beauty of RAG is that updating policies is straightforward. Add new documents or modify existing ones, and the agent immediately incorporates those changes without requiring prompt retraining.

You can use the tools section to upload directly files. For this example can we use the next content as a policy:

```
1. Naming convention for resources

All resources must follow this format: `<type>-<uniqueId>-<env>`
Examples:
rg-core-dev (Resource Group for developtment)
sa-1234-prod (Storage Account for production)
Supported types:
- rg: Resource Group
- sa: Storage Account
- vnet: Virtual Network
- sn: Subnet
- vm: Virtual Machine
- nic: Network Interface
Supported environments:
- dev, stg, prod

2. Tags must be applied

All resources must include this tag in Terraform:
tags = {
  env = "dev" | "stg" | "prod"
}

3. Required location

All resources must be deployed to: `eastus`
Example:
location = "eastus"
```

### Testing and Validation

Before integrating into production pipelines, thoroughly test your agent. Create Terraform examples that intentionally violate various policies:

```hcl
resource "azurerm_storage_account" "example" {
  name = "storageaccount123"
  resource_group_name = "default-rg"
  location = "centralus"
  account_tier = "Standard"
  account_replication_type = "LRS"
}
```

The agent should catch:
- Naming convention violations
- Incorrect region usage
- Missing mandatory tags

Verify that it correctly references your specific policies in its violation descriptions.

<img src="/assets/images/postsImages/AZ_Agent_01.png" alt="Agent Compliance-as-Code output" />


### Pipeline Integration

Add a compliance stage to your Azure DevOps pipeline:

```yaml
- stage: InfrastructureCompliance
  jobs:
  - job: ValidateCompliance
    steps:
    - task: UsePythonVersion@0
      inputs:
        versionSpec: '3.x'
    
    - script: |
        pip install azure-ai-projects requests
      displayName: 'Install dependencies'
    
    - script: |
        python scripts/run_compliance_check.py \
          --terraform-path ./infrastructure
      displayName: 'Execute compliance validation'
    
    - script: |
        RESULT=$(cat compliance_result.json | jq -r '.verdict')
        if [ "$RESULT" != "COMPLIANT" ]; then
          echo "Compliance check failed"
          exit 1
        fi
      displayName: 'Evaluate verdict'
```

This stage runs before any actual infrastructure deployment, catching issues early.

## Getting Started

If you're interested in implementing something similar:

1. Start small with a single, well-defined policy (like resource naming)
2. Test extensively with both compliant and non-compliant examples
3. Integrate into a non-production pipeline first
4. Gather feedback from developers
5. Gradually expand to additional policies

The goal isn't perfection from day one, but rather continuous improvement of your infrastructure governance.

## Closing Thoughts

Infrastructure compliance doesn't have to be a manual slog. By combining AI capabilities with structured policy documentation and automated pipelines, you can create a system that's both more reliable and more efficient than traditional approaches.

The technology is mature enough for production use today. The real challenge is organizational: clearly documenting your policies, building trust in automated systems, and changing team workflows to embrace this new approach.

For teams shipping infrastructure changes daily, this investment pays dividends quickly. The alternative—scaling manual review processes—simply doesn't work at modern deployment velocities.

Happy scripting!