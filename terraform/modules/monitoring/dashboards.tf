resource "aws_cloudwatch_dashboard" "operations" {
  count = var.enabled && length(local.dashboard_widgets) > 0 ? 1 : 0

  dashboard_name = "${var.name_prefix}-operations"
  dashboard_body = jsonencode({
    start          = "-PT6H"
    periodOverride = "inherit"
    widgets        = local.dashboard_widgets
  })
}
