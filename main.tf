provider "aws" {
  region = "us-east-1"
}

variable "server_port" {
  description = "The port used for http requests"
  default = 8080
}

resource "aws_security_group" "instance" {
  name = "tf-playground-instance"

  ingress {
    from_port    = "${var.server_port}"
    to_port      = "${var.server_port}"
    protocol     = "tcp"
    cidr_blocks  = ["0.0.0.0/0"]
  }
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "example" {
  ami           = "ami-40d28157"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["${aws_security_group.instance.id}"]
 
  user_data = <<-EOF
              #!/bin/bash
              echo "Hello TF!" > index.html
              nohup busybox httpd -f -p "${var.server_port}" &
              EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  aws_launch_configuration = "${aws_launch_configuration.example.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  min_size = 2
  max_size = 10

  tag {
    key       = "Name"
    value     = "tf-asg-example"
    propagate_at_launch = true
  }
}

output "public_ip" {
  value = "${aws_instance.example.public_ip}"
}


