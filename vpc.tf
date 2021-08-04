/*
This module deploys a VPC, with a pair of public and private subnets spread
across two Availability Zones. It deploys an internet gateway, with a default
route on the public subnets. It deploys a pair of NAT gateways (one in each
AZ), and default routes for them in the private subnets.
*/

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)
  cidr_block = var.public_subnet_cidrs[count.index]
  vpc_id = var.vpc_id
  map_public_ip_on_launch = true
  availability_zone = count.index % 2 == 0 ? "${var.region}a" : "${var.region}b"
  tags = merge({
    Name = "mwaa-${var.environment_name}-public-subnet-${count.index}"
  }, var.tags)
}

resource "aws_subnet" "private" {
  count = length( var.private_subnet_cidrs)
  cidr_block = var.private_subnet_cidrs[count.index]
  vpc_id = var.vpc_id
  map_public_ip_on_launch = false
  availability_zone = count.index % 2 == 0 ? "${var.region}a" : "${var.region}b"
  tags = merge({
    Name = "mwaa-${var.environment_name}-private-subnet-${count.index}"
  }, var.tags)
}

resource "aws_eip" "this" {
  count = length(var.public_subnet_cidrs)
  vpc = true
  tags = merge({
    Name = "mwaa-${var.environment_name}-eip-${count.index}"
  }, var.tags)
}

resource "aws_nat_gateway" "this" {
  count = length(var.public_subnet_cidrs)
  allocation_id = aws_eip.this[count.index].id
  subnet_id = aws_subnet.public[count.index].id
  tags = merge({
    Name = "mwaa-${var.environment_name}-nat-gateway-${count.index}"
  }, var.tags)
}

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = var.internet_gateway_id
  }
  tags = merge({
    Name = "mwaa-${var.environment_name}-public-routes"
  }, var.tags)
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)
  route_table_id = aws_route_table.public.id
  subnet_id = aws_subnet.public[count.index].id
}

resource "aws_route_table" "private" {
  count = length(aws_nat_gateway.this)
  vpc_id = var.vpc_id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[count.index].id
  }
  tags = merge({
    Name = "mwaa-${var.environment_name}-private-routes-a"
  }, var.tags)
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  route_table_id = aws_route_table.private[count.index].id
  subnet_id = aws_subnet.private[count.index].id
}

resource "aws_security_group" "this" {
  vpc_id = var.vpc_id
  name = "mwaa-${var.environment_name}-no-ingress-sg"
  tags = merge({
    Name = "mwaa-${var.environment_name}-no-ingress-sg"
  }, var.tags  )
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    self = true
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
}