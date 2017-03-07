output S3Bucket {
  value = "${aws_s3_bucket.BuildResults.id}"
}

output SnsTopic {
  value = "${aws_sns_topic.InvokeTopic.arn}"
}

output SnsRegion {
  value = "${var.aws_region}"
}

output SnsAccessKey {
  value = "${aws_iam_access_key.SnsAccessKey.id}"
}

output SnsSecret {
  value = "${aws_iam_access_key.SnsAccessKey.secret}"
}

output LambdaExecuteRole {
  value = "${aws_iam_role.LambdaExecution.id}"
}

