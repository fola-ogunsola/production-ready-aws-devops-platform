data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

resource "aws_sns_topic" "alarms" {
  count = var.enabled && var.create_sns_topic && var.existing_sns_topic_arn == null ? 1 : 0

  name              = "${var.name_prefix}-alarms"
  kms_master_key_id = "alias/aws/sns"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alarms"
  })
}

resource "aws_sns_topic_policy" "alarms" {
  count = length(aws_sns_topic.alarms) > 0 ? 1 : 0

  arn = aws_sns_topic.alarms[0].arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudWatchAlarmPublish"
      Effect    = "Allow"
      Principal = { Service = "cloudwatch.amazonaws.com" }
      Action    = "sns:Publish"
      Resource  = aws_sns_topic.alarms[0].arn
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
        ArnLike = {
          "aws:SourceArn" = "arn:${data.aws_partition.current.partition}:cloudwatch:${var.aws_region}:${data.aws_caller_identity.current.account_id}:alarm:${var.name_prefix}-*"
        }
      }
    }]
  })
}
