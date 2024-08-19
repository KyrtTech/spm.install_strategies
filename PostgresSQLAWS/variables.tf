variable "ENV" {
  description = "The environment for the resources"
  type        = string
  default     = "dev"
}

variable "PRODUCT" {
  description = "The owner of the resources"
  type        = string
  default     = "default-product"
}

variable "REGION" {
  description = "AWS Region"
  type        = string
  default     = "us-west-2"
}

variable "OUTPUT_FILE" {
  description = "Output file for SPM vars"
  type        = string
  default     = "output.json"
}
