output "cdn_hostname" {
  value = "${element(concat(aws_cloudfront_distribution.site.*.domain_name, aws_cloudfront_distribution.site_with_auth.*.domain_name), 0)}"
}

output "cdn_id" {
  value = "${element(concat(aws_cloudfront_distribution.site.*.id, aws_cloudfront_distribution.site_with_auth.*.id), 0)}"
}

output "bucket_id" {
  value = "${aws_s3_bucket.site.id}"
}
