variable "instance_type" {
  description = "Instance type for EC2 instances"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "AMI for EC2 instances. Amazon Linux 2, Kernel 5.10"
  type        = string
  default     = "ami-0e2031728ef69a466"
}

variable "rules" {
  type = list(object({
    port        = number
    proto       = string
    cidr_blocks = list(string)
  }))

  default = [
    {
      port        = 80
      proto       = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 22
      proto       = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "instances" {
  description = "List of instance names"
  type        = list(string)
  default     = ["Blue", "Green"]
}