provider aws {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

resource aws_dynamodb_table "ConfigTable" {
  name            = "${var.lambci_instance}-config"
  read_capacity   = "1"
  write_capacity  = "1"
  hash_key        = "project"

  attribute {
    name  = "project"
    type  = "S"
  }

}

resource aws_dynamodb_table "BuildsTable" {
  name            = "${var.lambci_instance}-builds"
  read_capacity   = "1"
  write_capacity  = "1"
  hash_key        = "project"
  range_key       = "buildNum"

  attribute {
    name  = "commit"
    type  = "S"
  }

  attribute {
    name  = "trigger"
    type  = "S"
  }

  attribute {
    name  = "buildNum"
    type  = "N"
  }

  attribute {
    name  = "project"
    type  = "S"
  }

  attribute {
    name  = "requestId"
    type  = "S"
  }

  local_secondary_index {
    name            = "commit"
    projection_type = "KEYS_ONLY"
    range_key       = "commit"
  }

  local_secondary_index {
    name            = "trigger"
    projection_type = "KEYS_ONLY"
    range_key       = "trigger"
  }

  local_secondary_index {
    name            = "requestId"
    projection_type = "KEYS_ONLY"
    range_key       = "requestId"
  }
}

resource aws_lambda_function "BuildLambda" {
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
  #provisioner "local-exec" {
  #  command = "sleep 30"
  #}

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
    "Resource":"${aws_s3_bucket.BuildResults.arn}/*",
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

resource aws_iam_role_policy "WriteTables" {
  name    = "WriteTables"
  role    = "${aws_iam_role.LambdaExecution.id}"

  policy  = <<EOF
{
  "Statement": {
    "Effect": "Allow",
    "Action": [
      "dynamodb:BatchWriteItem",
      "dynamodb:DeleteItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem"
    ],
    "Resource": [
      "${aws_dynamodb_table.ConfigTable.arn}",
      "${aws_dynamodb_table.BuildsTable.arn}"
    ]
  }
}
EOF
}

resource aws_iam_role_policy "UpdateSnsTopic" {
  name  = "UpdateSnsTopic"
  role  = "${aws_iam_role.LambdaExecution.id}"

  policy = <<EOF
{
  "Statement": {
    "Effect": "Allow",
    "Action": "sns:SetTopicAttributes",
    "Resource": "arn:aws:sns:*:*:${var.lambci_instance}-*"
  }
}
EOF
}

resource aws_sns_topic "InvokeTopic" {
  name = "${var.lambci_instance}-InvokeTopic"
}

resource aws_sns_topic_subscription "InvokeTopic" {
  topic_arn = "${aws_sns_topic.InvokeTopic.arn}"
  protocol  = "lambda"
  endpoint  = "${aws_lambda_function.BuildLambda.arn}"
}

resource aws_lambda_permission "LambdaInvoke" {
  statement_id  = "AllowExecutionFromSns"
  function_name = "${aws_lambda_function.BuildLambda.arn}"
  action        = "lambda:InvokeFunction"
  principal     = "sns.amazonaws.com"
  source_arn    = "${aws_sns_topic.InvokeTopic.arn}"
}

resource aws_iam_user "SnsSender" {
  name  = "${var.lambci_instance}-SnsSender"
}

resource aws_iam_user_policy "SnsSender" {
  name  = "PublishOnly"
  user  = "${aws_iam_user.SnsSender.id}"

  policy = <<EOF
{
  "Statement": {
    "Effect": "Allow",
    "Action": "sns:Publish",
    "Resource": "arn:aws:sns:*:*:${var.lambci_instance}-*"
  }
}
EOF
}

resource aws_iam_role "SnsFailures" {
  name  = "${var.lambci_instance}-SnsFailures"

  lifecycle {
    create_before_destroy = true
  }

  assume_role_policy = <<EOF
{
  "Statement": {
    "Effect": "Allow",
    "Principal": {
      "Service": "sns.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }
}
EOF
}

resource aws_iam_role_policy "SnsFailures" {
  name    = "WriteLogs"
  role    = "${aws_iam_role.SnsFailures.id}"
  policy  = <<EOF
{
  "Statement": {
    "Effect": "Allow",
    "Action": [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutMetricFilter",
      "logs:PutRetentionPolicy"
    ],
    "Resource": "arn:aws:logs:*:*:log-group:sns/*/*/${aws_sns_topic.InvokeTopic.id}/*"
  }
}
EOF
}

resource aws_iam_access_key "SnsAccessKey" {
  user  = "${aws_iam_user.SnsSender.name}"
}

resource aws_cloudformation_stack "ConfigUpdater" {
  name = "${var.lambci_instance}-ConfigUpdaterStack"

  parameters {
    ServiceToken    = "${aws_lambda_function.BuildLambda.arn}"
    GithubToken     = "${var.GithubToken}"
    Repositories    = "${var.Repositories}"
    SlackToken      = "${var.SlackToken}"
    SlackChannel    = "${var.SlackChannel}"
    S3Bucket        = "${aws_s3_bucket.BuildResults.id}"
    SnsTopic        = "${aws_sns_topic.InvokeTopic.arn}"
    SnsAccessKey    = "${aws_iam_access_key.SnsAccessKey.id}"
    SnsSecret       = "${aws_iam_access_key.SnsAccessKey.secret}"
    SnsFailuresRole = "${aws_iam_role.SnsFailures.arn}"
  }

  template_body = <<STACK
{
  "AWSTemplateFormatVersion": "2010-09-09",
  "Description": "LambCI function and supporting services (see github.com/lambci/lambci for documentation)",
  "Parameters": {
    "ServiceToken": {
      "Description": "Lambda function arn",
      "Type": "String"
    },
    "GithubToken": {
      "Description": "GitHub OAuth token",
      "Type": "String",
      "Default": "",
      "AllowedPattern": "^$|^[0-9a-f]{40}$",
      "ConstraintDescription": "Must be empty or a 40 char GitHub token"
    },
    "Repositories": {
      "Description": "(optional) GitHub repos to add hook to, eg: facebook/react,emberjs/ember.js",
      "Type": "CommaDelimitedList",
      "Default": ""
    },
    "SlackToken": {
      "Description": "(optional) Slack API token",
      "Type": "String",
      "Default": "",
      "AllowedPattern": "^$|^xox.-[0-9]+-.+",
      "ConstraintDescription": "Must be empty or a valid Slack token, eg: xoxb-1234"
    },
    "SlackChannel": {
      "Description": "(optional) Slack channel",
      "Type": "String",
      "Default": "#general",
      "AllowedPattern": "^$|^#.+",
      "ConstraintDescription": "Must be empty or a valid Slack channel, eg: #general"
    },
    "S3Bucket": {
      "Description": "S3 bucket for results",
      "Type": "String"
    },
    "SnsTopic": {
      "Type": "String"
    },
    "SnsAccessKey": {
      "Type": "String"
    },
    "SnsSecret": {
      "Type": "String"
    },
    "SnsFailuresRole": {
      "Type": "String"
    }
  },
  "Resources": {
    "ConfigUpdater": {
      "Type": "Custom::ConfigUpdater",
      "Properties": {
        "ServiceToken": {"Ref": "ServiceToken"},
        "GithubToken": {"Ref": "GithubToken"},
        "Repositories": {"Ref": "Repositories"},
        "SlackToken": {"Ref": "SlackToken"},
        "SlackChannel": {"Ref": "SlackChannel"},
        "S3Bucket": {"Ref": "S3Bucket"},
        "SnsTopic": {"Ref": "SnsTopic"},
        "SnsAccessKey": {"Ref": "SnsAccessKey"},
        "SnsSecret": {"Ref": "SnsSecret"},
        "SnsFailuresRole": {"Ref": "SnsFailuresRole"}
      }
    }
  }
}
STACK
}
