variable "aws_region" {
  description = "AWS region where resources are deployed."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Tag/name prefix for all created resources."
  type        = string
  default     = "deathstarbench-hotel-reservation"
}

# ── Network ───────────────────────────────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# ── EKS Cluster ───────────────────────────────────────────────────────────────

variable "eks_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.30"
}

variable "allowed_api_cidrs" {
  description = "CIDR blocks allowed to reach the EKS public API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ── Node Group ────────────────────────────────────────────────────────────────

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group."
  type        = list(string)
  default     = ["m5.xlarge"]
}

variable "node_disk_size_gb" {
  description = "Root EBS disk size in GiB for each node."
  type        = number
  default     = 50
}

variable "node_min_size" {
  description = "Minimum number of nodes in the managed node group."
  type        = number
  default     = 2
}

variable "node_max_size" {
  description = "Maximum number of nodes in the managed node group."
  type        = number
  default     = 6
}

variable "node_desired_size" {
  description = "Desired number of nodes in the managed node group."
  type        = number
  default     = 3
}

# ── Application ───────────────────────────────────────────────────────────────

variable "helm_namespace" {
  description = "Kubernetes namespace for hotel-reservation workloads."
  type        = string
  default     = "hotel-reservation"
}

# ── App runtime ───────────────────────────────────────────────────────────────

variable "log_level" {
  description = "Log verbosity for hotel-reservation services (ERROR, WARNING, INFO, DEBUG)."
  type        = string
  default     = "INFO"
}

variable "jaeger_sample_ratio" {
  description = "Fraction of requests sampled by Jaeger (0.0–1.0)."
  type        = number
  default     = 0.01
}

variable "memc_timeout" {
  description = "Memcached timeout in seconds."
  type        = number
  default     = 2
}

variable "gc_target" {
  description = "Go GC target percentage (GOGC)."
  type        = number
  default     = 100
}

# ── groundcover ───────────────────────────────────────────────────────────────

variable "groundcover_api_key" {
  description = "groundcover API key (token). Obtain from app.groundcover.com."
  type        = string
  sensitive   = true
}
