locals {
  tags = {

    project = "rancher"
    poc     = "john.prikkel@nga.mil"
  }

  domain_name = "rancher.local"
}

module "vpc" {
  source = "./rancher-vpc"

  tags        = local.tags
  domain_name = local.domain_name
}

module "bastion" {
  source = "./rancher-bastion"

  vpc_id    = module.vpc.id
  subnet_id = module.vpc.public_subnets[0].id

  key_name = aws_key_pair._.key_name
  tags     = local.tags
}

module "cluster" {
  source = "./rancher-cluster"

  vpc_id     = module.vpc.id
  subnet_ids = module.vpc.private_subnets.*.id

  key_name = aws_key_pair._.key_name
  tags     = local.tags

  instance_profile = aws_iam_instance_profile.master_profile.name
}

resource "aws_route53_zone" "_" {
  name = "rancher"

  vpc {
    vpc_id = module.vpc.id
  }

  tags = merge({
    Name = "rancher-zone"
    }, local.tags
  )
}

resource "aws_route53_record" "server" {
  zone_id = aws_route53_zone._.zone_id
  name    = "server"
  type    = "A"

  alias {
    name                   = module.cluster.server_lb.dns_name
    zone_id                = module.cluster.server_lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "agent" {
  zone_id = aws_route53_zone._.zone_id
  name    = "*.agent"
  type    = "A"

  alias {
    name                   = module.cluster.agent_lb.dns_name
    zone_id                = module.cluster.agent_lb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "registry" {
  zone_id = aws_route53_zone._.zone_id
  name    = "registry"
  type    = "A"
  ttl     = "5"

  records = [module.bastion.private_ip]
}

resource "aws_iam_role" "s3_read" {
  name = "rancher-s3-read"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "rancher-s3-read"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = ["s3:Get*", "s3:List*"]
          Effect   = "Allow"
          Resource = ["arn:aws:s3:::rancher-node-staging", "arn:aws:s3:::rancher-node-staging/*"]
        },
        {
          Action = ["s3:ListStorageLensConfigurations",
            "s3:ListAccessPointsForObjectLambda",
            "s3:GetAccessPoint",
            "s3:GetAccountPublicAccessBlock",
            "s3:ListAllMyBuckets",
            "s3:ListAccessPoints",
          "s3:ListJobs"]
          Effect   = "Allow"
          Resource = "*"
        }
      ]
    })
  }

  tags = merge({
    Name = "rancher-s3-read"
    }, local.tags
  )
}

resource "aws_iam_instance_profile" "master_profile" {
  name = "rancher-master-profile"
  role = aws_iam_role.s3_read.name
}

resource "tls_private_key" "_" {
  algorithm = "RSA"
}

resource "aws_key_pair" "_" {
  key_name   = "rancher"
  public_key = tls_private_key._.public_key_openssh
}


output "private_key" {
  value = tls_private_key._.private_key_pem
}

output "bastion_ip" {
  value = module.bastion.public_ip
}

output "server_ips" {
  value = module.cluster.server_ips
}

output "agent_ips" {
  value = module.cluster.agent_ips
}

output "server_lb_dns" {
  value = module.cluster.server_lb.dns_name
}

output "agent_lb_dns" {
  value = module.cluster.agent_lb.dns_name
}