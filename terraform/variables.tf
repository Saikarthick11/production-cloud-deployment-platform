variable "project_id" {
  description = "Existing GCP project ID with billing enabled; Terraform does not create a project."
  type        = string
}

variable "region" {
  description = "Region for the subnet and Docker registry."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "One zone in the selected region for this learning cluster."
  type        = string
  default     = "us-central1-a"
  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]-[a-z]$", var.zone))
    error_message = "Use a GCP zone such as us-central1-a."
  }
}

variable "admin_cidr" {
  description = "Your public IPv4 address followed by /32, allowed to reach the cluster API."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.admin_cidr)) && endswith(var.admin_cidr, "/32")
    error_message = "Set one valid IPv4 address with /32; broad internet access is not allowed."
  }
}

variable "deletion_protection" {
  description = "Protect the cluster from accidental deletion. Keep true during normal use."
  type        = bool
  default     = true
}
