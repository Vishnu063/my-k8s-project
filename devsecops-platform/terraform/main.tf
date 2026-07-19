terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# NETWORKING — we deliberately reuse the account's DEFAULT VPC/subnet instead
# of creating a new one. A custom VPC would need a NAT Gateway for the K3s
# node to reach the internet (docker pulls, k3s install script), and NAT
# Gateway costs ~$32/month flat, free-tier or not. The default VPC already
# has an Internet Gateway wired up, so a public subnet gets internet access
# for $0.
# ---------------------------------------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ---------------------------------------------------------------------------
# SECURITY GROUP
# Only three inbound rules, all scoped to YOUR IP only — never 0.0.0.0/0.
#   22    SSH        - to manage the box and pull the kubeconfig
#   6443  Kubernetes API - so kubectl on your laptop can talk to K3s
#   30000-30100 NodePort range - app (30080) and Grafana (30030) are exposed here
# ---------------------------------------------------------------------------
resource "aws_security_group" "k3s_node" {
  name        = "${var.project_name}-sg"
  description = "Security group for the single-node K3s DevSecOps platform"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "Kubernetes API server from my IP only"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    description = "NodePort range (app + Grafana + ArgoCD UI) from my IP only"
    from_port   = 30000
    to_port     = 30100
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    description = "Allow all outbound (image pulls, package installs, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-sg" }
}

# ---------------------------------------------------------------------------
# IAM ROLE — attached to the EC2 instance so K3s/kubelet can pull images
# straight from ECR WITHOUT storing any AWS credentials on the box or in a
# Kubernetes secret. This is the "least privilege via instance profile"
# pattern that's a very common interview question.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Lets the instance push CPU/memory/disk metrics to CloudWatch — used for
# the "Monitored production systems using CloudWatch" resume line to be
# literally true, not aspirational.
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# ---------------------------------------------------------------------------
# ECR REPOSITORY — where CI pushes scanned, built images
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "IMMUTABLE" # prevents overwriting a tag someone already deployed
  force_delete         = true        # so `terraform destroy` doesn't get blocked by leftover images

  image_scanning_configuration {
    scan_on_push = true # ECR's own basic vulnerability scan, in addition to Trivy in CI
  }
}

# ---------------------------------------------------------------------------
# EC2 INSTANCE — the single node running K3s (control plane + worker)
# ---------------------------------------------------------------------------
resource "aws_instance" "k3s_node" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = data.aws_subnets.default.ids[0]
  vpc_security_group_ids = [aws_security_group.k3s_node.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_size = 20 # GB — comfortably inside the 30GB free-tier EBS allowance
    volume_type = "gp3"
  }

  user_data = file("${path.module}/user_data.sh")

  tags = { Name = "${var.project_name}-k3s-node" }
}
