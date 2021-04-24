locals {
  az_map = {
    0 = "us-east-2a"
    1 = "us-east-2b"
    2 = "us-east-2c"
    3 = "us-east-2d"
    4 = "us-east-2e"
    5 = "us-east-2f"
  }

  region = "us-east-2"
}

resource "aws_vpc" "_" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge({
    Name = "rancher-test"
    }, var.tags
  )
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc._.id
  service_name = "com.amazonaws.${local.region}.s3"

  tags = merge({
    Name = "rancher-s3-endpoint"
    }, var.tags
  )
}

resource "aws_vpc_endpoint" "ec2" {
  vpc_id            = aws_vpc._.id
  service_name      = "com.amazonaws.${local.region}.ec2"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.allow_vpc_endpoint.id,
  ]

  private_dns_enabled = true

  tags = merge({
    Name = "rancher-ec2-endpoint"
    }, var.tags
  )
}

resource "aws_security_group" "allow_vpc_endpoint" {
  name        = "allow_vpc_endpoint"
  description = "Allow endpoint inbound traffic from VPC"
  vpc_id      = aws_vpc._.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc._.cidr_block]
  }

  tags = merge({
    Name = "rancher-ec2-endpoint"
    }, var.tags
  )
}

resource "aws_subnet" "public" {
  count             = 3
  vpc_id            = aws_vpc._.id
  cidr_block        = "10.0.${0 + count.index}.0/24"
  availability_zone = local.az_map[count.index]

  tags = merge({
    Name = "rancher-public-${count.index}"
    }, var.tags
  )
}

resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc._.id
  cidr_block        = "10.0.${10 + count.index}.0/24"
  availability_zone = local.az_map[count.index]

  tags = merge({
    Name = "rancher-private-${count.index}"
    }, var.tags
  )
}

resource "aws_internet_gateway" "_" {
  vpc_id = aws_vpc._.id


  tags = merge({
    Name = "rancher-igw"
    }, var.tags
  )
}

# Private subnet will only be accessible from public subnet. There will be NO egress to the internet to simulate airgap deployment
resource "aws_route_table" "private" {
  vpc_id = aws_vpc._.id

  tags = merge({
    Name = "rancher-private-airgap-rt"
    }, var.tags
  )

}

# Public subnet exists only as a bastion with access to private subnets. This will allow us to connect and interact with cluster.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc._.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway._.id
  }

  tags = merge({
    Name = "rancher-public-rt"
    }, var.tags
  )
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_dhcp_options" "_" {
  domain_name         = var.domain_name
  domain_name_servers = ["AmazonProvidedDNS"]

  tags = {
    Name = "rancher-options"
  }
}

resource "aws_vpc_dhcp_options_association" "_" {
  vpc_id          = aws_vpc._.id
  dhcp_options_id = aws_vpc_dhcp_options._.id
}