variable "function-name" {
  type = string
}

variable "timeout" {
  type = number
  default = 60
}

variable "handler" {
  type = string
}

variable "managed-policy-arns" {
  type = list(string)
}

variable "file-path" {
  type = string
}

variable "environment-variables" {
  type = map(string)
}