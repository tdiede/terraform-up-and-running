provider "aws" {
	region = "us-west-2"
}

resource "aws_instance" "example" {
	ami = "amid28157"
	instance_type = "t2.micro"
}
