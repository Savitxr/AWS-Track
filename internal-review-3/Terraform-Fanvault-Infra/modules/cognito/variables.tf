variable "project_name" {
  type        = string
  description = "The name of the project"
}

variable "environment" {
  type        = string
  description = "The environment (dev, prod, etc.)"
}

variable "callback_urls" {
  type        = list(string)
  description = "List of allowed callback URLs for the identity provider client"
  default     = ["http://localhost/callback"]
}

variable "logout_urls" {
  type        = list(string)
  description = "List of allowed logout URLs for the identity provider client"
  default     = ["http://localhost/logout"]
}

variable "domain_suffix" {
  type        = string
  description = "Optional suffix appended to the Cognito domain to ensure global uniqueness (e.g. account ID last 4 digits)"
  default     = ""
}

variable "owner" {
  type        = string
  description = "Owner tag for all resources in this module"
  default     = "platform-team"
}
