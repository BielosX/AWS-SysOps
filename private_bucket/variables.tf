variable "bucket-name" {
  type = string
}

variable "sse-s3-header-required" {
  type = bool
  default = false
}

variable "sse-kms-header-required" {
  type = bool
  default = false
}