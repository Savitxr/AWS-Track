variable "project_name" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment"
}

variable "secret_values" {
  type        = map(string)
  description = "Initial secret key-value pairs"
  default = {
    jwt_secret         = "placeholder-secret-replace-in-console-or-cicd"
    jwt_refresh_secret = "placeholder-refresh-secret-replace-in-console-or-cicd"
  }
  sensitive = true
}

variable "owner" {
  type        = string
  description = "Owner tag for all resources in this module"
  default     = "platform-team"
}
