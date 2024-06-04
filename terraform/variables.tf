variable "vault" {
  type = object({
    uri          = string
    api_key_path = string
  })
}

variable "atlas" {
  type = object({
    project_id = string
  })
}

variable "azure" {
  type = object({
    region = string
    prefix = string
  })
}
