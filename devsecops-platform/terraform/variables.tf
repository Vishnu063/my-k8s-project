variable "aws_region" {
  description = "AWS region to deploy into. Pick one close to you to reduce latency."
  type        = string
  default     = "ap-south-1" # Mumbai — good default if you're in India
}

variable "instance_type" {
  description = "EC2 instance type. t2.micro / t3.micro are free-tier eligible (750 hrs/month for 12 months)."
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of an EXISTING EC2 key pair in your AWS account, used for SSH access. Create one in the AWS Console under EC2 > Key Pairs before running this."
  type        = string
}

variable "my_ip" {
  description = "Your public IP in CIDR form, e.g. 49.36.XX.XX/32. Run `curl ifconfig.me` to find it. Restricts SSH/kubectl access to only you — never leave this as 0.0.0.0/0."
  type        = string
}

variable "project_name" {
  description = "Prefix used to name and tag all resources, so they're easy to find and clean up."
  type        = string
  default     = "devsecops-platform"
}
