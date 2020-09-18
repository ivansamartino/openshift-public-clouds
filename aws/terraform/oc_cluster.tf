##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "public_key_path" {}
variable "key_name" {}
variable "oc_username" {}
variable "oc_password" {}
variable "okd_install_repo" {
 type = string
 default = "https://github.com/okd-community-install/installcentos.git"
}
variable "clone_dir" {
  type = string
  default = "/tmp/installcentos"
}
variable "region" {
  default = "eu-central-1"
}
variable "network_address_space" {
  default = "10.1.0.0/16"
}
variable "subnet1_address_space" {
  default = "10.1.0.0/24"
}

##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region     = var.region
}

##################################################################################
# DATA
##################################################################################

data "aws_availability_zones" "available" {}

data "aws_ami" "aws-centos" {
  most_recent = true
  owners      = ["679593333241"]
  name_regex  = "CentOS Linux 7 x86_64 HVM EBS ENA 2002_01"
}

##################################################################################
# RESOURCES
##################################################################################

# NETWORKING #
resource "aws_vpc" "vpc" {
  cidr_block           = var.network_address_space
  enable_dns_hostnames = "true"

}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

}

resource "aws_subnet" "subnet1" {
  cidr_block              = var.subnet1_address_space
  vpc_id                  = aws_vpc.vpc.id
  map_public_ip_on_launch = "true"
  availability_zone       = data.aws_availability_zones.available.names[0]

}

# ROUTING #
resource "aws_route_table" "rtb" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta-subnet1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rtb.id
}

# SECURITY GROUPS #
# Nginx security group
resource "aws_security_group" "centos-sg" {
  name   = "centos_sg"
  vpc_id = aws_vpc.vpc.id

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Openshift Console
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# INSTANCES #

resource "aws_key_pair" "pkey" {
  key_name = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "singlenode" {
  ami                    = data.aws_ami.aws-centos.id
  # Bigger capacity go for: m5ad.4xlarge (16vCPU - 64GiB RAM - 2x300GB SSD)
  instance_type          = "t2.2xlarge"
  subnet_id              = aws_subnet.subnet1.id
  vpc_security_group_ids = [aws_security_group.centos-sg.id]
  key_name               = aws_key_pair.pkey.key_name

  root_block_device {
      volume_size           = "200"
      delete_on_termination = true
  }

  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "centos"
    private_key = file(var.private_key_path)

  }

  provisioner "remote-exec" {
    inline = [
      <<EOT
sudo yum update -y
sudo yum install -y git
git clone ${var.okd_install_repo} ${var.clone_dir}
export DOMAIN=${aws_route53_zone.primary.name}
export USERNAME=${var.oc_username}
export PASSWORD=${var.oc_password}
export INTERACTIVE=false
sudo -E bash echo \"DOMAIN IS: $DOMAIN\"
sudo -E bash ${var.clone_dir}/install-openshift.sh | tee /tmp/install.log
EOT
    ]
  }
}

# DNS RECORD #

resource "aws_route53_zone" "primary" {
  name    = "ivanmar-chkp.com"
}

resource "aws_route53_record" "console" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "console"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.singlenode.public_ip]
}

resource "aws_route53_record" "apps_console" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "apps.console"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.singlenode.public_ip]
}

resource "aws_route53_record" "wildcard_entry" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "*"
  type    = "A"
  alias {
      name                    = aws_route53_record.apps_console.fqdn
      zone_id                 = aws_route53_zone.primary.zone_id
      evaluate_target_health  = true
  }
}

##################################################################################
# OUTPUT
##################################################################################

output "aws_instance_public_dns" {
  value = aws_instance.singlenode.public_dns
}

