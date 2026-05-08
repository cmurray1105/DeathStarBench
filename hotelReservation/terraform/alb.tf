resource "aws_lb" "main" {
  # ALB names must be ≤ 32 chars
  name               = substr("${var.project_name}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = local.common_tags
}

# ── Frontend target group (port 5000) ─────────────────────────────────────────

resource "aws_lb_target_group" "frontend" {
  name        = substr("${var.project_name}-fe", 0, 32)
  port        = 5000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-404"
  }

  tags = local.common_tags
}

# ── Jaeger UI target group (port 16686) ───────────────────────────────────────

resource "aws_lb_target_group" "jaeger" {
  name        = substr("${var.project_name}-jaeger", 0, 32)
  port        = 16686
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200-404"
  }

  tags = local.common_tags
}

# ── Listeners ─────────────────────────────────────────────────────────────────

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.main.arn
  port              = 5000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener" "jaeger" {
  load_balancer_arn = aws_lb.main.arn
  port              = 16686
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jaeger.arn
  }
}
