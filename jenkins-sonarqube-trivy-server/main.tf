module "sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "netflix-sg"
  description = "Security group for netflix clone server"
  vpc_id      = var.vpc_id

  ingress_rules = {
    jenkins = {
      from_port   = 8080
      to_port     = 8080
      ip_protocol = "tcp"
      description = "Jenkins port"
      cidr_ipv4   = "0.0.0.0/0"
    }
    https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "HTTPS"
      cidr_ipv4   = "0.0.0.0/0"
    }
    http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      description = "HTTP"
      cidr_ipv4   = "0.0.0.0/0"
    }
    ssh = {
      from_port   = 22
      to_port     = 22
      ip_protocol = "tcp"
      description = "SSH"
      cidr_ipv4   = "0.0.0.0/0"
    }
    sonarqube = {
      from_port   = 9000
      to_port     = 9000
      ip_protocol = "tcp"
      description = "SonarQube port"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  egress_rules = {
    all = {
      ip_protocol = "-1"
      description = "All traffic"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }
}

module "ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"

  name = "netflix-server"

  instance_type               = var.instance_type
  ami                         = var.ami
  key_name                    = var.key_pair
  monitoring                  = true
  vpc_security_group_ids      = [module.sg.id]
  subnet_id                   = var.subnet_id
  user_data                   = file("userdata.sh")
  user_data_replace_on_change = true
  root_block_device = {
    size = 25
    type = "gp3"
  }

  tags = {
    Terraform   = "true"
    Environment = "dev"
    Name        = "netflix-server"
  }
}

resource "aws_eip" "eip" {
  instance = module.ec2_instance.id
  domain   = "vpc"
}