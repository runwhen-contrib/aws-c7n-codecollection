# Create ACM Certificate
resource "aws_acm_certificate" "cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Environment = "development"
    Name        = "${var.domain_name}-certificate"
  }

  # Add www subdomain as subject alternative name
  subject_alternative_names = ["www.${var.domain_name}"]
}

# Output the certificate ARN
output "certificate_arn" {
  value = aws_acm_certificate.cert.arn
}

# Output the DNS validation records
output "validation_records" {
  value = aws_acm_certificate.cert.domain_validation_options
}


resource "tls_private_key" "example_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "one_day_cert" {
  private_key_pem = tls_private_key.example_key.private_key_pem

  subject {
    common_name  = "example1.com"
    organization = "Example One-Day"
  }

  // 24 hours = 1 day
  validity_period_hours = 24
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
  is_ca_certificate = false
}

resource "tls_self_signed_cert" "thirty_day_cert" {
  private_key_pem = tls_private_key.example_key.private_key_pem

  subject {
    common_name  = "example2.com"
    organization = "Example Thirty-Day"
  }

  // 720 hours = 30 days
  validity_period_hours = 720
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
  is_ca_certificate = false
}

resource "aws_acm_certificate" "one_day_acm_cert" {
  certificate_body = tls_self_signed_cert.one_day_cert.cert_pem
  private_key      = tls_private_key.example_key.private_key_pem

  // Self-signed cert => no certificate chain
  # certificate_chain = ...
}

resource "aws_acm_certificate" "thirty_day_acm_cert" {
  certificate_body = tls_self_signed_cert.thirty_day_cert.cert_pem
  private_key      = tls_private_key.example_key.private_key_pem
  # certificate_chain = ...
}