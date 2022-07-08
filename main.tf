terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

#### CREATE VPC
resource "aws_vpc" "main" {
  cidr_block = "10.10.0.0/16"
  
  tags = {
    Name = "main"
  }  
}
#### CREATE SUBNET
resource "aws_subnet" "principal" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.10.10.0/24"
  availability_zone_id = "use1-az1"
  
  tags = {
     Name = "main" 
  }
}
resource "aws_subnet" "secundaria" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.10.20.0/24"
  availability_zone_id = "use1-az2"

  tags = {
    Name = "main"
  }
}

#### CREATE SECURITY GROUP
resource "aws_security_group" "vpc-sg" {
  name = "main"
  vpc_id = aws_vpc.main.id
  description = "VPC Default Security Group"

  tags = {
    Name = "main"
  }

  ingress {
    description = "Allow Port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "Allow Port 80"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
    egress{
    description = "Allow All"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "my-app-getaway"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.main.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_eip" "gw" {
  vpc        = true
  depends_on = [aws_internet_gateway.gw]
}
resource "aws_nat_gateway" "gw" {
  subnet_id     = aws_subnet.principal.id
  allocation_id = aws_eip.gw.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "my-route"
  }
  route {
    cidr_block     = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}  

resource "aws_route_table_association" "private" {
  #count          = var.az_count
  subnet_id      = aws_subnet.principal.id
  route_table_id = aws_route_table.private.id
}

#### CREATE CLUSTER ECS 
resource "aws_ecs_cluster" "main" {
  name = "myapp-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = {
    Name = "main"
  }
}

#resource "aws_cloudwatch_log_group" "myapp-log" {
 # name              = "myapp-log"
  #retention_in_days = 30
#}

####TASK DEFINITION 
resource "aws_ecs_task_definition" "main" {
    family                   = "myapp-task"
    requires_compatibilities = ["FARGATE"]
    network_mode             = "awsvpc"
    cpu                      = "1024"
    memory                   = "2048"
    execution_role_arn       =  "arn:aws:iam::450890513155:role/LabRole"
    container_definitions    = jsonencode([
        {
            name         =     "product-service"
            image        =     "450890513155.dkr.ecr.us-east-1.amazonaws.com/sale_app:products-service"
            #cpu          =     256
            memory       =     512
            essentials   =     true
            portMappings = [
                {
                    containerPort = 8080  
                    #hostPort      = 0
                }      
            ]
            logConfiguration = {
                    logDriver = "awslogs"
                    options =  {
                            awslogs-group = "myapp-log"
                            awslogs-region  = "us-east-1"
                            awslogs-stream-prefix = "ecs"
                    }
            }
          },

        {
            name         =     "payments-service"
            image        =     "450890513155.dkr.ecr.us-east-1.amazonaws.com/sale_app:payments-service"
            #cpu          =     256
            memory       =     512
            essentials   =     true
            portMappings = [
                {
                    containerPort = 9090
                    #hostPort      = 0
                }
            ]
            logConfiguration = {
                    logDriver = "awslogs"
                    options =  {
                            awslogs-group = "myapp-log"
                            awslogs-region  = "us-east-1"
                            awslogs-stream-prefix = "ecs"
                    }
            }
        } 
    ])
}

####SERVICE DEFINITION
resource "aws_ecs_service" "main" {
  name            = "myapp-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  #health_check_grace_period_seconds = 2
  #deployment_minimum_healthy_percent = 1
  #deployment_maximum_percent = 100
  desired_count   = 1
  launch_type     = "FARGATE"

 network_configuration {
    security_groups  = [aws_security_group.vpc-sg.id]
    subnets          = aws_subnet.principal.*.id
    assign_public_ip = true
  }    
  
}