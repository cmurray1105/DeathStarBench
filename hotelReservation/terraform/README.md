# Terraform deployment (AWS)

This folder provisions a single Amazon EC2 host and deploys DeathStarBench `hotelReservation` via `docker compose`.

## What this creates

- 1 EC2 instance (Amazon Linux 2023)
- 1 Security Group
- Uses your **default VPC** and the first default subnet
- Starts `hotelReservation/docker-compose.yml` on boot

## Prerequisites

- Terraform >= 1.5
- AWS credentials configured locally (CLI profile, env vars, or SSO)
- An AWS account with permission to create EC2 + Security Group resources

## Quick start

1. Copy variables file:

   - `cp terraform.tfvars.example terraform.tfvars`

2. Update `terraform.tfvars` (especially `ssh_cidr` and `repo_url`).

3. Deploy:

   - `terraform init`
   - `terraform plan`
   - `terraform apply`

4. After apply, use outputs:

   - `app_url` → Hotel reservation endpoint
   - `jaeger_url` → Jaeger UI

## Runtime config

Set hotelReservation environment variables using `docker_compose_env` in `terraform.tfvars`, for example:

- `TLS`
- `GC`
- `JAEGER_SAMPLE_RATIO`
- `MEMC_TIMEOUT`
- `LOG_LEVEL`

## Destroy

- `terraform destroy`

## Notes

- This is a simple benchmark-focused deployment, not production hardened.
- Restrict `ssh_cidr` and `allowed_ingress_cidrs` before exposing publicly.
- If you prefer your fork, set `repo_url` to your GitHub repository URL.
