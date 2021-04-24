locals {
  support_instance = "t3a.small"
  cluster_instance = "t3a.xlarge"
  registry_ip      = "10.0.0.10"
}

data "aws_ami" "amzn_linux_2" {
  most_recent = true
  owners      = ["amazon"]


  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}


resource "aws_network_interface" "bastion_registry" {
  subnet_id   = var.subnet_id
  private_ips = [local.registry_ip]
}

resource "aws_network_interface_sg_attachment" "bastion_registry" {
  security_group_id    = aws_security_group.allow_ssh.id
  network_interface_id = aws_network_interface.bastion_registry.id
}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.bastion_registry.id
  associate_with_private_ip = local.registry_ip
}


resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = var.vpc_id

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({
    Name = "ssh-incoming"
    }, var.tags
  )
}

resource "aws_instance" "bastion_registry" {
  ami           = data.aws_ami.amzn_linux_2.id
  instance_type = local.support_instance

  key_name = var.key_name

  network_interface {
    network_interface_id = aws_network_interface.bastion_registry.id
    device_index         = 0
  }

  root_block_device {
    volume_size = var.volume_size
    tags = merge({
      Name = "rancher-bastion"
      }, var.tags
    )
  }

  user_data = file("${path.module}/registry.sh")

  tags = merge({
    Name = "rancher-bastion"
    }, var.tags
  )

}