variable "server_port"{
  type = number
  default = 80
  
}
variable "security_group_name"{
  description ="name of terraform SG"
  type = string
}

variable "asg_name"{
  description ="name of ASG"
  type = string
}

variable "lt_name" {
  description = "name of l_template"
  type = string
}
