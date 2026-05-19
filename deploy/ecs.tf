# ECS EXEC ROLE -----
# Create an IAM role for ECS Exec to allow executing commands in ECS tasks via SSM.
# tasks such as running `aws ecs execute-command` require this role to be attached to the ECS task execution role.
resource "aws_iam_role" "ecs_exec_role" {
  name               = "ecs-exec-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_role_assume_role_policy.json
}

# attach the AmazonECSTaskExecutionRolePolicy to allow ECS tasks to execute commands via SSM.
resource "aws_iam_role_policy_attachment" "ecs_exec_role_ssm_core" {
  role       = aws_iam_role.ecs_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# failed to fetch secret 
# arn:aws:secretsmanager:us-east-1:802838070254:secret:rds!db-acf1... from secrets manager
resource "aws_iam_role_policy" "ecs_exec_role_read_rds_secret" {
  name = "${local.prefix}-ecs-exec-role-read-rds-secret"
  role = aws_iam_role.ecs_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = local.postgres_instance.master_user_secret[0].secret_arn
      }
    ]
  })
}

# ECS TASK ROLE -----
# task role -----
resource "aws_iam_role" "ecs_task_role" {
  name               = "ecs-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_role_assume_role_policy.json
}

resource "aws_iam_role_policy" "ecs_task_exec_command" {
  name = "${local.prefix}-ecs-exec-command"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

## s3 access
resource "aws_iam_policy" "ecs_task_s3_policy" {
  name = "${local.prefix}-ecs-task-s3-policy"

  policy = file("${path.module}/s3-policy.json")
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_attach" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_s3_policy.arn
}

# ECS CLUSTER -----
resource "aws_ecs_cluster" "main" {
  name = "${local.prefix}-cluster"

  tags = {
    Name = "${local.prefix}-cluster"
  }
}

# LOG GROUP -----
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${local.prefix}"
  retention_in_days = 7

  tags = {
    Name = "/ecs/${local.prefix}"
  }
}

# SECURITY GROUP -----
resource "aws_security_group" "ecs" {
  name        = "${local.prefix}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${local.prefix}-ecs-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_http_from_alb" {
  security_group_id            = aws_security_group.ecs.id
  from_port                    = var.api_container.port
  to_port                      = var.api_container.port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "ecs_all_out" {
  security_group_id = aws_security_group.ecs.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# TASK DEFINITION -----
resource "aws_ecs_task_definition" "api" {
  family                   = "${local.prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.ecs.cpu)
  memory                   = tostring(var.ecs.memory)
  execution_role_arn       = aws_iam_role.ecs_exec_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = var.api_container.name
      image = var.api_container.image
      portMappings = [
        {
          containerPort = var.api_container.port
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DB_HOST"
          value = local.postgres_instance.address
        },
        {
          name  = "DB_PORT"
          value = tostring(local.postgres_instance.port)
        },
        {
          name  = "DB_NAME"
          value = var.db.name
        },
        {
          name  = "ALLOWED_HOSTS"
          value = var.allowed_hosts
        },
        {
          name  = "CORS_ALLOWED_ORIGINS"
          value = "http://pixel-monitor-frontend.s3-website-us-east-1.amazonaws.com"
        },
        {
          name  = "AWS_STORAGE_BUCKET_NAME"
          value = var.AWS_STORAGE_BUCKET_NAME
        },
        {
          name  = "AWS_S3_REGION_NAME"
          value = var.aws_region
        }

      ]

      secrets = [
        {
          name      = "DB_USER"
          valueFrom = "${local.postgres_instance.master_user_secret[0].secret_arn}:username::"
        },
        {
          name      = "DB_PASS"
          valueFrom = "${local.postgres_instance.master_user_secret[0].secret_arn}:password::"
        },
        {
          name      = "DJANGO_SECRET_KEY"
          valueFrom = "${local.postgres_instance.master_user_secret[0].secret_arn}:password::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = var.api_container.name
        }
      }
    }
  ])
}

# ECS SERVICE -----
resource "aws_ecs_service" "api" {
  name            = "${local.prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.ecs.desired_count
  launch_type     = "FARGATE"

  enable_execute_command = true

  network_configuration {
    subnets          = [for s in aws_subnet.private : s.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.ecs.arn
    container_name   = var.api_container.name
    container_port   = var.api_container.port
  }

  tags = {
    Name = "${local.prefix}-service"
  }
}
