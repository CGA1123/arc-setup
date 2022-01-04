variable "subscription_id" {
  description = "The Azure subscription id to use"
  type        = string
}

variable "resource_group" {
  description = "The resource group name to create"
  type        = string
}

variable "location" {
  description = "The Azure region to provision resources in"
  type        = string
}

variable "dns_prefix" {
  description = "A custom DNS prefix for the webhook server (must be unique)"
  type        = string
}

variable "letsencrypt_email" {
  description = "An email address to use for letsencrypt certificate generation"
  type        = string
}

variable "enterprise_url" {
  description = "GitHub Enterprise Server URL"
  type        = string
  default     = ""
}

variable "app_id" {
  description = "The GitHub App ID to be used to manage runners"
  type        = string
}

variable "installation_id" {
  description = "The GitHub App Installation ID for the GitHub App"
  type        = string
}

variable "private_key" {
  description = "The private key for the GitHub App, required to make API calls to GitHub"
  type        = string
  sensitive   = true
}

variable "webhook_secret" {
  description = "The GitHub App Webhook signing secret"
  type        = string
  sensitive   = true
}

variable "organization" {
  description = "The name of the organization for which to manager runners"
  type        = string
}

variable "runner_group" {
  description = "The name of the runner group to manager"
  type        = string
}
