provider "aws" {

}

data "aws_availability_zones" "available" {

}

module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  version              = "2.66.0"
  name                 = "lb-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  tags = {
    "lb" = "artur"
  }
}

resource "aws_security_group" "my-sg" {

  vpc_id = module.vpc.vpc_id
  name   = join("_", ["sg", module.vpc.vpc_id])

  dynamic "ingress" {
    for_each = var.rules

    content {
      from_port   = ingress.value["port"]
      to_port     = ingress.value["port"]
      protocol    = ingress.value["proto"]
      cidr_blocks = ingress.value["cidr_blocks"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "LB_SG_Rules"
  }

}

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "generated_key" {
  key_name   = "default_key"
  public_key = tls_private_key.example.public_key_openssh
}


# -----------Instances---------
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  # for_each = toset(["ec2-code-deploy1", "ec2-code-deploy2", "ec2-code-deploy3", "ec2-code-deploy4"])

  name = "instance-1"
  # name = "instance-${each.key}"


  associate_public_ip_address = true
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.my-sg.id]
  subnet_id                   = module.vpc.public_subnets[0]
  user_data                   = <<-EOF
              #!/bin/bash
              echo "Hello, World $ {each.key}" > index.html
              python3 -m http.server 80 &
              EOF

  tags = {
    "lb" = "artur"
  }
}

