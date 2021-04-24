variable "tags" {
  type        = map(any)
  description = "Tags to apply to the resources"
}

variable "domain_name" {
  type        = string
  description = "DNS Name to use for all cluster resources. Applied in DHCP option set"
}