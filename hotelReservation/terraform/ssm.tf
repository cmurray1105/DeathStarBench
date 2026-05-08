locals {
  # Cloud Map private DNS namespace used by all ECS services.
  sd_namespace = "${var.project_name}.local"

  # config.json rewritten to use Cloud Map hostnames.
  # The app reads this file at /config.json inside each container.
  config_json_content = jsonencode({
    consulAddress           = "consul.${local.sd_namespace}:8500"
    jaegerAddress           = "jaeger.${local.sd_namespace}:6831"
    FrontendPort            = "5000"
    GeoPort                 = "8083"
    GeoMongoAddress         = "mongodb-geo.${local.sd_namespace}:27017"
    ProfilePort             = "8081"
    ProfileMongoAddress     = "mongodb-profile.${local.sd_namespace}:27017"
    ProfileMemcAddress      = "memcached-profile.${local.sd_namespace}:11211"
    ReviewPort              = "8088"
    ReviewMongoAddress      = "mongodb-review.${local.sd_namespace}:27017"
    ReviewMemcAddress       = "memcached-review.${local.sd_namespace}:11211"
    AttractionsPort         = "8089"
    AttractionsMongoAddress = "mongodb-attractions.${local.sd_namespace}:27017"
    RatePort                = "8084"
    RateMongoAddress        = "mongodb-rate.${local.sd_namespace}:27017"
    RateMemcAddress         = "memcached-rate.${local.sd_namespace}:11211"
    RecommendPort           = "8085"
    RecommendMongoAddress   = "mongodb-recommendation.${local.sd_namespace}:27017"
    ReservePort             = "8087"
    ReserveMongoAddress     = "mongodb-reservation.${local.sd_namespace}:27017"
    ReserveMemcAddress      = "memcached-reserve.${local.sd_namespace}:11211"
    SearchPort              = "8082"
    UserPort                = "8086"
    UserMongoAddress        = "mongodb-user.${local.sd_namespace}:27017"
    KnativeDomainName       = ""
  })

  # Base64-encoded so the container can decode it with:
  #   echo $CONFIG_JSON_B64 | base64 -d > /config.json
  config_json_b64 = base64encode(local.config_json_content)
}

resource "aws_ssm_parameter" "config_json" {
  name        = "/${var.project_name}/config-json-b64"
  description = "Base64-encoded config.json for hotel-reservation services"
  type        = "String"
  value       = local.config_json_b64

  tags = local.common_tags
}
