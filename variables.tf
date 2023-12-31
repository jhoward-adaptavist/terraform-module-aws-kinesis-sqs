variable "product" {
  type = string
}

variable "region" {
  type = string
}

variable "stage" {
  type = string
}

variable "record_type" {
  type = string
}

variable "data_primary_key" {
  type = string
  default = null
}

variable "tags" {
  type = map(string)
}

variable "stage_type" {
  type = string
}

variable "stream_name" {
  type = string
}
variable "process_record_lambda_arn" {
  type = string
}
variable "process_record_lambda_name" {
  type = string
}

variable "sqs_event_filtering_path" {
  type = string
  default = null
}

variable "cluster_id" {
  type        = string
  description = "The ID / name of the Redis cluster"
  default = null
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

variable "availability_zones" {
  type    = list(string)
  default = []
}


variable "redis_hash_key" {
  type = string
  description = "The key used to extract a value from the data and create a distinct record on"
  default     = null
}

variable "redis_security_group_id" {
  type = string
  description = "The security group id assocaited with the redis cluster"
  default = null
  
}

variable "lambda_function_name_override" {
  type = string
  default = ""
}
variable "sqs_queue_name_override" {
  type = string
  default = ""
}
variable "enable_cloudwatch_logs" {
  type = bool
  default = true
}