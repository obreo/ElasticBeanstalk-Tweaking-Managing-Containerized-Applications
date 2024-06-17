resource "aws_cloudfront_distribution" "distribution" {
  count         = length(var.Loadbalanced_resource_count) == length("true") ? 1 : 0
  origin {
    domain_name = "${aws_elastic_beanstalk_environment.environment[count.index].cname_prefix}.${var.region}.elasticbeanstalk.com"
    origin_id   = var.name


    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    origin_shield {
      enabled              = true
      origin_shield_region = "us-east-1"
    }
  }

  enabled         = true
  is_ipv6_enabled = true

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = var.name
    # Doc: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # Doc: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
    # Doc: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-response-headers-policies.html#managed-response-headers-policies-cors
    response_headers_policy_id = "60669652-455b-4ae9-85a4-c4c02393f86c"
    viewer_protocol_policy     = "https-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  tags = {
    Environment = ""
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  lifecycle {
    ignore_changes = [
      viewer_certificate
    ]
  }
}




resource "aws_cloudfront_distribution" "distribution_singleinstance" {
  count = length(var.singleinstance_resource_count) == length("true") ? 1 : 0
  origin {
    domain_name = "${aws_elastic_beanstalk_environment.environment_singleinstance[0].cname_prefix}.${var.region}.elasticbeanstalk.com"
    origin_id   = var.name


    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    origin_shield {
      enabled              = true
      origin_shield_region = "us-east-1"
    }
  }

  enabled         = true
  is_ipv6_enabled = true

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = var.name
    # Doc: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-cache-policies.html
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # Doc: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
    # Doc: https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-response-headers-policies.html#managed-response-headers-policies-cors
    response_headers_policy_id = "60669652-455b-4ae9-85a4-c4c02393f86c"
    viewer_protocol_policy     = "https-only"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  tags = {
    Environment = ""
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  lifecycle {
    ignore_changes = [
      viewer_certificate
    ]
  }
}
