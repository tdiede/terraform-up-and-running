provider "aws" {
	region = "us-west-2"
}

resource "aws_instance" "example" {
	ami = "ami-db710fa3"
	instance_type = "t2.micro"

	user_data = <<-EOF
				#!/bin/bash
				echo "Hello, World" > index.html
				nohup busybox httpd -f -p 8080 &
				EOF

	tags {
		Name = "terraform-example"
	}
}
