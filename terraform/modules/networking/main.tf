locals {
  nat_availability_zones = var.enable_nat_gateway ? (
    var.single_nat_gateway ? [var.availability_zones[0]] : var.availability_zones
  ) : []
}

resource "aws_eip" "nat" {
  for_each = toset(local.nat_availability_zones)

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${each.key}"
  })

  depends_on = [var.internet_gateway_id]
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_availability_zones)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = var.public_subnet_ids[each.key]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-${each.key}"
  })

  depends_on = [var.internet_gateway_id]
}

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.internet_gateway_id
}

resource "aws_route_table_association" "public" {
  for_each = var.public_subnet_ids

  subnet_id      = each.value
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  for_each = toset(var.availability_zones)

  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-rt-${each.key}"
  })
}

resource "aws_route" "private_nat" {
  for_each = var.enable_nat_gateway ? toset(var.availability_zones) : toset([])

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.this[var.availability_zones[0]].id : aws_nat_gateway.this[each.key].id
}

resource "aws_route_table_association" "private" {
  for_each = var.private_subnet_ids

  subnet_id      = each.value
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route_table" "database" {
  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-database-rt"
  })
}

resource "aws_route_table_association" "database" {
  for_each = var.database_subnet_ids

  subnet_id      = each.value
  route_table_id = aws_route_table.database.id
}

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_gateway_endpoint ? 1 : 0

  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.region}.s3"

  route_table_ids = concat(
    [aws_route_table.public.id],
    [for route_table in aws_route_table.private : route_table.id]
  )

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-s3-endpoint"
  })
}

data "aws_region" "current" {}
