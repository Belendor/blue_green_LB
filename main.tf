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

  for_each = toset(var.instances)

  name = "instance-${each.key}"

  associate_public_ip_address = true
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.generated_key.key_name
  vpc_security_group_ids      = [aws_security_group.my-sg.id]
  subnet_id                   = module.vpc.public_subnets[0]
  user_data                   = <<-EOF
              #!/bin/bash
              echo "Hello, World $(hostname -f)" > index.html
              python3 -m http.server 80 &
              EOF

  tags = {
    "lb" = "artur"
  }
}

# ----------Load Balancer---------
module "elb" {
  source  = "terraform-aws-modules/elb/aws"
  version = "3.0.1"
  health_check = {
    target              = "HTTP:80/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }
  listener = [
    {
      instance_port     = 80
      instance_protocol = "HTTP"
      lb_port           = 80
      lb_protocol       = "HTTP"
    }
  ]

  name = "elb"

  security_groups = [aws_security_group.my-sg.id]
  subnets = [module.vpc.public_subnets[0]]
  instances = [for instance in module.ec2_instance : instance.id]
  depends_on = [module.ec2_instance]
  number_of_instances = 2
}

# ----------Auto Scaling Group----------
resource "aws_launch_configuration" "lc" {
  image_id      = var.ami_id
  instance_type = "t2.micro"
  security_groups = ["${aws_security_group.my-sg.id}"]
  key_name = aws_key_pair.generated_key.key_name
  user_data                   = <<-EOF
            #!/bin/bash
            echo "Hello, World $(hostname -f)" > index.html
            python3 -m http.server 80 &
            EOF
  depends_on = [module.ec2_instance]
  lifecycle {
      create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "asg" {
  vpc_zone_identifier = ["${module.vpc.public_subnets[0]}"]
  desired_capacity   = 2
  max_size           = 2
  min_size           = 2
  load_balancers = [module.elb.elb_id] 
  launch_configuration = aws_launch_configuration.lc.id
  depends_on = [aws_launch_configuration.lc]
  lifecycle {
      create_before_destroy = true
  }  
}