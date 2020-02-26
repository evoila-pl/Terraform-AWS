# Providers

provider "aws" {
  region = "eu-central-1"
  profile = "Lab"
}

provider "archive" {}

data "archive_file" "zip" {
  type = "zip"
  source_file = "hello_lambda.py"
  output_path = "hello_lambda.zip"
}

# Base IAM

data "aws_iam_policy_document" "policy" {
  statement {
    sid = ""
    effect = "Allow"

    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"
  assume_role_policy = "${data.aws_iam_policy_document.policy.json}"
}

# CloudWatch - Schedule

resource "aws_cloudwatch_event_rule" "schedule" {
  name = "shedule"
  schedule_expression = "cron(0 8,16 ? * MON-FRI *)"
}

resource "aws_cloudwatch_event_target" "check_schedule" {
  rule = "${aws_cloudwatch_event_rule.schedule.name}"
  target_id = "lambda"
  arn = "${aws_lambda_function.lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  statement_id = "AllowExecutionFromCloudWatch"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda.function_name}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.schedule.arn}"
}

# CloudWatch - Logs

resource "aws_cloudwatch_log_group" "example" {
  name = "/aws/lambda/${aws_lambda_function.lambda.function_name}"
  retention_in_days = 14
}

resource "aws_iam_policy" "lambda_logging" {
  name = "lambda_logging"
  path = "/"
  policy = <<-EOT
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:*:*:*",
        "Effect": "Allow"
      }
    ]
  }
  EOT
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role = "${aws_iam_role.iam_for_lambda.name}"
  policy_arn = "${aws_iam_policy.lambda_logging.arn}"
}

# Lambda

resource "aws_lambda_function" "lambda" {
  function_name = "hello_lambda"

  filename = "${data.archive_file.zip.output_path}"
  source_code_hash = "${data.archive_file.zip.output_base64sha256}"

  role = "${aws_iam_role.iam_for_lambda.arn}"
  handler = "hello_lambda.lambda_handler"
  runtime = "python3.6"

  environment {
    variables = {
      greeting = "Hello"
    }
  }
}
