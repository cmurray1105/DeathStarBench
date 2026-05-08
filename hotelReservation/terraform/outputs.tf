output "alb_dns_name" {
  description = "ALB DNS name."
  value       = aws_lb.main.dns_name
}

output "app_url" {
  description = "Hotel Reservation frontend endpoint."
  value       = "http://${aws_lb.main.dns_name}:5000"
}

output "jaeger_url" {
  description = "Jaeger UI endpoint."
  value       = "http://${aws_lb.main.dns_name}:16686"
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.main.name
}

output "ecr_hotel_reservation_url" {
  description = "ECR repository URL for the hotel-reservation image."
  value       = aws_ecr_repository.hotel_reservation.repository_url
}

output "ecr_review_url" {
  description = "ECR repository URL for the review image."
  value       = aws_ecr_repository.review.repository_url
}

output "ecr_attractions_url" {
  description = "ECR repository URL for the attractions image."
  value       = aws_ecr_repository.attractions.repository_url
}

output "service_discovery_namespace" {
  description = "Cloud Map private DNS namespace used by all services."
  value       = aws_service_discovery_private_dns_namespace.main.name
}

output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (ECS tasks)."
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALB)."
  value       = aws_subnet.public[*].id
}
