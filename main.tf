provider "aws" {
	region = "us-west-2"
}

# EC2 instance running web server on Ubuntu w/ security group
resource "aws_instance" "example" {
	ami = "ami-db710fa3"
	instance_type = "t2.micro"
	vpc_security_group_ids = ["${aws_security_group.instance.id}"]

	user_data = <<-EOF
				#!/bin/bash
				echo "Hello, World (from Therese)" > index.html
				nohup busybox httpd -f -p 8080 &
				EOF

	tags {
		Name = "terraform-example"
	}
}

# publishes the public IP address in Terraform output
output "public_ip" {
	value = "${aws_instance.example.public_ip}"
}

# publishes the DNS name of the ELB
output "elb_dns_name" {
	value = "${aws_elb.example.dns_name}"
}

# sets an input variable
variable "server_port" {
	description = "The port the server will use for HTTP requests"
	default = 8080
}

# allows incoming requests on port 8080 from any IP
resource "aws_security_group" "instance" {
	name = "terraform-example-instance-sg"

	ingress {
		from_port = 8080
		to_port = 8080
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
}

# first step in creating an auto-scaling group (ASG)
resource "aws_launch_configuration" "example" {
	image_id = "ami-db710fa3"
	instance_type = "t2.micro"
	security_groups = ["${aws_security_group.instance.id}"]
}

# fetched information from AWS API
data "aws_availability_zones" "all" {}

# create the ASG itself referencing the launch config
resource "aws_autoscaling_group" "example" {
	launch_configuration = "${aws_launch_configuration.example.id}"
	availability_zones = ["${data.aws_availability_zones.all.names}"]

	load_balancers = ["${aws_elb.example.name}"]
	health_check_type = "ELB"

	min_size = 2
	max_size = 4

	tag {
		key = "Name"
		value = "terraform-asg-example"
		propagate_at_launch = true
	}
}

# first step in creating an elastic load balancer (ELB)
resource "aws_security_group" "elb" {
	name = "terraform-elb-example"

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

# create the ELB itself referencing the security group
resource "aws_elb" "example" {
	name = "terraform-asg-example"
	availability_zones = ["${data.aws_availability_zones.all.names}"]
	security_groups = ["${aws_security_group.elb.id}"]

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