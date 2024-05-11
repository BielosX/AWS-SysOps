variable "http_port" {
  type = number
}

variable "image_id" {
  type = string
}

variable "cidr_block" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "subnet_bits" {
  type = number
}

variable "app_port" {
  type = number
}
