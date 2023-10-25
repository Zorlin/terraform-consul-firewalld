variable "services" {
  description = "Consul services monitored by CTS"
  type        = map(any)
  default     = {}
}
