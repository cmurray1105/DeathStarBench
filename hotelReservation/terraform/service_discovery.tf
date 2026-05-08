# AWS Cloud Map provides private DNS for ECS service-to-service communication.
# Each service registers itself under <service>.hotel-reservation.local.

resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = local.sd_namespace
  description = "Private DNS for Hotel Reservation microservices"
  vpc         = aws_vpc.main.id

  tags = local.common_tags
}

locals {
  # All logical service names that need a Cloud Map entry.
  all_sd_services = toset(concat(
    ["consul", "jaeger", "review", "attractions"],
    keys(local.app_services),
    [for k in local.mongodb_services : "mongodb-${k}"],
    [for k in local.memcached_services : "memcached-${k}"]
  ))
}

resource "aws_service_discovery_service" "services" {
  for_each = local.all_sd_services

  name = each.key

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.main.id
    routing_policy = "MULTIVALUE"

    dns_records {
      ttl  = 10
      type = "A"
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = local.common_tags
}
