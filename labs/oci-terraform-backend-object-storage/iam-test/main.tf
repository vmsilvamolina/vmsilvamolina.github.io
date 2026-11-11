# Throwaway non-admin identity for the OBJECT_OVERWRITE and prefix tests.
# The API public key is generated locally by 50-overwrite-test.sh (private key never touches state).
#
# policy_mode:
#   four   -> the HashiCorp-docs policy from the opening of the post (expected to fail on 2nd apply)
#   four_rb-> four permissions + read buckets (isolates OBJECT_OVERWRITE from read buckets)
#   five_norb -> five permissions, no read buckets
#   five   -> the corrected policy (+ OBJECT_OVERWRITE, + read buckets)
#   prefix -> five permissions scoped with target.object.name = /network\/*/

terraform {
  required_version = ">= 1.12.0"
  required_providers {
    oci = { source = "oracle/oci", version = "~> 9.12" }
  }
}

provider "oci" {
  region              = var.region
  config_file_profile = var.config_file_profile
}

variable "tenancy_ocid" {}
variable "compartment_id" {}
variable "compartment_name" { default = "tfstate" }
variable "region" { default = "sa-saopaulo-1" }
variable "bucket_name" { default = "tfstate-lab" }
variable "config_file_profile" { default = "DEFAULT" }
variable "public_key_path" {}

variable "policy_mode" {
  default = "four"
  validation {
    condition     = contains(["four", "four_rb", "five_norb", "five", "prefix", "prefix_split"], var.policy_mode)
    error_message = "policy_mode must be four, four_rb, five_norb, five, prefix or prefix_split."
  }
}

locals {
  perms4 = ["OBJECT_INSPECT", "OBJECT_READ", "OBJECT_CREATE", "OBJECT_DELETE"]
  perms5 = concat(local.perms4, ["OBJECT_OVERWRITE"])
  perms  = startswith(var.policy_mode, "four") ? local.perms4 : local.perms5
  any    = join(",\n      ", [for p in local.perms : "request.permission = '${p}'"])

  prefix_cond = var.policy_mode == "prefix" ? "\n    target.object.name = /network\\/*/," : ""

  objects_stmt = <<-EOT
    Allow group tfstate-lab-operators to manage objects in compartment ${var.compartment_name}
      where all {
        target.bucket.name = '${var.bucket_name}',${local.prefix_cond}
        any {
          ${local.any}
        }
      }
  EOT

  # prefix_split: the proposed CI fix. Listing is bucket-wide (names only), everything else is prefix-scoped.
  split_stmts = [
    <<-EOT
    Allow group tfstate-lab-operators to manage objects in compartment ${var.compartment_name}
      where all {
        target.bucket.name = '${var.bucket_name}',
        request.permission = 'OBJECT_INSPECT'
      }
    EOT
    ,
    <<-EOT
    Allow group tfstate-lab-operators to manage objects in compartment ${var.compartment_name}
      where all {
        target.bucket.name = '${var.bucket_name}',
        target.object.name = /network\/*/,
        any {
          request.permission = 'OBJECT_READ',
          request.permission = 'OBJECT_CREATE',
          request.permission = 'OBJECT_OVERWRITE',
          request.permission = 'OBJECT_DELETE'
        }
      }
    EOT
  ]

  statements = (
    var.policy_mode == "prefix_split" ? local.split_stmts :
    contains(["four", "five_norb"], var.policy_mode) ? [local.objects_stmt] : [
      "Allow group tfstate-lab-operators to read buckets in compartment ${var.compartment_name} where target.bucket.name = '${var.bucket_name}'",
      local.objects_stmt,
    ]
  )
}

resource "oci_identity_group" "operators" {
  compartment_id = var.tenancy_ocid
  name           = "tfstate-lab-operators"
  description    = "Lab: least-privilege Terraform state operators"
}

resource "oci_identity_user" "operator" {
  compartment_id = var.tenancy_ocid
  name           = "tfstate-lab-operator"
  description    = "Lab: non-admin identity for the OBJECT_OVERWRITE test"
  email          = "tfstate-lab-operator@example.invalid"
}

resource "oci_identity_user_group_membership" "m" {
  group_id = oci_identity_group.operators.id
  user_id  = oci_identity_user.operator.id
}

resource "oci_identity_api_key" "operator" {
  user_id   = oci_identity_user.operator.id
  key_value = file(var.public_key_path)
}

resource "oci_identity_policy" "operators" {
  compartment_id = var.compartment_id
  name           = "tfstate-lab-operators"
  description    = "Lab policy, mode=${var.policy_mode}"
  statements     = local.statements
}

output "user_id" { value = oci_identity_user.operator.id }
output "fingerprint" { value = oci_identity_api_key.operator.fingerprint }
output "statements" { value = local.statements }
