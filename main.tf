terraform {}

provider "aws" {
	region = "us-west-2"
}

data "aws_availability_zones" "all" {}

# launch_config: step 1 in creating auto-scaling group (ASG)
resource "aws_launch_configuration" "example" {
	image_id		= "ami-db710fa3"
	instance_type	= "t2.micro"
	security_groups	= ["${aws_security_group.instance.id}"]

	user_data = <<-EOF
				#!/bin/bash
				echo "Hello, World (from Therese)" > index.html
				nohup busybox httpd -f -p "${var.server_port}" &
				EOF

	lifecycle {
		create_before_destroy = true
	}
}

# ASG: referencing the launch_config
resource "aws_autoscaling_group" "example" {
	launch_configuration	= "${aws_launch_configuration.example.id}"
	availability_zones		= ["${data.aws_availability_zones.all.names}"]

	load_balancers		= ["${aws_elb.example.name}"]
	health_check_type	= "ELB"

	min_size = 2
	max_size = 4

	tag {
		key					= "Name"
		value				= "terraform-asg-example"
		propagate_at_launch	= true
	}
}

# instance SG: allows incoming requests on port 8080 from any IP
resource "aws_security_group" "instance" {
	name = "terraform-example-instance"

	ingress {
		from_port	= "${var.server_port}"
		to_port		= "${var.server_port}"
		protocol	= "tcp"
		cidr_blocks	= ["0.0.0.0/0"]
	}

	lifecycle {
		create_before_destroy = true
	}
}

# ELB: referencing the security_group
resource "aws_elb" "example" {
	name				= "terraform-asg-example"
	availability_zones	= ["${data.aws_availability_zones.all.names}"]
	security_groups		= ["${aws_security_group.elb.id}"]

	listener {
		lb_port				= 80
		lb_protocol			= "http"
		instance_port		= "${var.server_port}"
		instance_protocol	= "http"
	}

	health_check {
		healthy_threshold	= 2
		unhealthy_threshold	= 2
		timeout				= 3
		interval			= 30
		target				= "HTTP:${var.server_port}/"
	}
}

# elb SG: step 1 in creating elastic load balancer (ELB)
resource "aws_security_group" "elb" {
	name = "terraform-example-elb"

	ingress {
		from_port	= 80
		to_port		= 80
		protocol	= "tcp"
		cidr_blocks	= ["0.0.0.0/0"]
	}

	egress {
		from_port	= 0
		to_port		= 0
		protocol	= "-1"
		cidr_blocks	= ["0.0.0.0/0"]
	}
}