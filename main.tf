provider "aws" {

    region = "ap-southeast-1"
    access_key= ""
    secret_key= ""
}

variable vpc_cidr_block{}
variable publicSubnet_cidr_block-1{}
variable publicSubnet_cidr_block-2{}
variable privateSubnet_cidr_block-1{}
variable privateSubnet_cidr_block-2{}
variable availability_zone-1{}
variable availability_zone-2{}
variable env_prefix{}
variable public_key_location{}
variable my_ip{}

resource "aws_vpc" "tkg_vpc" {
  cidr_block =  var.vpc_cidr_block
  tags= {
    Name: "${var.env_prefix}-vpc"
  }

}

# Creating Public Subnet1
resource "aws_subnet" "tkg_subnet1-public" {
  vpc_id     = aws_vpc.tkg_vpc.id
  cidr_block = var.publicSubnet_cidr_block-1
  availability_zone= var.availability_zone-1
  map_public_ip_on_launch = true 
    tags= {
    Name: "${var.env_prefix}-publicSUbnet-1"
  }
}

# Creating Public Subnet2 
resource "aws_subnet" "tkg_subnet2-public" {  
vpc_id                  = aws_vpc.tkg_vpc.id  
cidr_block              = var.publicSubnet_cidr_block-2 
availability_zone       = var.availability_zone-2
map_public_ip_on_launch = true  
tags = {    
        Name: "${var.env_prefix}-publicSUbnet-2"
       }
}

# Creating Private Subnet1
resource "aws_subnet" "tkg_subnet1-private" {
  vpc_id     = aws_vpc.tkg_vpc.id
  cidr_block = var.privateSubnet_cidr_block-1 
  availability_zone= var.availability_zone-1
    tags= {
    Name: "${var.env_prefix}-privateSUbnet-1"
  }
}

# Creating Private Subnet2
resource "aws_subnet" "tkg_subnet2-private" {
  vpc_id     = aws_vpc.tkg_vpc.id
  cidr_block = var.privateSubnet_cidr_block-2
  availability_zone= var.availability_zone-2
    tags= {
    Name: "${var.env_prefix}-privateSUbnet-2"
  }
}

# Creating Public Route Table
resource "aws_route_table" "tkg_route_table-public" {
  vpc_id = aws_vpc.tkg_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.tkg_igw.id
  }

  tags = {
    Name = "${var.env_prefix}-rt-public"
  }
}


# Create route table association of public subnet1
resource "aws_route_table_association" "rtb-subnet-1-pub" {
  subnet_id      = aws_subnet.tkg_subnet1-public.id
  route_table_id = aws_route_table.tkg_route_table-public.id
}
# Create route table association of public subnet2
resource "aws_route_table_association" "rtb-subnet-2-pub" {
  subnet_id      = aws_subnet.tkg_subnet2-public.id
  route_table_id = aws_route_table.tkg_route_table-public.id
}




# Creating Internet Gateway
resource "aws_internet_gateway" "tkg_igw" {
  vpc_id = aws_vpc.tkg_vpc.id

  tags = {
    Name = "${var.env_prefix}-igw"
  }
}

# Create EIP for NAT GW1  
resource "aws_eip" "eip_natgw1" {  
     count = "1"
} 
# Create NAT gateway1
resource "aws_nat_gateway" "natgateway_1" {  
     count         = "1"  
     allocation_id = aws_eip.eip_natgw1[0].id  
     subnet_id     = aws_subnet.tkg_subnet1-public.id
} 


# Create EIP for NAT GW2 
resource "aws_eip" "eip_natgw2"{
     count = "1"
} 
# Create NAT gateway2 
resource "aws_nat_gateway" "natgateway_2"{ 
               
     count    = "1"  
     allocation_id = aws_eip.eip_natgw2[0].id 
     subnet_id     = aws_subnet.tkg_subnet2-public.id
}


# Creating Private Route Table subnet-1
resource "aws_route_table" "tkg_route_table-1-private" {
  vpc_id = aws_vpc.tkg_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgateway_1[0].id
  }

  tags = {
    Name = "${var.env_prefix}-rt-private-1"
  }
}


# Creating Private Route Table subnet-2
resource "aws_route_table" "tkg_route_table-2-private" {
  vpc_id = aws_vpc.tkg_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgateway_2[0].id
  }

  tags = {
    Name = "${var.env_prefix}-rt-private-2"
  }
}


