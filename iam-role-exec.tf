##
# (c) 2021-2025
#     Cloud Ops Works LLC - https://cloudops.works/
#     Find us on:
#       GitHub: https://github.com/cloudopsworks
#       WebSite: https://cloudops.works
#     Distributed Under Apache v2.0 License
#
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com",
        "scheduler.amazonaws.com",
      ]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.function_name_short}-exec-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.all_tags
}

resource "aws_iam_role_policy" "lambda_exec" {
  name = "${local.function_name_short}-exec-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowInvokeFunction"
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction",
          "lambda:InvokeAsync"
        ]
        Resource = [
          aws_lambda_function.this.arn,
          "${aws_lambda_function.this.arn}:*"
        ]
      }
    ]
  })
  role = aws_iam_role.lambda_exec.id
}

resource "aws_iam_role" "scheduler_sqs" {
  name               = "${local.function_name_short}-sched-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.all_tags
}

resource "aws_iam_role_policy" "scheduler_sqs" {
  role = aws_iam_role.scheduler_sqs.id
  name = "${local.function_name_short}-sched-sqs-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSQSToSendMessage"
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:SendMessageBatch",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl"
        ]
        Resource = aws_sqs_queue.this.arn
      }
    ]
  })
}