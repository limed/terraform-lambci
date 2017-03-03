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
  role          = "${aws_iam_role.LambdaExecution.arn}"
  s3_bucket     = "lambci-${var.aws_region}"
  s3_key        = "fn/lambci-build-${var.lambci_version}.zip"
  runtime       = "nodejs4.3"
}

resource aws_s3_bucket "BuildResults" {
  bucket  = "${var.lambci_instance}-buildresults"

  tags {
    Name  = "${var.lambci_instance}-buildresults"
  }
}

resource aws_iam_role "LambdaExecution" {
  name  = "${var.lambci_instance}-LambdaExcution-role"

  lifecycle {
    create_before_destroy = true
  }

  # Sometimes an IAM role will exist but not be ready
  provisioner "local-exec" {
    command = "sleep 30"
  }

  assume_role_policy = <<EOF
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

resource aws_iam_role_policy "WriteLogs" {
  name  = "WriteLogs"
  role  = "${aws_iam_role.LambdaExecution.id}"

  policy = <<EOF
{
  "Statement": {
    "Action":[
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ],
    "Resource":"arn:aws:logs:*:*:log-group:/aws/lambda/${var.lambci_instance}-*",
    "Effect":"Allow"
  }
}
EOF
}

resource aws_iam_role_policy "ReadWriteBucket" {
  name  = "ReadWriteBucket"
  role  = "${aws_iam_role.LambdaExecution.id}"

  policy = <<EOF
{
  "Statement": {
    "Action":[
      "s3:GetObject",
      "s3:PutObject",
      "s3:PutObjectAcl"
    ],
    "Resource":"arn:aws:s3:::${aws_s3_bucket.BuildResults.id}/*",
    "Effect":"Allow"
  }
}
EOF
}

resource aws_iam_role_policy "ReadTables" {
  name  = "ReadTables"
  role  = "${aws_iam_role.LambdaExecution.id}"

  policy = <<EOF
{
  "Statement": {
    "Action": [
      "dynamodb:BatchGetItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan"
    ],
    "Resource":"arn:aws:dynamodb:*:*:table/${var.lambci_instance}-*",
    "Effect":"Allow"
  }
}

EOF
}

