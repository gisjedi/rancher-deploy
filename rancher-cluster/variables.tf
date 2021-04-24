variable "subnet_ids" {
  description = "Subnet IDs where nodes"
}

variable "vpc_id" {
  description = "VPC ID where resources will be deployed"
}

variable "key_name" {
  description = "Key name to attach to instances for SSH access"
}

variable "tags" {
  type        = map(any)
  description = "Tags to apply to the resources"
}

variable "instance_profile" {
  type        = string
  description = "Name of instance profile to apply to cluster nodes"
}

variable "volume_size" {
  type        = number
  description = "Volume size for bastion / register server in Gigabytes"
  default     = 100
}

