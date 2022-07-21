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

#### CREATE SECURITY GROUP TASK DEFINITION
resource "aws_security_group" "vpc-sg" {
  name = "main"
  vpc_id = aws_vpc.main.id
  description = "VPC Default Security Group"

  tags = {
    Name = "main"
  }

  #ingress {
  #  description = "Allow Port 80"
  #  from_port   = 80
  #  to_port     = 80
  #  protocol    = "tcp"
  #  cidr_blocks = ["0.0.0.0/0"]
  #}

ingress {
    description = "Allow Port 80"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    #cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.alb.id]
  }
    egress{
    description = "Allow All"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#### CREATE SECURITY GROUP ALB DEFINITION
resource "aws_security_group" "alb" {
  name = "alb-main"
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

resource "aws_route_table_association" "public" {
  #count          = var.az_count
  subnet_id      = aws_subnet.secundaria.id
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
        #1st container
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
		  #2nd container

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
        },
		#3rd container
		{
            name         =     "shipping-service"
            image        =     "450890513155.dkr.ecr.us-east-1.amazonaws.com/sale_app:shipping-service"
            #cpu          =     256
            memory       =     512
            essentials   =     true
            portMappings = [
                {
                    containerPort = 8082
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
		#4rd container
		{
            name         =     "orders-service"
            image        =     "450890513155.dkr.ecr.us-east-1.amazonaws.com/sale_app:orders-service"
            #cpu          =     256
            memory       =     512
            essentials   =     true
            portMappings = [
                {
                    containerPort = 8083
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
  desired_count   = 2
  launch_type     = "FARGATE"

 network_configuration {
    security_groups  = [aws_security_group.vpc-sg.id]
    subnets          = aws_subnet.principal.*.id
    assign_public_ip = true
  }    

   load_balancer {
    target_group_arn = aws_alb_target_group.app.id
    container_name   = "product-service"
    container_port   = 8080
  }

  
}

# alb.tf

resource "aws_alb" "main" {
  name            = "myapp-load-balancer"
  #subnets         = aws_subnet.principal.*.id

  subnets = [
    aws_subnet.principal.id,
    aws_subnet.secundaria.id,
  ]
  security_groups = [aws_security_group.alb.id]
}

resource "aws_alb_target_group" "app" {
  name        = "myapp-target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
  #  healthy_threshold   = "3"
    interval            = "300"
  #  protocol            = "HTTP"
  #  matcher             = "200"
   timeout             = "60"
  #  #path                = var.health_check_path
    unhealthy_threshold = "10"
  }
}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.main.id
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.app.id
    type             = "forward"
  }
}