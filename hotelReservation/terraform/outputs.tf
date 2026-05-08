output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.hotel_reservation.id
}

output "public_ip" {
  description = "Public IP of the benchmark host."
  value       = aws_instance.hotel_reservation.public_ip
}

output "public_dns" {
  description = "Public DNS of the benchmark host."
  value       = aws_instance.hotel_reservation.public_dns
}

output "app_url" {
  description = "Hotel Reservation HTTP endpoint."
  value       = "http://${aws_instance.hotel_reservation.public_dns}:5000"
}

output "jaeger_url" {
  description = "Jaeger UI endpoint."
  value       = "http://${aws_instance.hotel_reservation.public_dns}:16686"
}
