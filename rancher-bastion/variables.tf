variable "subnet_id" {
  description = "Subnet ID where bastion will be deployed"
}

variable "vpc_id" {
  description = "VPC ID where resources will be deployed"
}

variable "key_name" {
  description = "Key name to attach to instances for SSH access"
}

variable "volume_size" {
  type        = number
  description = "Volume size for bastion / register server in Gigabytes"
  default     = 100
}

variable "tags" {
  type        = map(any)
  description = "Tags to apply to the resources"
}