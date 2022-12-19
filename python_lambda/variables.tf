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
  default = []
}

variable "file-path" {
  type = string
  default = ""
}

variable "environment-variables" {
  type = map(string)
  default = {}
}

variable "code" {
  type = string
  default = ""
}