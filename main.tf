provider aws {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

resource aws_lambda_function "lambci-function" {
  function_name = "${var.lambci_instance}-build"
  description   = "LambCI build function for stack: ${var.lambci_instance}"
  handler       = "index.handler"
  memory_size   = "1536"
  timeout       = "300"

  s3_bucket     = "lambci-${var.aws_region}"
  s3_key        = "fn/lambci-build-${var.lambci_version}.zip"
  runtime       = "nodejs4.3"
}

resources aws_iam_role "LambdaExecution" {
  name  = "${var.lambci_instance}-LambdaExcution-role"
  
  lifecycle {
    create_before_destroy = true
  }

  # Sometimes an IAM role will exist but not be ready
  provisioner "local-exec" {
    command = "sleep 30"
  }

  assume_policy_role = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": [
                    "lambda.amazonaws.com"
                ]
            },
            "Action": [
                "sts:AssumeRole"
            ]
        }
    ]
}  
EOF

}
