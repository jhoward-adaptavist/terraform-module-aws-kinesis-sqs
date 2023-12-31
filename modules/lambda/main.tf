module "sqs_message_processor" {
  source                 = "Adaptavist/aws-lambda/module"
  version                = "1.34.0"
  name                   = var.function_name
  namespace              = var.namespace
  stage                  = var.stage
  tags                   = var.tags
  lambda_code_dir        = var.code_dir
  handler                = "app.lambda_handler"
  runtime                = "python3.8"
  timeout                = 60
  memory_size            = 512
  description            = var.description
  function_name          = var.function_name
  enable_cloudwatch_logs = var.enable_cloudwatch_logs
  aws_region             = var.region
  disable_label_function_name_prefix = true
  enable_tracing = true
  tracing_mode = "Active"
  kms_key_arn  = aws_kms_key.kms_key.arn
  environment_variables = var.environment_variables
  vpc_security_group_ids = var.vpc_id != null ? [element(aws_security_group.lambda_security_group.*.id, 0)] : []
  vpc_subnet_ids = var.vpc_subnet_ids != null ? var.vpc_subnet_ids : []
  depends_on = [ null_resource.install_lambda_dependencies ]
}

resource "null_resource" "install_lambda_dependencies" {
    provisioner "local-exec" {
    command = "pip3 install -r ${var.code_dir}/requirements.txt -t ${var.code_dir}"

  }
    triggers = {
        always_run = "${timestamp()}"
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
resource "aws_kms_key" "kms_key" {
  description            = "Key used for the add record lambda ${var.function_name}"
  policy                 = data.aws_iam_policy_document.kms_policy.json
  tags                   = var.tags
  is_enabled             = true
  enable_key_rotation    = true
}
resource "aws_kms_alias" "kms_alias" {
  name          = "alias/add_${var.product}_record_to_sqs_kms_key"
  target_key_id = aws_kms_key.kms_key.key_id
}
data "aws_iam_policy_document" "kms_policy" {
  statement {
    sid     = "s3_access"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    resources = ["*"]
  }
  statement {
    sid     = "account_access"
    effect  = "Allow"
    actions = ["kms:*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    resources = ["*"]
  }
}


data "aws_iam_policy_document" "access_policy_document" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = length(var.sqs_write_arn_list) > 0 ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "sqs:SendMessage",
        "sqs:ChangeMessageVisibility"
      ]
      resources = var.sqs_write_arn_list
    }
  }

  dynamic "statement" {
    for_each = length(var.sqs_read_arn_list) > 0 ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "sqs:Get*",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage"
      ]
      resources = var.sqs_read_arn_list
    }
  }

  dynamic "statement" {
    for_each = length(var.kinesis_read_arn_list) > 0 ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "kinesis:Get*",
        "kinesis:List*",
        "kinesis:Describe*"
      ]
      resources = var.kinesis_read_arn_list
    }
  }


  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = var.kms_key_arn_list
  }

  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"] # need access to all KMS keys to decrypt data from all buckets in the account
  }
}

resource "aws_iam_policy" "access_policy" {
  name   = "add_record_to_sqs-process-data"
  policy = data.aws_iam_policy_document.access_policy_document.json
}

resource "aws_iam_role_policy_attachment" "access_policy_attach" {
  role       = module.sqs_message_processor.lambda_role_name
  policy_arn = aws_iam_policy.access_policy.arn
}


resource "aws_cloudwatch_metric_alarm" "error_alarm" {
  alarm_name          = module.sqs_message_processor.lambda_name
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  dimensions = {
    FunctionName = module.sqs_message_processor.lambda_name
  }
  period                    = "60"
  statistic                 = "Sum"
  alarm_actions             = [var.slack_sns_arn]
  threshold                 = "1"
  alarm_description         = "This metric monitors SQS message processors"
  insufficient_data_actions = []
  tags                      = var.tags
}


resource "aws_security_group" "lambda_security_group" {
  count       = var.vpc_id != null ? 1 : 0
  name_prefix = var.function_name
  description = "lambda_security"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "lambda_security_group_rule" {
  count              = var.vpc_id != null ? 1 : 0
  type               = "egress"
  from_port          = 0
  to_port            = 65535
  protocol           = "tcp"
  cidr_blocks        = ["0.0.0.0/0"]
  security_group_id  = aws_security_group.lambda_security_group[count.index].id
}