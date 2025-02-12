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