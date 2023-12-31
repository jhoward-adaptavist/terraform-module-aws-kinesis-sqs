variable "stage" {
  type = string
}

variable "namespace" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "description" {
  type = string
}

variable "code_dir" {
  type = string
}

variable "function_name" {
  type = string
}

variable "product" {
  type = string
}

variable "kms_key_arn_list" {
  type = list(string)
}

variable "sqs_read_arn_list" {
  type    = list(string)
  default = []
}

variable "region" {
  type = string
}

variable "kinesis_read_arn_list" {
  type    = list(string)
  default = []
}

variable "sqs_write_arn_list" {
  type    = list(string)
  default = []
}

variable "environment_variables" {
  type = map(string)
}

variable "slack_sns_arn" {
  type = string
}

variable "sqs_batch_size" {
  type    = number
  default = 10
}

variable "maximum_batching_window_in_seconds" {
  type    = number
  default = 0
}

variable "vpc_id" {
  type = string
  description = "Id of the VPC attached to the lambda"
  default     = null
}

variable "vpc_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs associated with the VPC"
  default     = null
}

variable "enable_cloudwatch_logs" {
  type = bool
  default = true
}



