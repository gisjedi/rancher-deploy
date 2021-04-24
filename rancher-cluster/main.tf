locals {
  cluster_instance = "t3a.xlarge"
  server_count     = 1
  agent_count      = 3
  storage          = 256
}

data "aws_ami" "amzn_linux_2" {
  most_recent = true
  owners      = ["amazon"]


  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}


resource "aws_network_interface" "server" {
  count     = local.server_count
  subnet_id = var.subnet_ids[count.index % length(var.subnet_ids)]

  tags = merge({
    Name = "rancher-server-nic-${count.index}"
    }, var.tags
  )
}

resource "aws_network_interface" "agent" {
  count     = local.agent_count
  subnet_id = var.subnet_ids[count.index % length(var.subnet_ids)]

  tags = merge({
    Name = "rancher-agent-nic-${count.index}"
    }, var.tags
  )
}

resource "aws_network_interface_sg_attachment" "server" {
  count                = length(aws_network_interface.server)
  security_group_id    = aws_security_group._.id
  network_interface_id = aws_network_interface.server[count.index].id
}

resource "aws_network_interface_sg_attachment" "agent" {
  count                = length(aws_network_interface.agent)
  security_group_id    = aws_security_group._.id
  network_interface_id = aws_network_interface.agent[count.index].id
}

resource "aws_security_group" "_" {
  name        = "internal"
  description = "Allow all inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.0.0/16"]
  }

  tags = merge({
    Name = "rancher-internal"
    }, var.tags
  )
}

resource "aws_instance" "server" {
  count         = length(aws_network_interface.server)
  ami           = data.aws_ami.amzn_linux_2.id
  instance_type = local.cluster_instance

  key_name = var.key_name

  network_interface {
    network_interface_id = aws_network_interface.server[count.index].id
    device_index         = 0
  }

  iam_instance_profile = var.instance_profile

  root_block_device {
    volume_size = var.volume_size
    tags = merge({
      Name = "rancher-server-${count.index}"
      }, var.tags
    )
  }

  tags = merge({
    Name = "rancher-server-${count.index}"
    }, var.tags
  )
}


resource "aws_instance" "agent" {
  count         = length(aws_network_interface.agent)
  ami           = data.aws_ami.amzn_linux_2.id
  instance_type = local.cluster_instance

  key_name = var.key_name

  network_interface {
    network_interface_id = aws_network_interface.agent[count.index].id
    device_index         = 0
  }

  iam_instance_profile = var.instance_profile

  root_block_device {
    volume_size = var.volume_size
    tags = merge({
      Name = "rancher-agent-${count.index}"
      }, var.tags
    )
  }

  tags = merge({
    Name = "rancher-agent-${count.index}"
    }, var.tags
  )
}


resource "aws_lb" "server" {
  name               = "rancher-server"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  tags = merge({
    Name = "rancher-server"
    }, var.tags
  )
}

resource "aws_lb_listener" "server" {
  load_balancer_arn = aws_lb.server.arn
  port              = "9345"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.server.arn
  }
}

resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.server.arn
  port              = "6443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

resource "aws_lb_target_group" "server" {
  name     = "rancher-server"
  port     = 9345
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group" "api" {
  name     = "rancher-api"
  port     = 6443
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "server" {
  count            = length(aws_network_interface.server)
  target_group_arn = aws_lb_target_group.http.arn
  target_id        = aws_instance.server[count.index].id
  port             = 9345
}

resource "aws_lb_target_group_attachment" "api" {
  count            = length(aws_network_interface.server)
  target_group_arn = aws_lb_target_group.https.arn
  target_id        = aws_instance.server[count.index].id
  port             = 6443
}

resource "aws_lb" "ingress" {
  name               = "rancher-ingress"
  internal           = true
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  tags = merge({
    Name = "rancher-ingress"
    }, var.tags
  )
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ingress.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.http.arn
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.ingress.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.https.arn
  }
}

resource "aws_lb_target_group" "http" {
  name     = "rancher-http"
  port     = 80
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group" "https" {
  name     = "rancher-https"
  port     = 443
  protocol = "TCP"
  vpc_id   = var.vpc_id
}

resource "aws_lb_target_group_attachment" "http" {
  count            = length(aws_network_interface.agent)
  target_group_arn = aws_lb_target_group.http.arn
  target_id        = aws_instance.agent[count.index].id
  port             = 80
}

resource "aws_lb_target_group_attachment" "https" {
  count            = length(aws_network_interface.agent)
  target_group_arn = aws_lb_target_group.https.arn
  target_id        = aws_instance.agent[count.index].id
  port             = 443
}