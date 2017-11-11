provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "all" {}

data "terraform_remote_state" "db" {
    backend "s3" 
    
    config {
      bucket = "tf-playground-state"
      key = "stage/data-stores/mysql/terraform.tfstate"
      region = "us-east-1"
    }
}

terraform {
    backend "s3" {
        config {
              bucket = "tf-playground-state"
              key = "stage/services/webserver-cluster/terraform.tfstate"
              region = "us-east-1"
              encrypt = true
          }
    }
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

resource "aws_security_group" "elb" {
  name = "tf-playground-elb"

  ingress {
    from_port    = 80
    to_port      = 80
    protocol     = "tcp"
    cidr_blocks  = ["0.0.0.0/0"]
  }

  egress {
    from_port    = 0
    to_port      = 00
    protocol     = "-1"
    cidr_blocks  = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "example" {
  image_id               = "ami-40d28157"
  instance_type          = "t2.micro"
  security_groups = ["${aws_security_group.instance.id}"]
 
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
  launch_configuration = "${aws_launch_configuration.example.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  
  load_balancers = ["${aws_elb.example.name}"]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key       = "Name"
    value     = "tf-asg-example"
    propagate_at_launch = true
  }
}

resource "aws_elb" "example" {
  name               = "tf-asg-example"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  security_groups    = ["${aws_security_group.elb.id}"]

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "${var.server_port}"
    instance_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:${var.server_port}/"
  }
}





