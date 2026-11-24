resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = local.alarm_specs

  alarm_name          = each.value.alarm_name
  alarm_description   = each.value.alarm_description
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = var.evaluation_periods
  datapoints_to_alarm = var.datapoints_to_alarm
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  period              = var.alarm_period_seconds
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  unit                = each.value.unit
  dimensions          = each.value.dimensions
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.notification_topic_arn == null ? [] : [local.notification_topic_arn]

  tags = merge(var.tags, {
    Name = each.value.alarm_name
  })
}
