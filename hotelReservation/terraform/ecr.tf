# ECR repository for the main hotel-reservation image.
# Build the image locally and push before running `terraform apply`:
#   docker build -t <repo_url>:latest ../
#   docker push <repo_url>:latest
#
# The review and attractions services use locally built images.
# Build and push those similarly before deploying.

resource "aws_ecr_repository" "hotel_reservation" {
  name                 = "${var.project_name}/hotel-reservation"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "review" {
  name                 = "${var.project_name}/review"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

resource "aws_ecr_repository" "attractions" {
  name                 = "${var.project_name}/attractions"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.common_tags
}

# Lifecycle policy: keep the last 5 tagged images in each repo.
resource "aws_ecr_lifecycle_policy" "hotel_reservation" {
  repository = aws_ecr_repository.hotel_reservation.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 tagged images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}
