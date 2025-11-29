---
title: 'OCI Cloud Guard: Excepting with custom tags [English]'
author: Victor Silva
date: 2025-08-31T23:14:33+00:00
layout: post
permalink: /oci-cloud-guard-detection-rules/
excerpt: "In Oracle Cloud Infrastructure (OCI) environments, it's common to encounter scenarios where public datasets are hosted in Object Storage to facilitate access for researchers, open-source communities, or partners. However, Cloud Guard, OCI's automated security service, can generate constant alerts about these intentionally public buckets, creating noise in the monitoring system and making it difficult to identify real threats."
categories:
  - Oracle
  - Security
tags:
  - Oracle Cloud
  - Cloud Guard
  - Detection Rules
  - Security
---

In Oracle Cloud Infrastructure (OCI) environments, it's common to encounter scenarios where public datasets are hosted in Object Storage to facilitate access for researchers, open-source communities, or partners. However, Cloud Guard, OCI's automated security service, can generate constant alerts about these intentionally public buckets, creating noise in the monitoring system and making it difficult to identify real threats.

## The Challenge: Security vs. Public Access
Cloud Guard is designed to identify insecure configurations and potential vulnerabilities in your OCI tenancy. One of its most sensitive detectors identifies Object Storage buckets with public access, as these represent a potential risk of sensitive data exposure.
But what happens when your buckets must be public by design?
The Right Solution: Modify Detection Rules
Of the available options to handle this scenario, the correct answer is to modify the Cloud Guard Detection Rules configuration to exclude known public buckets from security scans.

### Why is this the best option?

- **Granularity**: Allows you to keep Cloud Guard active for all other resources
Security: Doesn't compromise the overall security posture of your tenancy
- **Flexibility**: You can apply specific exceptions without disabling important protections
- **Scalability**: Easy to maintain as your infrastructure grows

### Why aren't the other options suitable?

Disable Cloud Guard completely: Would remove protection from your entire tenancy
Convert buckets to private: Contradicts the purpose of sharing data publicly
Create a separate compartment without Cloud Guard: Leaves a segment of your infrastructure unmonitored, creating a security blind spot

## Implementing Exceptions with Custom Tags
The most elegant and maintainable way to implement this solution is by using custom tags combined with Detection Rules configuration.

### Step 1: Create a Tag Namespace and Tag
First, create a tag namespace and a specific tag to identify authorized public resources:

```bash
# Create Tag Namespace
le

# Create Tag
oci iam tag create \
  --tag-namespace-id <tag-namespace-ocid> \
  --name "exception" \
  --description "Indicates that the resource is an authorized exception"
```

### Step 2: Apply the Tag to Public Buckets
Tag the buckets that are intentionally public. In our case, we'll tag the publicBucket in the ocilabs compartment:

```bash
oci os bucket update \
  --bucket-name publicBucket \
  --namespace <namespace> \
  --freeform-tags '{"exception":"true"}'
```

Or using Defined Tags:

```bash
oci os bucket update \
  --bucket-name publicBucket \
  --namespace <namespace> \
  --defined-tags '{"SecurityExceptions":{"exception":"true"}}'
```

### Step 3: Configure Cloud Guard Detection Rules

Now comes the crucial part: modifying the Detection Rule that detects public buckets so it ignores those with the appropriate tag.

#### Option A: Using the OCI Console

1. Navigate to **Security** → **Cloud Guard** → **Configuration**
2. Select the **Detector Recipe** you're using
3. Find the "Public Bucket" rule (typically `OBJECT_STORE_PUBLIC_BUCKET`)
4. Click **Edit Rule**
5. In the **Condition** section, add a condition to exclude resources with the tag:

```
resource.type = 'Bucket' 
AND resource.publicAccessType IN ('ObjectRead', 'ObjectReadWithoutList')
AND NOT (resource.freeformTags.exception = 'true')
```

#### Option B: Using OCI CLI

```bash
# Get the current detector recipe
oci cloud-guard detector-recipe get \
  --detector-recipe-id <detector-recipe-ocid> \
  > detector-recipe.json

# Edit the detector-recipe.json file to update the condition
# Then update the detector recipe
oci cloud-guard detector-recipe update \
  --detector-recipe-id <detector-recipe-ocid> \
  --from-json file://detector-recipe.json
```

### Practical Example: Configuring publicBucket in ocilabs
Let's walk through a complete example for the publicBucket in the ocilabs compartment:
1. Tag the Bucket

```bash
# First, get your namespace
export NAMESPACE=$(oci os ns get --query 'data' --raw-output)

# Tag the publicBucket
oci os bucket update \
  --bucket-name publicBucket \
  --namespace $NAMESPACE \
  --freeform-tags '{"exception":"true"}' \
  --compartment-id <ocilabs-compartment-ocid>
```

2. Verify the Tag

```bash
oci os bucket get \
  --bucket-name publicBucket \
  --namespace $NAMESPACE \
  --query 'data."freeform-tags"'
```

Expected output:

```json
{
  "exception": "true"
}
```

3. Update Cloud Guard Detector Recipe

```bash
# List detector recipes to find the one you're using
oci cloud-guard detector-recipe list \
  --compartment-id <root-compartment-ocid> \
  --lifecycle-state ACTIVE
```

Clone the Oracle-managed recipe if you haven't already

