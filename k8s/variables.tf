variable "mongodb_username" {
  type = string
}

variable "mongodb_password" {
    type = string
    sensitive = true
}