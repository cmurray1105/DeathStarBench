# ── EKS cluster security group ────────────────────────────────────────────────

resource "aws_security_group" "eks_cluster" {
  name        = "${var.project_name}-eks-cluster"
  description = "EKS control plane security group"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-eks-cluster-sg" })
}

# Allow worker nodes to communicate with the control plane.
resource "aws_security_group_rule" "cluster_ingress_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster.id
  source_security_group_id = aws_security_group.eks_nodes.id
  description              = "Worker nodes → control plane"
}

# ── Worker node security group ────────────────────────────────────────────────

resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-nodes"
  description = "EKS worker node security group"
  vpc_id      = aws_vpc.main.id

  # Nodes communicate freely with each other (pod-to-pod, Consul, etc.)
  ingress {
    description = "Inter-node"
    from_port   = 0
    to_port     = 65535
    protocol    = "-1"
    self        = true
  }

  # Control plane → kubelet
  ingress {
    description     = "Control plane → kubelet"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-eks-nodes-sg" })
}
