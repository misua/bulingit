variable "server_port" {
    description = "server port 8080"
    type = number
    default = 8080
 }



resource "aws_instance" "myEC2" {
    ami = "ami-0947d2ba12ee1ff75"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.MyEC2_SG.id]

    user_data = <<EOF
                #!/bin/bash
                echo "Hello, World" > index.html
                nohup busybox httpd -fp ${var.server_port} &
                EOF

    tags = {    
        Name = "Terraform EC2"
    }
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


output "public_ip" {
   value = "aws_instance.myEC2.public_ip"
   description = "fablek ip of ec2"
}

