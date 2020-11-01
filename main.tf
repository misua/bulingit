
terraform {
    required_version = ">= 0.12"
}


variable "server_port" {
    description = "server port 80"
    type = number
    default = 80
 }



resource "aws_security_group" "MyEC2_SG" {
    name = "terraform sg for ec2"

    ingress {
        from_port = var.server_port
        to_port = var.server_port
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


resource "aws_launch_configuration" "ASGlaunchconfig" {
    image_id = "ami-0947d2ba12ee1ff75"
    instance_type = "t2.micro"
    security_groups = [aws_security_group.MyEC2_SG.id]


     user_data = <<EOF
                    #!/bin/bash
                    echo "Hello, World" > index.html
                EOF

    lifecycle {
    create_before_destroy = true
  }


# tags = {    
#      Name = "Terraform autoscaling group"
#  }
}


data "aws_vpc" "default"{
    default = true
}

data "aws_subnet_ids" "default"{
    vpc_id = data.aws_vpc.default.id
}


resource "aws_autoscaling_group" "ASGgroup" {
    launch_configuration = aws_launch_configuration.ASGlaunchconfig.name
    vpc_zone_identifier = data.aws_subnet_ids.default.ids

    target_group_arns = [aws_lb_target_group.asgTG.arn]
    health_check_type = "ELB"

    min_size = 2
    max_size = 4

    tag {
        key = "Name"
        value = "terra-asg-group"
        propagate_at_launch = true
    }
}



#--------ALB------

resource "aws_lb" "MyALB" {
    name = "terraform-ALB-example"
    load_balancer_type = "application"
    security_groups = [aws_security_group.albSG.id]
    subnets = data.aws_subnet_ids.default.ids

}




#---- asg security alb

resource "aws_security_group" "albSG" {
    name = "terraform sg alb"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


#-----lb target group----


resource "aws_lb_target_group" "asgTG" {
    name = "terraform-asgTG"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id

    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
  }
}

#--------ALB listener--------

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.MyALB.arn
    port = 80
    protocol = "HTTP"   


default_action {
    type = "fixed-response"

    fixed_response {
        content_type = "text/plain"
        message_body = "404: page not found"
        status_code = 404
    }
  }
}


#----------lb listenr rule


resource "aws_lb_listener_rule" "asgLSTN"{
    listener_arn = aws_lb_listener.http.arn
    priority = 100

    #condition {
     #   field = "path_pattern" 
     #   values = ["*"]
   # }

    condition {
        path_pattern {
            values = ["*"]
     }
    }
    
    action {
        type = "forward"
        target_group_arn = aws_lb_target_group.asgTG.arn
    }
    
  }


output "alb_dns_name" {
   value = "aws_lb.MyALB.dns_name"
   description = "dns name load balancer"
}