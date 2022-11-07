variable "instance-type" {
  type = string
}

variable "security-group-ids" {
  type = list(string)
}

variable "subnet-id" {
  type = string
}

variable "managed-policy-arns" {
  type = set(string)
  default = []
}

variable "name" {
  type = string
}

variable "user-data" {
  type = string
}