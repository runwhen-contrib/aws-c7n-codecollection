
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "null_resource" "check_bucket_existence" {
  provisioner "local-exec" {
    command = <<EOT
    BUCKET_NAME="${var.bucket_prefix}-${random_id.bucket_suffix.hex}"
    if aws s3api head-bucket --bucket $BUCKET_NAME 2>/dev/null; then
      echo "Bucket $BUCKET_NAME already exists. Exiting."
      exit 1
    else
      echo "Bucket $BUCKET_NAME does not exist. Proceeding."
    fi
    EOT
  }
}

resource "aws_s3_bucket" "unique_bucket" {
  depends_on = [null_resource.check_bucket_existence]

  bucket = "${var.bucket_prefix}-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "Public S3 Bucket"
    Environment = "Development"
  }
}


resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket                  = aws_s3_bucket.unique_bucket.id
  block_public_acls       = false
  ignore_public_acls      = false
  block_public_policy     = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_bucket_policy" {
  bucket = aws_s3_bucket.unique_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.unique_bucket.arn}/*"
      }
    ]
  })
}
