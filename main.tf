locals {
  have_basic_auth = "${var.basic_auth_user != "" && var.basic_auth_password != ""}"
}

/*
==== ALERT ====
Remember to apply the changes on both "aws_cloudfront_distribution.site"
and "aws_cloudfront_distribution.site_with_auth" resources!

These resources are intentionally DUPLICATED!

This is the only workaround to add/remove conditionally the
"lambda_function_association" configuration block

https://github.com/hashicorp/terraform/issues/7034
*/

resource "aws_cloudfront_distribution" "site" {
  count               = "${local.have_basic_auth ? 0 : 1}"
  aliases             = "${compact(list(var.domain))}"
  default_root_object = "index.html"
  enabled             = true
  http_version        = "http2"
  price_class         = "${var.cdn_price_class}"

  custom_error_response {
    error_caching_min_ttl = "360"
    error_code            = "404"
    response_code         = "200"
    response_page_path    = "${var.not_found_file_path}"
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "DELETE", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    default_ttl            = "3600"
    max_ttl                = "86400"
    min_ttl                = "0"
    target_origin_id       = "${aws_s3_bucket.site.id}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  }

  origin {
    origin_id   = "${aws_s3_bucket.site.id}"
    domain_name = "${aws_s3_bucket.site.website_endpoint}"

    custom_header {
      name  = "User-Agent"
      value = "${var.secret_hash_for_origin_check}"
    }

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1"]
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = "${var.acm_certificate_arn}"
    cloudfront_default_certificate = "${var.acm_certificate_arn == "" ? true : false}"
    minimum_protocol_version       = "TLSv1"
    ssl_support_method             = "sni-only"
  }

  tags {
    Name = "${var.name}"
  }
}

resource "aws_cloudfront_distribution" "site_with_auth" {
  count               = "${local.have_basic_auth ? 1 : 0}"
  aliases             = "${compact(list(var.domain))}"
  default_root_object = "index.html"
  enabled             = true
  http_version        = "http2"
  price_class         = "${var.cdn_price_class}"

  custom_error_response {
    error_caching_min_ttl = "360"
    error_code            = "404"
    response_code         = "200"
    response_page_path    = "${var.not_found_file_path}"
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "DELETE", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    default_ttl            = "3600"
    max_ttl                = "86400"
    min_ttl                = "0"
    target_origin_id       = "${aws_s3_bucket.site.id}"
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    lambda_function_association {
      event_type = "viewer-request"
      lambda_arn = "${aws_lambda_function.site_auth_lambda.qualified_arn}"
    }
  }

  origin {
    origin_id   = "${aws_s3_bucket.site.id}"
    domain_name = "${aws_s3_bucket.site.website_endpoint}"

    custom_header {
      name  = "User-Agent"
      value = "${var.secret_hash_for_origin_check}"
    }

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1"]
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn            = "${var.acm_certificate_arn}"
    cloudfront_default_certificate = "${var.acm_certificate_arn == "" ? true : false}"
    minimum_protocol_version       = "TLSv1"
    ssl_support_method             = "sni-only"
  }

  tags {
    Name = "${var.name}"
  }
}

resource "aws_s3_bucket" "site" {
  acl    = "private"
  bucket = "${var.bucket_name}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadAccess",
      "Principal": {
        "AWS": "*"
      },
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::${var.bucket_name}/*",
      "Condition": {
        "StringEquals": {
          "aws:UserAgent": "${var.secret_hash_for_origin_check}"
        }
      }
    }
  ]
}
EOF

  website {
    error_document = "error.html"
    index_document = "index.html"
  }

  tags {
    Name = "${var.name}"
  }
}

resource "aws_route53_record" "site" {
  count   = "${var.route53_zone_id == "" ? 0 : 1}"
  zone_id = "${var.route53_zone_id}"
  name    = "${var.domain}"
  type    = "CNAME"
  ttl     = "300"
  records = "${concat(aws_cloudfront_distribution.site.*.domain_name, aws_cloudfront_distribution.site_with_auth.*.domain_name)}"
}

# Basic auth lambda
resource "aws_iam_role" "site_auth" {
  count  = "${local.have_basic_auth ? 1 : 0}"
  name   = "${var.name}-edgelambda-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com",
          "edgelambda.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "template_file" "site_auth_function" {
  count    = "${local.have_basic_auth ? 1 : 0}"
  template = "${file("${path.module}/basic_auth_function.js")}"

  vars {
    user     = "${var.basic_auth_user}"
    password = "${var.basic_auth_password}"
  }
}

data "archive_file" "site_auth_package" {
  count       = "${local.have_basic_auth ? 1 : 0}"
  type        = "zip"
  output_path = "${path.module}/basic_auth_function.zip"

  source {
    content  = "${data.template_file.site_auth_function.rendered}"
    filename = "basic_auth_function.js"
  }
}

resource "aws_lambda_function" "site_auth_lambda" {
  count            = "${local.have_basic_auth ? 1 : 0}"
  filename         = "${data.archive_file.site_auth_package.output_path}"
  function_name    = "${var.name}-basic-auth"
  handler          = "basic_auth_function.handler"
  publish          = true
  role             = "${aws_iam_role.site_auth.arn}"
  runtime          = "nodejs8.10"
  source_code_hash = "${data.archive_file.site_auth_package.output_base64sha256}"
}