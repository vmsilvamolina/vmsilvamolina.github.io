---
title: 'The art of saying no: Azure Policy as your role assignment guardian [English]'
author: Victor Silva
date: 2025-03-07T07:35:18+00:00
layout: post
permalink: /azure-policy-role-guardian/
excerpt: 'In the world of cloud security, the principle of least privilege is paramount. However, managing who can assign roles in Azure can become challenging as organizations grow. While Azure RBAC provides granular access control, without proper governance, role assignments can proliferate unchecked. Enter Azure Policy - your gatekeeper for maintaining strict control over who can assign what roles to whom.'
categories:
  - Azure
tags:
  - Azure
  - Policy
  - Governance
---

In the world of cloud security, the principle of least privilege is paramount. However, managing who can assign roles in Azure can become challenging as organizations grow. While Azure RBAC provides granular access control, without proper governance, role assignments can proliferate unchecked. Enter Azure Policy - your gatekeeper for maintaining strict control over who can assign what roles to whom.

## Use Cases

### When do you need this?

1. **Security Compliance Requirements**
    
    - Ensuring only authorized service principals can manage role assignments
    - Meeting regulatory requirements for access control
    - Implementing separation of duties
2. **Large Enterprise Scenarios**
    
    - Managing multiple development teams with different access needs
    - Controlling access across multiple subscriptions
    - Automating security governance
3. **DevOps Environments**
    
    - Allowing CI/CD pipelines to manage specific resources
    - Restricting human access while enabling automation
    - Maintaining security in automated deployments

## Implementation Guide

### Prerequisites

- Azure Subscription with Owner/Contributor access
- An existing App Registration that needs to maintain role assignment capabilities
- Azure CLI or PowerShell installed (for command-line operations)

### Step 1: Identify Your Service Principal

First, gather the necessary information about your service principal:

```powershell
# Get Service Principal Object ID
$spObjectId = (az ad sp show --id "your-app-id" --query objectId -o tsv)
```

### Step 2: Create the Policy Definition

{% highlight json %}
{
    "mode": "All",
    "policyRule": {
        "if": {
            "allOf": [
                {
                    "field": "type",
                    "equals": "Microsoft.Authorization/roleAssignments"
                },
                {
                    "field": "Microsoft.Authorization/roleAssignments/principalId",
                    "notEquals": "[parameters('allowedServicePrincipalObjectId')]"
                }
            ]
        },
        "then": {
            "effect": "deny"
        }
    },
    "parameters": {
        "allowedServicePrincipalObjectId": {
            "type": "String",
            "metadata": {
                "displayName": "Allowed Service Principal Object ID",
                "description": "Object ID of the service principal allowed to create role assignments"
            }
        }
    }
}
{% endhighlight %}

### Step 3: Deploy the Policy

{% highlight powershell %}
# Create the policy definition
$definition = New-AzPolicyDefinition `
    -Name "restrict-role-assignments" `
    -Description "Restrict role assignments to specific service principal" `
    -Policy "path/to/policy.json"

# Create the policy assignment
$assignment = New-AzPolicyAssignment `
    -Name "restrict-role-assignments" `
    -PolicyDefinition $definition `
    -Scope "/subscriptions/$subscriptionId" `
    -PolicyParameterObject @{
        allowedServicePrincipalObjectId = $spObjectId
    }
{% endhighlight %}

### Step 4: Verify the Policy

Test the policy by attempting role assignments:

4. Try to create a role assignment with a different service principal (should be denied):

{% highlight powershell %}
New-AzRoleAssignment `
    -SignInName "user@domain.com" `
    -RoleDefinitionName "Reader" `
    -ResourceGroupName "myResourceGroup"
{% endhighlight %}

5. Create a role assignment with the allowed service principal (should succeed):

{% highlight powershell %}
# Use your service principal credentials
az login --service-principal -u "app-id" -p "password" --tenant "tenant-id"

az role assignment create \
    --role "Reader" \
    --assignee-object-id "user-object-id" \
    --resource-group "myResourceGroup"
{% endhighlight %}

## Best Practices and Considerations

6. **Emergency Access**
    
    - Always maintain an emergency access account
    - Document the process for policy exceptions
    - Regularly review and audit policy assignments
7. **Monitoring and Compliance**
    
    - Enable Azure Activity logs for role assignments
    - Set up alerts for policy violations
    - Regular review of role assignment attempts
8. **Policy Scope**
    
    - Consider implementing at management group level for broader control
    - Use exclusions carefully and document them
    - Regular validation of excluded resources

## Troubleshooting

Common issues and solutions:

9. **Policy Not Taking Effect**
    
    - Verify policy assignment scope
    - Check parameter values
    - Confirm service principal permissions
10. **Legitimate Assignments Blocked**
    
    - Review policy parameters
    - Check service principal object ID
    - Verify scope configuration

## Conclusion

Implementing Azure Policy as your role assignment gatekeeper provides a robust and automated way to enforce least-privilege access in your Azure environment. By following this guide, you've learned how to implement a policy that restricts role assignments while maintaining the flexibility needed for authorized service principals to operate effectively.

Remember to regularly review and update your policies as your organization's needs evolve, and always maintain proper documentation of your policy implementations.

Happy scripting!