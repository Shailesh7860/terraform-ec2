variable "aws_region" {
  description = "AWS region for the EC2 instance"
  type        = string
  default     = "ap-south-1" # Set to Mumbai to match your AMI
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID used to launch the EC2 instance"
  type        = string
  default     = "ami-0b1ed96948adabcd9"
}

variable "tags_name" {
    description = "tags as common"
    type = string
    default = "github-terraform"
}