locals {
  # ── App microservices (same image, different entrypoints) ──────────────────
  app_services = {
    frontend = {
      entrypoint = "frontend"
      cpu        = 512
      memory     = 1024
    }
    profile = {
      entrypoint = "profile"
      cpu        = 256
      memory     = 512
    }
    search = {
      entrypoint = "search"
      cpu        = 256
      memory     = 512
    }
    geo = {
      entrypoint = "geo"
      cpu        = 256
      memory     = 512
    }
    rate = {
      entrypoint = "rate"
      cpu        = 256
      memory     = 512
    }
    recommendation = {
      entrypoint = "recommendation"
      cpu        = 256
      memory     = 512
    }
    user = {
      entrypoint = "user"
      cpu        = 256
      memory     = 512
    }
    reservation = {
      entrypoint = "reservation"
      cpu        = 256
      memory     = 512
    }
  }

  # ── MongoDB service names ──────────────────────────────────────────────────
  mongodb_services = toset([
    "geo", "profile", "rate", "recommendation",
    "reservation", "user", "review", "attractions"
  ])

  # ── Memcached service names ────────────────────────────────────────────────
  memcached_services = toset(["rate", "profile", "reserve", "review"])

  # Shared environment variables injected into every app container.
  app_env = [
    { name = "TLS", value = var.tls },
    { name = "GC", value = tostring(var.gc) },
    { name = "JAEGER_SAMPLE_RATIO", value = tostring(var.jaeger_sample_ratio) },
    { name = "MEMC_TIMEOUT", value = tostring(var.memc_timeout) },
    { name = "LOG_LEVEL", value = var.log_level },
  ]

  # Standard CloudWatch log driver config – parameterised per service.
  log_driver = {
    logDriver = "awslogs"
    options = {
      "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
      "awslogs-region"        = var.aws_region
      "awslogs-stream-prefix" = "ecs"
    }
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# CONSUL
# ═══════════════════════════════════════════════════════════════════════════════

resource "aws_ecs_task_definition" "consul" {
  family                   = "${var.project_name}-consul"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "consul"
    image     = "hashicorp/consul:latest"
    essential = true

    portMappings = [
      { containerPort = 8300, protocol = "tcp" },
      { containerPort = 8400, protocol = "tcp" },
      { containerPort = 8500, protocol = "tcp" },
      { containerPort = 8600, protocol = "udp" },
    ]

    logConfiguration = local.log_driver
  }])
}

resource "aws_ecs_service" "consul" {
  name            = "consul"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.consul.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.services["consul"].arn
  }

  tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# JAEGER
# ═══════════════════════════════════════════════════════════════════════════════

resource "aws_ecs_task_definition" "jaeger" {
  family                   = "${var.project_name}-jaeger"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "jaeger"
    image     = "jaegertracing/all-in-one:latest"
    essential = true

    portMappings = [
      { containerPort = 5775, protocol = "udp" },
      { containerPort = 6831, protocol = "udp" },
      { containerPort = 6832, protocol = "udp" },
      { containerPort = 5778, protocol = "tcp" },
      { containerPort = 14268, protocol = "tcp" },
      { containerPort = 16686, protocol = "tcp" },
    ]

    logConfiguration = local.log_driver
  }])
}

resource "aws_ecs_service" "jaeger" {
  name            = "jaeger"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.jaeger.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.jaeger.arn
    container_name   = "jaeger"
    container_port   = 16686
  }

  service_registries {
    registry_arn = aws_service_discovery_service.services["jaeger"].arn
  }

  tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# APP MICROSERVICES  (frontend, profile, search, geo, rate, recommendation,
#                    user, reservation) – same image, different entrypoints.
#
# config.json is stored base64-encoded in SSM and decoded at container startup:
#   echo $CONFIG_JSON_B64 | base64 -d > /config.json && exec <service>
# ═══════════════════════════════════════════════════════════════════════════════

