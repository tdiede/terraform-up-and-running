provider "aws" {
	region = "us-west-2"
}

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

output "public_ip" {
	value = "${aws_instance.example.public_ip"
}

resource "aws_security_group" "instance" {
	name = "terraform-example-instance-sg"

	ingress {
		from_port = 8080
		to_port = 8080
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
}

resource "aws_launch_configuration" "example" {
	image_id = "ami-db710fa3"
	instance_type = "t2.micro"
	security_groups = ["${aws_security_group.instance.id}"]
}