locals {
  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
  }
}

# ── EKS Cluster ───────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-eks"
  version  = var.eks_version
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = var.allowed_api_cidrs
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
    aws_cloudwatch_log_group.eks_cluster,
  ]
}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.project_name}-eks/cluster"
  retention_in_days = 7
  tags              = local.common_tags
}

# ── OIDC Provider (required for IRSA) ────────────────────────────────────────

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  tags            = local.common_tags
}

# ── Managed Node Group ────────────────────────────────────────────────────────

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = aws_subnet.private[*].id
  instance_types  = var.node_instance_types
  disk_size       = var.node_disk_size_gb

  scaling_config {
    min_size     = var.node_min_size
    max_size     = var.node_max_size
    desired_size = var.node_desired_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = local.common_tags

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_readonly,
  ]
}

# ── EKS Add-ons ───────────────────────────────────────────────────────────────

resource "aws_eks_addon" "coredns" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.main]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = aws_eks_cluster.main.name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.main]
}

# ── AWS Load Balancer Controller (Helm) ──────────────────────────────────────

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller.arn
  }

  depends_on = [
    aws_eks_node_group.main,
    aws_iam_openid_connect_provider.eks,
  ]
}

# ── hotel-reservation namespace ───────────────────────────────────────────────

resource "kubernetes_namespace" "hotel_reservation" {
  metadata {
    name = var.helm_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  depends_on = [aws_eks_node_group.main]
}

# ── hotel-reservation app (existing Helm chart in the repo) ──────────────────
# Uses only public Docker Hub images — no ECR build required.
# review + attractions are skipped (require locally-built images).

resource "helm_release" "hotel_reservation" {
  name       = "hotel-reservation"
  chart      = "${path.module}/../../helm-chart/hotelreservation"
  namespace  = kubernetes_namespace.hotel_reservation.metadata[0].name
  timeout    = 300

  values = [yamlencode({
    global = {
      replicas        = 1
      imagePullPolicy = "IfNotPresent"
      mongodb = {
        persistentVolume = { enabled = false }
      }
      services = {
        environments = {
          TLS                 = "0"
          LOG_LEVEL           = var.log_level
          JAEGER_SAMPLE_RATIO = tostring(var.jaeger_sample_ratio)
          MEMC_TIMEOUT        = tostring(var.memc_timeout)
          GC                  = tostring(var.gc_target)
        }
      }
    }
  })]

  depends_on = [
    aws_eks_node_group.main,
    helm_release.aws_load_balancer_controller,
  ]
}

# ── groundcover collector (eBPF sensor DaemonSet) ────────────────────────────
# Self-serve backend already provisioned; this installs only the collector.
# Token is from: app.groundcover.com → Settings → Clusters → Add Cluster

resource "helm_release" "groundcover" {
  name             = "groundcover"
  repository       = "https://helm.groundcover.com/"
  chart            = "groundcover"
  namespace        = "groundcover"
  create_namespace = true
  timeout          = 300

  set_sensitive {
    name  = "global.groundcover_token"
    value = var.groundcover_api_key
  }

  set {
    name  = "global.clusterName"
    value = aws_eks_cluster.main.name
  }

  depends_on = [aws_eks_node_group.main]
}
