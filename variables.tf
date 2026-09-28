variable "project_name" {
  description = "Project name used as prefix for all resources."
  type        = string
  default     = "floci-multilang-notifications"
}

variable "aws_region" {
  description = "AWS region (simulated by floci)."
  type        = string
  default     = "us-east-1"
}

variable "target_language_code" {
  description = "Target language code Amazon Translate translates notifications into."
  type        = string
  default     = "es"
}

variable "source_language_code" {
  description = "Source language code of the incoming notification text."
  type        = string
  default     = "en"
}
