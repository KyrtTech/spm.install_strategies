variable "env" {
  description = "The environment for the resources"
  type        = string
  default     = "dev"
}

variable "product" {
  description = "The owner of the resources"
  type        = string
  default     = "default-product"
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "us-west-2"
}

variable "output_file" {
  description = "Output file for SPM vars"
  type        = string
  default     = "output.json"
}
