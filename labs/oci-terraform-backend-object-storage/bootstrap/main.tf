# Bootstrap stack from the post, unchanged except:
#  - bucket name is a variable (lab default: tfstate-lab)
#  - prevent_destroy removed so 90-teardown.sh can clean up (keep it in real use)
#  - time_sleep after the policies, as the post suggests for propagation lag

terraform {
  required_version = ">= 1.12.0"
  required_providers {
    oci  = { source = "oracle/oci", version = "~> 9.12" }
    time = { source = "hashicorp/time", version = "~> 0.12" }
  }
  # no backend block yet: local state, migrated later by 20-migrate.sh
}

provider "oci" {
  region              = var.region
  config_file_profile = var.config_file_profile
}

variable "tenancy_ocid" {}
variable "compartment_id" {}
variable "region" { default = "sa-saopaulo-1" }
variable "bucket_name" { default = "tfstate-lab" }
variable "config_file_profile" { default = "DEFAULT" }

data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.tenancy_ocid
}

resource "oci_kms_vault" "state" {
  compartment_id = var.compartment_id
  display_name   = "tfstate-vault"
  vault_type     = "DEFAULT"
}

resource "oci_kms_key" "state" {
  compartment_id      = var.compartment_id
  display_name        = "tfstate-key"
  management_endpoint = oci_kms_vault.state.management_endpoint
  protection_mode     = "SOFTWARE"

  key_shape {
    algorithm = "AES"
    length    = 32
  }
}

resource "oci_identity_policy" "objectstorage_kms" {
  compartment_id = var.compartment_id
  name           = "objectstorage-use-tfstate-key"
  description    = "Allow Object Storage to use the tfstate key"
  statements = [
    "Allow service objectstorage-${var.region} to use keys in compartment id ${var.compartment_id} where target.key.id = '${oci_kms_key.state.id}'",
  ]
}

resource "oci_identity_policy" "objectstorage_lifecycle" {
  compartment_id = var.tenancy_ocid
  name           = "objectstorage-lifecycle"
  description    = "Allow Object Storage lifecycle to purge old state versions"
  statements = [
    "Allow service objectstorage-${var.region} to manage object-family in compartment id ${var.compartment_id}",
  ]
}

resource "time_sleep" "policy_propagation" {
  depends_on      = [oci_identity_policy.objectstorage_kms, oci_identity_policy.objectstorage_lifecycle]
  create_duration = "30s"
}

resource "oci_objectstorage_bucket" "tfstate" {
  compartment_id        = var.compartment_id
  namespace             = data.oci_objectstorage_namespace.ns.namespace
  name                  = var.bucket_name
  access_type           = "NoPublicAccess"
  versioning            = "Enabled"
  storage_tier          = "Standard"
  kms_key_id            = oci_kms_key.state.id
  object_events_enabled = true

  depends_on = [time_sleep.policy_propagation]
}

resource "oci_objectstorage_object_lifecycle_policy" "tfstate" {
  namespace = data.oci_objectstorage_namespace.ns.namespace
  bucket    = oci_objectstorage_bucket.tfstate.name

  rules {
    name        = "purge-old-state-versions"
    action      = "DELETE"
    target      = "previous-object-versions"
    time_amount = 30
    time_unit   = "DAYS"
    is_enabled  = true
  }

  rules {
    name        = "abort-stale-multipart"
    action      = "ABORT"
    target      = "multipart-uploads"
    time_amount = 1
    time_unit   = "DAYS"
    is_enabled  = true
  }

  depends_on = [time_sleep.policy_propagation]
}

resource "oci_logging_log_group" "tfstate" {
  compartment_id = var.compartment_id
  display_name   = "tfstate-access"
}

resource "oci_logging_log" "tfstate_read" {
  display_name       = "tfstate-read"
  log_group_id       = oci_logging_log_group.tfstate.id
  log_type           = "SERVICE"
  retention_duration = 30
  is_enabled         = true

  configuration {
    compartment_id = var.compartment_id
    source {
      category    = "read"
      resource    = oci_objectstorage_bucket.tfstate.name
      service     = "objectstorage"
      source_type = "OCISERVICE"
    }
  }
}

resource "oci_logging_log" "tfstate_write" {
  display_name       = "tfstate-write"
  log_group_id       = oci_logging_log_group.tfstate.id
  log_type           = "SERVICE"
  retention_duration = 30
  is_enabled         = true

  configuration {
    compartment_id = var.compartment_id
    source {
      category    = "write"
      resource    = oci_objectstorage_bucket.tfstate.name
      service     = "objectstorage"
      source_type = "OCISERVICE"
    }
  }
}

output "namespace" { value = data.oci_objectstorage_namespace.ns.namespace }
output "bucket" { value = oci_objectstorage_bucket.tfstate.name }
output "key_id" { value = oci_kms_key.state.id }
output "vault_id" { value = oci_kms_vault.state.id }
output "log_group_id" { value = oci_logging_log_group.tfstate.id }
output "read_log_id" { value = oci_logging_log.tfstate_read.id }
output "write_log_id" { value = oci_logging_log.tfstate_write.id }
