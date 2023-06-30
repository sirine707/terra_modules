resource "aws_vpc" "terraformvpc"{
  cidr_block = "172.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"
  enable_dns_support = "true"

  tags={
    Name="terraformvpc"
  }
}

resource "aws_internet_gateway" "terraformIGW" {
  vpc_id =  aws_vpc.terraformvpc.id
  tags = {
    Name= "terraformIGW"
  }
  
}
resource "aws_route_table" "terraformRT" {
  vpc_id =  aws_vpc.terraformvpc.id
  tags = {
    Name= "terraformRT"
  }
}
resource "aws_route" "terraformEoute" {
  route_table_id = aws_route_table.terraformRT.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.terraformIGW.id
}

resource "aws_main_route_table_association" "terraformMainRTAssociation" {
  vpc_id = aws_vpc.terraformvpc.id
  route_table_id = aws_route_table.terraformRT.id
}


resource "aws_subnet" "my_subnet1" {
  vpc_id            = aws_vpc.terraformvpc.id
  cidr_block        = "172.0.0.0/24"
  availability_zone = "eu-west-3b"
  map_public_ip_on_launch = true

  tags = {
    Name = "sub01"
  }
}
resource "aws_subnet" "my_subnet2" {
  vpc_id            = aws_vpc.terraformvpc.id
  cidr_block        = "172.0.1.0/24"
  availability_zone = "eu-west-3a"
  map_public_ip_on_launch = true

  tags = {
    Name = "sub02"
  }
}
resource "aws_subnet" "my_subnet3" {
  vpc_id            = aws_vpc.terraformvpc.id
  cidr_block        = "172.0.2.0/24"
  availability_zone = "eu-west-3c"
  map_public_ip_on_launch = true

  tags = {
    Name = "sub03"
  }
}

resource "aws_route_table_association" "terraAsoocSub1" {
  subnet_id = aws_subnet.my_subnet1.id
  route_table_id = aws_route_table.terraformRT.id
}
resource "aws_route_table_association" "terraAsoocSub2" {
  subnet_id = aws_subnet.my_subnet2.id
  route_table_id = aws_route_table.terraformRT.id
}
resource "aws_route_table_association" "terraAsoocSub3" {
  subnet_id = aws_subnet.my_subnet3.id
  route_table_id = aws_route_table.terraformRT.id
}

resource "aws_security_group" "terraSG" {
  name = "${var.security_group_name}"
  vpc_id  = aws_vpc.terraformvpc.id 
  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  
}


#---------------aws-launch-template

resource "aws_launch_template" "terraformLT" {
  name = "${var.lt_name}"
  default_version = 1
  description = "launch template used for provisioning with terraform"
  image_id        = data.aws_ami.std_ami.id
  instance_type   = "t2.micro"
  user_data= filebase64("${path.module}/httpd.sh")
  network_interfaces {
    subnet_id = aws_subnet.my_subnet1.id
    security_groups = [aws_security_group.terraSG.id]
  }
  

  
  # Required when using a launch configuration with an ASG.
  tag_specifications {
    resource_type= "instance"
    tags ={
      Name = "terraformInstance"
    }
  }
}

resource "aws_autoscaling_group" "terraformASG" {
  name = "${var.asg_name}"
  vpc_zone_identifier  =  [aws_subnet.my_subnet2.id, aws_subnet.my_subnet3.id, aws_subnet.my_subnet1.id]
  
  health_check_type = "ELB"
  desired_capacity = 2
  min_size = 2
  max_size = 10
  launch_template {
    id=aws_launch_template.terraformLT.id
    version = "$Latest"
  }

}

resource "aws_autoscaling_attachment" "asg_attachement" {
  autoscaling_group_name = aws_autoscaling_group.terraformASG.id
  lb_target_group_arn= aws_lb_target_group.terraformTG.arn
}


#---------------------LOAD BALaNCER
resource "aws_lb" "example" {
  name               = "terraform-asg-example"
  internal   = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.my_subnet1.id, aws_subnet.my_subnet2.id, aws_subnet.my_subnet3.id]
  security_groups = [ aws_security_group.terraSG.id ]
  
}
#----------------------LISTENER
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = 80
  protocol          = "HTTP"

  
  default_action {
    type = "forward"
    target_group_arn  = aws_lb_target_group.terraformTG.arn

    
  }
}


#------------------target group for ASG
resource "aws_lb_target_group" "terraformTG" {
  name     = "terraformTG"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.terraformvpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}
