# 1. CONFIGURE AWS PROVIDER
provider "aws" { region = "us-east-1" }

# 2. FETCH DEFAULT NETWORK INFRASTRUCTURE
data "aws_vpc" "default" { default = true }
data "aws_subnets" "default" { filter { name = "vpc-id"; values = [data.aws_vpc.default.id] } }

# 3. SECURITY GROUP FOR FLASK SERVICE (Port 5000)
resource "aws_security_group" "ecs_sg" {
  name   = "flask-app-ecs-sg"
  vpc_id = data.aws_vpc.default.id
  ingress { from_port = 5000; to_port = 5000; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }
}

# 4. IAM ROLE FOR ECS EXECUTION
resource "aws_iam_role" "ecs_execution_role" {
  name = "flask-app-ecs-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "://amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy_attachment" "ecs_execution_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 5. ECS FARGATE CLUSTER
resource "aws_ecs_cluster" "flask_cluster" { name = "flask-app-cluster" }

# 6. ECS TASK DEFINITION
resource "aws_ecs_task_definition" "flask_task" {
  family                   = "flask-app-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  container_definitions = jsonencode([{
    name      = "flask-app-container"
    image     = "docker.io/yourusername/sample-python-flask-app:latest"
    essential = true
    portMappings = [{ containerPort = 5000; hostPort = 5000 }]
  }])
}

# 7. ECS SERVICE
resource "aws_ecs_service" "flask_service" {
  name            = "flask-app-service"
  cluster         = aws_ecs_cluster.flask_cluster.id
  task_definition = aws_ecs_task_definition.flask_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }
  # CRITICAL: Prevents Terraform from overwriting updates from CodePipeline
  lifecycle { ignore_changes = [task_definition] }
}