# Create route table association of private subnet1
resource "aws_route_table_association" "rtb-subnet-1-prv" {
  subnet_id      = aws_subnet.tkg_subnet1-private.id
  route_table_id = aws_route_table.tkg_route_table-1-private.id
}
# Create route table association of private subnet2
resource "aws_route_table_association" "rtb-subnet-2-prv" {
  subnet_id      = aws_subnet.tkg_subnet2-private.id
  route_table_id = aws_route_table.tkg_route_table-2-private.id
}




# Create security group for loadbalancer
resource "aws_security_group" "tkg_alb_SG" {
  name        = "tkg_alb_SG"
  vpc_id      =  aws_vpc.tkg_vpc.id

ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
  }
egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.env_prefix}-alb-sg"
  }

}


# Create security group for Private-EC2
resource "aws_security_group" "tkg_SG" {
  name        = "tkg_SG"
  vpc_id      =  aws_vpc.tkg_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    description = "HTTP"
    cidr_blocks = ["0.0.0.0/0"]
   }

  ingress {
    description      = "ssh"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["10.0.10.0/24","10.0.11.0/24"]
  }

    egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.env_prefix}-sg"
  }

}


#Selection of AMI
data "aws_ami" "latest-amazon-linux-image" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

#Creating key-pair
resource "aws_key_pair" "private-EC2-keypair" {
  key_name   = "private-server-key"
  public_key = file(var.public_key_location)
}

#Creating Ec2 Instance for private subnet1
resource "aws_instance" "sub-1-private-EC2" {
  ami           = data.aws_ami.latest-amazon-linux-image.id
  instance_type = "t2.micro"
  subnet_id      = aws_subnet.tkg_subnet1-private.id
  vpc_security_group_ids = [aws_security_group.tkg_SG.id]
  availability_zone= var.availability_zone-1
  key_name= aws_key_pair.private-EC2-keypair.key_name
  user_data = <<EOF
                # !/bin/bash 
                sudo yum update -y
                sudo yum install -y httpd
                sudo systemctl start httpd
                sudo systemctl enable httpd
                chmod 777 /var/www/html -R
                sudo echo "<h1>Hello World from public EC2</h1>" > /var/www/html/index.html
              EOF
  
  tags = {
  Name = "${var.env_prefix}-ec2-server-1"
  }
}


#Creating Ec2 Instance for private subnet2
resource "aws_instance" "sub-2-private-EC2" {
  ami           = data.aws_ami.latest-amazon-linux-image.id
  instance_type = "t2.micro"
  subnet_id      = aws_subnet.tkg_subnet2-private.id
  vpc_security_group_ids = [aws_security_group.tkg_SG.id]
  availability_zone= var.availability_zone-2
  key_name= aws_key_pair.private-EC2-keypair.key_name
  user_data = <<EOF
                # !/bin/bash 
                sudo yum update -y
                sudo yum install -y httpd
                sudo systemctl start httpd
                sudo systemctl enable httpd
                chmod 777 /var/www/html -R
                sudo echo "<h1>Hello World from public EC2</h1>" > /var/www/html/index.html
              EOF
  
  tags = {
  Name = "${var.env_prefix}-ec2-server-2"
  }
}




#creating application load balancer target group-Instance
resource "aws_lb_target_group" "tkg_alb_target_group" {
  name     = "tkg-alb-tg-pub"
  port     = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.tkg_vpc.id
}

#creating application load balancer target group association
resource "aws_lb_target_group_attachment" "tkg-private-1-EC2" {
  target_group_arn = aws_lb_target_group.tkg_alb_target_group.arn
  target_id        = aws_instance.sub-1-private-EC2.id
  port             = 80
}
 
resource "aws_lb_target_group_attachment" "tkg-private-2-EC2" {
  target_group_arn = aws_lb_target_group.tkg_alb_target_group.arn
  target_id        = aws_instance.sub-2-private-EC2.id
  port             = 80
}

#creation of application load balancer
resource "aws_lb" "tkg-alb" {
  name               = "pub-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.tkg_alb_SG.id]
  subnets            = [aws_subnet.tkg_subnet1-public.id,aws_subnet.tkg_subnet2-public.id]

  enable_deletion_protection = true


  tags = {
    Environment = "dev-alb"
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.tkg-alb.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tkg_alb_target_group.arn
  }
}
