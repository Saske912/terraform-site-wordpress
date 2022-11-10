variable "namespace" {
  default = "default"
}

variable "vault-path" {
  type = string
}

variable "database" {
  type = object({
    host = string
    root-password = string
  })
}

variable "smtp" {
  type = object({
    host = string
    login = string
    password = string
  })
}

variable "name" {
  type = object({
    first= string
    last = string
  })
}

variable "blog-name" {
  type = string
}

variable "cluster" {
  type = object({
    domain = string
    issuer = string
  })
}