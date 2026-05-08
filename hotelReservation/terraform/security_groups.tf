# ── ALB security group ────────────────────────────────────────────────────────

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb"
  description = "Allow inbound traffic to the Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Hotel Reservation frontend"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  ingress {
    description = "Jaeger UI"
    from_port   = 16686
    to_port     = 16686
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-alb-sg" })
}

# ── ECS tasks security group ──────────────────────────────────────────────────

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks"
  description = "Allow traffic between ECS tasks and from the ALB"
  vpc_id      = aws_vpc.main.id

  # ALB → frontend (5000) and jaeger (16686)
  ingress {
    description     = "From ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Inter-service communication (consul, gRPC ports, mongo, memcached, etc.)
  ingress {
    description = "Inter-service"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # UDP for consul DNS and Jaeger UDP reporters
  ingress {
    description = "Inter-service UDP"
    from_port   = 0
    to_port     = 65535
    protocol    = "udp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-ecs-tasks-sg" })
}
