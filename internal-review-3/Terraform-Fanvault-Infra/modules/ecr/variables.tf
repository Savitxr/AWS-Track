variable "project_name" {
  type        = string
  description = "Project name"
}

variable "environment" {
  type        = string
  description = "Environment"
}

variable "repository_names" {
  type        = list(string)
  description = "List of repository names to create"
  default     = ["frontend", "user-service", "commerce-service"]
}

variable "owner" {
  type        = string
  description = "Owner tag for all resources in this module"
  default     = "platform-team"
}
