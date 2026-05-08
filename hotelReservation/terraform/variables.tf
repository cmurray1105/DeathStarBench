variable "aws_region" {
  description = "AWS region where resources are deployed."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefix for all created resource names and tags."
  type        = string
  default     = "hotel-reservation"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ, minimum 2)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ, minimum 2)."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the ALB (frontend port 5000 + Jaeger port 16686)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ──────────────────────────────────────────────
# hotelReservation runtime config
# ──────────────────────────────────────────────

variable "tls" {
  description = "TLS mode: 0 (off), 1 (on), or a specific cipher suite string."
  type        = string
  default     = "0"
}

variable "gc" {
  description = "Go runtime GC target percentage."
  type        = number
  default     = 100
}

variable "jaeger_sample_ratio" {
  description = "Fraction of requests traced by Jaeger (0.0 – 1.0)."
  type        = number
  default     = 0.01
}

variable "memc_timeout" {
  description = "Memcached client timeout in seconds."
  type        = number
  default     = 2
}

variable "log_level" {
  description = "Log verbosity: ERROR | WARNING | INFO | TRACE | DEBUG."
  type        = string
  default     = "INFO"
}
