variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "environment" {
  type        = string
  description = "Environment name"
}

variable "geo_blocked_countries" {
  type        = list(string)
  description = "List of ISO country codes to block"
  default     = []
}
