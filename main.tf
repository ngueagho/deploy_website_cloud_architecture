provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    apigateway     = "http://localhost:4566"
    apigatewayv2   = "http://localhost:4566"
    cloudformation = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    ec2            = "http://localhost:4566"
    es             = "http://localhost:4566"
    elasticache    = "http://localhost:4566"
    firehose       = "http://localhost:4566"
    iam            = "http://localhost:4566"
    kinesis        = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    rds            = "http://localhost:4566"
    redshift       = "http://localhost:4566"
    route53        = "http://localhost:4566"
    s3             = "http://localhost:4566"
    secretsmanager = "http://localhost:4566"
    ses            = "http://localhost:4566"
    sns            = "http://localhost:4566"
    sqs            = "http://localhost:4566"
    ssm            = "http://localhost:4566"
    stepfunctions  = "http://localhost:4566"
    sts            = "http://localhost:4566"
    waf            = "http://localhost:4566"
    cloudfront     = "http://localhost:4566"
    acm            = "http://localhost:4566"
    shield         = "http://localhost:4566"
    wafv2          = "http://localhost:4566"
    wafregional    = "http://localhost:4566"
  }
}

# Créer un bucket S3
resource "aws_s3_bucket" "static_site" {
  bucket = "my-static-site"
  acl    = "private"

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  tags = {
    Name        = "MyStaticSite"
    Environment = "Dev"
  }
}

# Télécharger des fichiers statiques vers le bucket S3
resource "aws_s3_bucket_object" "index" {
  bucket = aws_s3_bucket.static_site.bucket
  key    = "index.html"
  source = "index.html"
  acl    = "private"
}

resource "aws_s3_bucket_object" "error" {
  bucket = aws_s3_bucket.static_site.bucket
  key    = "error.html"
  source = "error.html"
  acl    = "private"
}

# Créer une OAI CloudFront
resource "aws_cloudfront_origin_access_identity" "aoi" {
  comment = "OAI for my S3 bucket"
}

# Définir une politique de bucket S3 pour permettre l'accès via l'OAI
resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.static_site.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.aoi.cloudfront_access_identity_path}"
        }
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.static_site.arn}/*"
      }
    ]
  })
}

# Créer une distribution CloudFront
resource "aws_cloudfront_distribution" "cloudfront_distribution" {
  origin {
    domain_name = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.static_site.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.aoi.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "My CloudFront Distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.static_site.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Créer une règle WAF
resource "aws_waf_rule" "example_rule" {
  name        = "example-rule"
  metric_name = "exampleRule"

  predicates {
    data_id = aws_waf_byte_match_set.example_byte_set.id
    negated = false
    type    = "ByteMatch"
  }
}

# Créer un ensemble de correspondance de byte WAF
resource "aws_waf_byte_match_set" "example_byte_set" {
  name = "example-byte-match-set"

  byte_match_tuples {
    field_to_match {
      type = "URI"
    }
    positional_constraint = "STARTS_WITH"
    target_string         = "/example"
    text_transformation   = "NONE"
  }
}


# Créer une zone hébergée Route 53
resource "aws_route53_zone" "example_zone" {
  name = "example.com"
}

# Créer un enregistrement A dans Route 53
resource "aws_route53_record" "example_record" {
  zone_id = aws_route53_zone.example_zone.zone_id
  name    = "www"
  type    = "A"
  ttl     = "300"
  records = ["127.0.0.1"]
}

# Créer un certificat ACM
resource "aws_acm_certificate" "example_cert" {
  domain_name       = "example.com"
  validation_method = "DNS"
}
