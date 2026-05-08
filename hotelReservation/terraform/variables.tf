variable "aws_region" {
  description = "AWS region where resources are deployed."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Tag/name prefix for created resources."
  type        = string
  default     = "deathstarbench-hotel-reservation"
}

variable "instance_type" {
  description = "EC2 instance type for running docker-compose services."
  type        = string
  default     = "t3.large"
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH access. Leave empty to disable SSH key auth."
  type        = string
  default     = ""
}

variable "ssh_cidr" {
  description = "CIDR block allowed to SSH to the EC2 host."
  type        = string
  default     = "0.0.0.0/0"
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to access the hotel reservation HTTP endpoint (port 5000) and Jaeger UI (16686)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "repo_url" {
  description = "Git repository URL for DeathStarBench source code."
  type        = string
  default     = "https://github.com/delimitrou/DeathStarBench.git"
}

variable "repo_branch" {
  description = "Git branch to deploy from."
  type        = string
  default     = "master"
}

variable "app_path" {
  description = "Path to app folder inside the repository."
  type        = string
  default     = "hotelReservation"
}

variable "docker_compose_file" {
  description = "Compose file to start services."
  type        = string
  default     = "docker-compose.yml"
}

variable "docker_compose_env" {
  description = "Environment variables exported before running docker compose (e.g. TLS, GC, LOG_LEVEL)."
  type        = map(string)
  default     = {}
}