```bash
oci cloud-guard detector-recipe create \
  --compartment-id <ocilabs-compartment-ocid> \
  --display-name "Custom Detector Recipe - Public Buckets Exception" \
  --source-detector-recipe-id <oracle-detector-recipe-ocid>
```

## Best Practices

1. Documentation
Maintain a record of all resources tagged as exceptions:

```markdown
# Cloud Guard Exceptions

| Resource | Compartment | Tag | Justification | Date | Approved by |
|----------|-------------|-----|---------------|------|-------------|
| publicBucket | ocilabs | exception:true | Public datasets for research | 2025-10-31 | Security Team |
```

2. Periodic Review
Implement a quarterly review process to validate that exceptions are still necessary:

```bash
# List all buckets with the exception tag
oci search resource structured-search \
  --query-text "query bucket resources where (freeformTags.key = 'exception' && freeformTags.value = 'true')"
```

3. Custom Alerts
Configure alerts when new public buckets are created without the appropriate tag:

```hclresource
"oci_events_rule" "public_bucket_without_tag" {
  compartment_id = var.compartment_ocid
  display_name   = "Alert on untagged public bucket"
  is_enabled     = true
  
  condition = <<-EOT
    {
      "eventType": ["com.oraclecloud.objectstorage.createbucket", "com.oraclecloud.objectstorage.updatebucket"],
      "data": {
        "additionalDetails": {
          "publicAccessType": ["ObjectRead", "ObjectReadWithoutList"]
        }
      }
    }
  EOT
  
  actions {
    actions {
      action_type = "ONS"
      is_enabled  = true
      topic_id    = oci_ons_notification_topic.security_alerts.id
      description = "Notify security team of untagged public bucket"
    }
  }
}

# Create ONS topic for alerts
resource "oci_ons_notification_topic" "security_alerts" {
  compartment_id = var.compartment_ocid
  name           = "security-alerts"
  description    = "Security alerts for Cloud Guard exceptions"
}

# Subscribe to the topic
resource "oci_ons_subscription" "security_team_email" {
  compartment_id = var.compartment_ocid
  endpoint       = "security-team@example.com"
  protocol       = "EMAIL"
  topic_id       = oci_ons_notification_topic.security_alerts.id
}
```

4. Principle of Least Privilege
Ensure that only authorized users can apply the exception tag:
```hclresource
"oci_identity_policy" "tag_management" {
  compartment_id = var.tenancy_ocid
  name           = "security-exceptions-tag-policy"
  description    = "Control security exception tags"
  
  statements = [
    "Allow group SecurityAdmins to manage buckets in compartment ocilabs where request.user.name != 'unauthorized-user'",
    "Allow group SecurityAdmins to use tag-namespaces in tenancy where target.tag-namespace.name='SecurityExceptions'"
  ]
}
```

5. Automation Script
Create a script to automate the tagging process for multiple buckets:
```bash
#!/bin/bash
# tag-public-buckets.sh

NAMESPACE=$(oci os ns get --query 'data' --raw-output)
COMPARTMENT_ID="<ocilabs-compartment-ocid>"

# Array of public buckets that should be tagged
PUBLIC_BUCKETS=("publicBucket" "research-data" "open-datasets")

for bucket in "${PUBLIC_BUCKETS[@]}"; do
  echo "Tagging bucket: $bucket"
  oci os bucket update \
    --bucket-name "$bucket" \
    --namespace "$NAMESPACE" \
    --freeform-tags '{"exception":"true"}' \
    --compartment-id "$COMPARTMENT_ID" \
    --force
  
  if [ $? -eq 0 ]; then
    echo "✓ Successfully tagged $bucket"
  else
    echo "✗ Failed to tag $bucket"
  fi
done
```

### Monitoring and Auditing
Implement logging to track changes to Detection Rules and tagged resources:

```bash
# Enable Cloud Guard logging
oci logging log create \
  --display-name "cloudguard-config-changes" \
  --log-group-id <log-group-ocid> \
  --log-type SERVICE \
  --configuration '{
    "source": {
      "sourceType": "OCISERVICE",
      "service": "cloudguard",
      "resource": "<target-ocid>",
      "category": "write"
    },
    "archiving": {
      "isEnabled": true
    }
  }'

# Enable Object Storage logging for bucket updates
oci logging log create \
  --display-name "bucket-modification-logs" \
  --log-group-id <log-group-ocid> \
  --log-type SERVICE \
  --configuration '{
    "source": {
      "sourceType": "OCISERVICE",
      "service": "objectstorage",
      "resource": "publicBucket",
      "category": "write"
    }
  }'
```

## Conclusion
Modifying Cloud Guard Detection Rules to exclude specific resources through custom tags is the most professional and maintainable way to manage intentionally public buckets in OCI. This strategy allows you to:

Maintain a robust security posture
Reduce false positive alert noise
Scale your infrastructure without compromising security
Maintain visibility and control over exceptions

For the specific case of publicBucket in the ocilabs compartment with the exception:true tag, this approach ensures that your research datasets remain accessible while Cloud Guard continues to protect the rest of your infrastructure.
Remember that security is an ongoing process. Establish clear procedures for exception management, document all decisions, and regularly review your configuration to ensure it remains aligned with your organization's needs.

Happy scripting!
