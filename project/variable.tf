variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  type    = string
  default = "10.0.2.0/24"
}

variable "ami_id" {
  type    = string
  default = "ami-0b1ed96948adabcd9"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "tags_name" {
  type    = string
  default = "learning-tf" # This is your master identifier label
}
