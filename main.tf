# Certificate
resource "aws_acm_certificate" "cert" {
  domain_name       = "*.${var.name}.${var.domain}"
  validation_method = "DNS"

  tags = {
    NameArea    = var.area
    NameClient  = var.name
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_record" {
  for_each = {
    for options in aws_acm_certificate.cert.domain_validation_options : options.domain_name => {
      name   = options.resource_record_name
      record = options.resource_record_value
      type   = options.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.aws_route53_zone_id
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_record : record.fqdn]
}

# Bucket
resource "aws_s3_bucket" "client" {
  for_each  = toset(var.environments)

  bucket    = "${each.key}.${var.name}.${var.domain}"
  acl       = "public-read"
  policy    = templatefile("${path.module}/policies/s3-public-read.json", {
    bucket  = "${each.key}.${var.name}.${var.domain}"
  })

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["HEAD", "GET", "PUT", "POST"]
    allowed_origins = ["https://${each.key}.${var.name}.${var.domain}"]
  }

  website {
    index_document  = "index.html"
    error_document  = "index.html"
  }

  tags = {
    NameArea    = var.area
    NameClient  = var.name
    Environment = each.key
  }
}

# CloudFront
resource "aws_cloudfront_distribution" "cdn" {
  for_each  = toset(var.environments)
  origin {
    domain_name = aws_s3_bucket.client[each.key].website_endpoint
    origin_id   = aws_s3_bucket.client[each.key].id

    custom_origin_config {
      http_port              = "80"
      https_port             = "443"
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1", "TLSv1.1", "TLSv1.2"]
    }
  }

  aliases             = [aws_s3_bucket.client[each.key].id]

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.client[each.key].id

    forwarded_values {
      query_string = true
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  tags = {
    NameArea    = var.area
    NameClient  = var.name
    Environment = each.key
  }

  viewer_certificate {
    acm_certificate_arn       = aws_acm_certificate.cert.arn
    ssl_support_method        = "sni-only"
    minimum_protocol_version  = "TLSv1"
  }
}

# Route53
resource "aws_route53_record" "root_domain" {
  for_each  = toset(var.environments)

  zone_id   = var.aws_route53_zone_id
  name      = "${each.key}.${var.name}.${var.domain}"
  type      = "A"

  alias {
    name                   = aws_cloudfront_distribution.cdn[each.key].domain_name
    zone_id                = aws_cloudfront_distribution.cdn[each.key].hosted_zone_id
    evaluate_target_health = false
  }
}

# IAM
resource "aws_iam_user" "pipeline" {
  for_each  = toset(var.environments)

  name      = "s3-${var.name}-${each.key}"

  tags = {
    NameArea    = var.area
    NameClient  = var.name
    Environment = each.key
  }
}

resource "aws_iam_access_key" "pipeline" {
  for_each  = toset(var.environments)

  user      = aws_iam_user.pipeline[each.key].name
}

resource "aws_iam_user_policy" "pipeline" {
  for_each  = toset(var.environments)

  user      = aws_iam_user.pipeline[each.key].name
  policy    = templatefile("${path.module}/policies/s3-full-access-and-cloudfront-invalidation.json", {
    bucket_arn      = aws_s3_bucket.client[each.key].arn
    cloudfront_arn  = aws_cloudfront_distribution.cdn[each.key].arn
  })
}

# Github Actions Secret
resource "github_actions_secret" "aws_access_key_id" {
  for_each        = toset(var.environments)

  repository      = var.github_repository
  secret_name     = "${upper(each.key)}_AWS_ACCESS_KEY_ID"
  plaintext_value = aws_iam_access_key.pipeline[each.key].id
}

resource "github_actions_secret" "aws_secret_access_key" {
  for_each        = toset(var.environments)

  repository      = var.github_repository
  secret_name     = "${upper(each.key)}_AWS_SECRET_ACCESS_KEY"
  plaintext_value = aws_iam_access_key.pipeline[each.key].secret
}

resource "github_actions_secret" "aws_region" {
  for_each        = toset(var.environments)

  repository      = var.github_repository
  secret_name     = "${upper(each.key)}_AWS_REGION"
  plaintext_value = aws_s3_bucket.client[each.key].region
}

resource "github_actions_secret" "s3_bucket" {
  for_each        = toset(var.environments)

  repository      = var.github_repository
  secret_name     = "${upper(each.key)}_AWS_S3_BUCKET"
  plaintext_value = aws_s3_bucket.client[each.key].bucket
}

resource "github_actions_secret" "cdn" {
  for_each        = toset(var.environments)

  repository      = var.github_repository
  secret_name     = "${upper(each.key)}_AWS_CLOUDFRONT_DISTRIBUTION_ID"
  plaintext_value = aws_cloudfront_distribution.cdn[each.key].id
}
