variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west1"
}

variable "zone" {
  type    = string
  default = "europe-west1-b"
}

variable "name_prefix" {
  type    = string
  default = "pycon"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,14}$", var.name_prefix))
    error_message = "name_prefix must match ^[a-z][a-z0-9-]{1,14}$."
  }
}

variable "stage" {
  description = "on = GKE cluster, node pools and the demo's service account key exist; off = only the cheap parts remain."
  type        = string
  default     = "off"
  validation {
    condition     = contains(["on", "off"], var.stage)
    error_message = "stage must be on or off."
  }
}

variable "spot" {
  description = "Spot nodes for rehearsals. Never on talk day: a reclaimed node ends the demo."
  type        = bool
  default     = false
}

variable "app_machine_type" {
  description = "Node type for each side. os.cpu_count() inside the pods reports this machine's vCPUs."
  type        = string
  default     = "e2-standard-8"
}

variable "tools_machine_type" {
  type    = string
  default = "e2-standard-4"
}

variable "vm_ssh_user" {
  type    = string
  default = "demo"
}

variable "vm_ssh_public_key_file" {
  description = "Public key allowed to log in to the VM through IAP."
  type        = string
  default     = "~/.ssh/pycon-vm.pub"
}

variable "vm_and_cloud_run" {
  description = "Also create the VM and the Cloud Run probe that compare os.cpu_count() outside a pod."
  type        = bool
  default     = false
}
