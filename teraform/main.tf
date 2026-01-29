########################
# Provider & backend
########################
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

########################
# S3 Buckets
########################

resource "aws_s3_bucket" "raw" {
  bucket = "weather-csv-raw-data-${var.env}"
}

resource "aws_s3_bucket" "processed" {
  bucket = "weather-csv-processed-data-${var.env}"
}

resource "aws_s3_bucket" "final" {
  bucket = "weather-csv-final-data-${var.env}"
}

########################
# IAM pour Lambda
########################

resource "aws_iam_role" "lambda_role" {
  name = "labRol-lambda-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-s3-logs-${var.env}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.raw.arn,
          "${aws_s3_bucket.raw.arn}/*",
          aws_s3_bucket.processed.arn,
          "${aws_s3_bucket.processed.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

########################
# Lambda function
########################

resource "aws_lambda_function" "preprocess" {
  function_name = "CSV-Preprocessor-function-${var.env}"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.lambda_handler"
  runtime       = "python3.11"

  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda-function.zip")

  environment {
    variables = {
      PROCESSED_BUCKET = aws_s3_bucket.processed.bucket
    }
  }
}

########################
# Trigger S3 -> Lambda
########################

resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.preprocess.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw.arn
}

resource "aws_s3_bucket_notification" "raw_notification" {
  bucket = aws_s3_bucket.raw.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.preprocess.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

########################
# Glue Data Catalog & Crawler
########################

resource "aws_glue_catalog_database" "csv_data_pipeline_catalog" {
  name = "csv-data-pipline-catalog-${var.env}"
}

resource "aws_iam_role" "glue_role" {
  name = "labRol-glue-${var.env}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "glue_policy" {
  name = "csv-glue-policy-${var.env}"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.processed.arn,
          "${aws_s3_bucket.processed.arn}/*",
          aws_s3_bucket.final.arn,
          "${aws_s3_bucket.final.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_glue_crawler" "processed_crawler" {
  name          = "csv-data-pipline-crawler-${var.env}"
  role          = aws_iam_role.glue_role.arn
  database_name = aws_glue_catalog_database.csv_data_pipeline_catalog.name

  s3_target {
    path = "s3://${aws_s3_bucket.processed.bucket}/processed/"
  }

  schedule = "cron(0 * * * ? *)"
}

########################
# Glue Job (ETL processed -> final)
########################

resource "aws_s3_bucket" "scripts" {
  bucket = "csv-glue-scripts-${var.env}"
}

resource "aws_s3_object" "glue_job_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "scripts/etl_csv_to_final.py"
  source = "${path.module}/scripts/etl_csv_to_final.py"
  etag   = filemd5("${path.module}/scripts/etl_csv_to_final.py")
}

resource "aws_glue_job" "csv_transformation" {
  name     = "csvTransformation-${var.env}"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.scripts.bucket}/${aws_s3_object.glue_job_script.key}"
    python_version  = "3"
  }

  default_arguments = {
    "--TempDir"      = "s3://${aws_s3_bucket.processed.bucket}/tmp/"
    "--FINAL_BUCKET" = aws_s3_bucket.final.bucket
    "--job-language" = "python"
  }

  max_retries = 0
}
