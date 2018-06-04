variable "name" {}

variable "bucket_name" {}

variable "basic_auth_user" {
  default = ""
}

variable "basic_auth_password" {
  default = ""
}

variable "domain" {
  default = ""
}

variable "acm_certificate_arn" {
  default = ""
}

variable "route53_zone_id" {
  default = ""
}

variable "cdn_price_class" {
  default = "PriceClass_All"
}

variable "not_found_file_path" {
  default = "/404.html"
}

variable "secret_hash_for_origin_check" {
  default = "mrwhiskersrulestheworld"
}
