variable "project_id" {
  type = string
}

variable "billing_account" {
  description = "Billing account ID, e.g. 012345-6789AB-CDEF01 (gcloud billing accounts list)."
  type        = string
}

variable "region" {
  type    = string
  default = "southamerica-west1"
}

variable "budget_amount" {
  type    = number
  default = 30
}

variable "budget_currency" {
  description = "Must match the billing account's currency."
  type        = string
  default     = "USD"
}