resource "aws_ecs_task_definition" "app_service" {
  for_each = local.app_services

  family                   = "${var.project_name}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = each.key
    image     = "${aws_ecr_repository.hotel_reservation.repository_url}:latest"
    essential = true

    # Decode SSM-stored config.json, write it to /, then exec the binary.
    entryPoint = ["sh", "-c"]
    command    = ["echo $CONFIG_JSON_B64 | base64 -d > /config.json && exec ${each.value.entrypoint}"]

    portMappings = each.key == "frontend" ? [{ containerPort = 5000, protocol = "tcp" }] : []

    environment = local.app_env

    secrets = [{
      name      = "CONFIG_JSON_B64"
      valueFrom = aws_ssm_parameter.config_json.arn
    }]

    logConfiguration = local.log_driver
  }])
}

resource "aws_ecs_service" "app_service" {
  for_each = local.app_services

  name            = each.key
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app_service[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  dynamic "load_balancer" {
    for_each = each.key == "frontend" ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.frontend.arn
      container_name   = "frontend"
      container_port   = 5000
    }
  }

  service_registries {
    registry_arn = aws_service_discovery_service.services[each.key].arn
  }

  tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# REVIEW  (custom locally-built image → push to ECR before apply)
# ═══════════════════════════════════════════════════════════════════════════════

resource "aws_ecs_task_definition" "review" {
  family                   = "${var.project_name}-review"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "review"
    image     = "${aws_ecr_repository.review.repository_url}:latest"
    essential = true

    entryPoint = ["sh", "-c"]
    command    = ["echo $CONFIG_JSON_B64 | base64 -d > /config.json && exec review"]

    environment = concat(local.app_env, [
      { name = "MEMC_TIMEOUT", value = tostring(var.memc_timeout) }
    ])

    secrets = [{
      name      = "CONFIG_JSON_B64"
      valueFrom = aws_ssm_parameter.config_json.arn
    }]

    logConfiguration = local.log_driver
  }])
}

resource "aws_ecs_service" "review" {
  name            = "review"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.review.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.services["review"].arn
  }

  tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# ATTRACTIONS  (custom locally-built image → push to ECR before apply)
# ═══════════════════════════════════════════════════════════════════════════════

resource "aws_ecs_task_definition" "attractions" {
  family                   = "${var.project_name}-attractions"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "attractions"
    image     = "${aws_ecr_repository.attractions.repository_url}:latest"
    essential = true

    entryPoint = ["sh", "-c"]
    command    = ["echo $CONFIG_JSON_B64 | base64 -d > /config.json && exec attractions"]

    environment = concat(local.app_env, [
      { name = "MEMC_TIMEOUT", value = tostring(var.memc_timeout) }
    ])

    secrets = [{
      name      = "CONFIG_JSON_B64"
      valueFrom = aws_ssm_parameter.config_json.arn
    }]

    logConfiguration = local.log_driver
  }])
}

resource "aws_ecs_service" "attractions" {
  name            = "attractions"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.attractions.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.services["attractions"].arn
  }

  tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# MONGODB  (one task + service per data store, ephemeral storage for benchmarks)
# ═══════════════════════════════════════════════════════════════════════════════

resource "aws_ecs_task_definition" "mongodb" {
  for_each = local.mongodb_services

  family                   = "${var.project_name}-mongodb-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "mongodb-${each.key}"
    image     = "mongo:5.0"
    essential = true

    portMappings = [{ containerPort = 27017, protocol = "tcp" }]

    logConfiguration = local.log_driver
  }])
}

resource "aws_ecs_service" "mongodb" {
  for_each = local.mongodb_services

  name            = "mongodb-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mongodb[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.services["mongodb-${each.key}"].arn
  }

  tags = local.common_tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# MEMCACHED  (rate, profile, reserve, review)
# ═══════════════════════════════════════════════════════════════════════════════

resource "aws_ecs_task_definition" "memcached" {
  for_each = local.memcached_services

  family                   = "${var.project_name}-memcached-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "memcached-${each.key}"
    image     = "memcached:latest"
    essential = true

    portMappings = [{ containerPort = 11211, protocol = "tcp" }]

    environment = [
      { name = "MEMCACHED_CACHE_SIZE", value = "128" },
      { name = "MEMCACHED_THREADS", value = "2" },
    ]

    logConfiguration = local.log_driver
  }])
}

resource "aws_ecs_service" "memcached" {
  for_each = local.memcached_services

  name            = "memcached-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.memcached[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.services["memcached-${each.key}"].arn
  }

  tags = local.common_tags
}
