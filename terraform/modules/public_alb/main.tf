locals {
  resource_name       = substr("${var.name_prefix}-${var.environment}-public", 0, 32)
  certificate_arn     = var.public_tls_mode == "route53" ? aws_acm_certificate.public[0].arn : var.public_imported_certificate_arn
  github_cidr_batches = chunklist(var.github_hooks_ipv4_cidrs, 2)
  normalized_hostname = var.public_hostname == null ? null : trimsuffix(var.public_hostname, ".")
}

resource "aws_security_group" "alb" {
  name_prefix = "${local.resource_name}-"
  description = "Shared public ALB ingress and fixed EKS NodePort egress"
  vpc_id      = var.vpc_id

  ingress {
    description = "Public HTTP redirected to HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Public HTTPS for the frontend and restricted Jenkins webhook rule"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description     = "Frontend NodePort on EKS managed nodes"
    from_port       = var.frontend_node_port
    to_port         = var.frontend_node_port
    protocol        = "tcp"
    security_groups = [var.node_alb_security_group_id]
  }

  egress {
    description     = "Jenkins webhook NodePort on EKS managed nodes"
    from_port       = var.jenkins_webhook_node_port
    to_port         = var.jenkins_webhook_node_port
    protocol        = "tcp"
    security_groups = [var.node_alb_security_group_id]
  }

  tags = merge(var.common_tags, {
    Name        = "${local.resource_name}-alb"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "alb_to_frontend" {
  description              = "Allow only the shared ALB to the frontend NodePort"
  type                     = "ingress"
  from_port                = var.frontend_node_port
  to_port                  = var.frontend_node_port
  protocol                 = "tcp"
  security_group_id        = var.node_alb_security_group_id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_to_jenkins_webhook" {
  description              = "Allow only the shared ALB to the Jenkins webhook NodePort"
  type                     = "ingress"
  from_port                = var.jenkins_webhook_node_port
  to_port                  = var.jenkins_webhook_node_port
  protocol                 = "tcp"
  security_group_id        = var.node_alb_security_group_id
  source_security_group_id = aws_security_group.alb.id
}

resource "aws_lb" "public" {
  name               = local.resource_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false
  drop_invalid_header_fields = true

  tags = merge(var.common_tags, {
    Name        = local.resource_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_lb_target_group" "frontend" {
  name        = substr("${var.name_prefix}-${var.environment}-frontend", 0, 32)
  port        = var.frontend_node_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15
    matcher             = "200-399"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = merge(var.common_tags, {
    Name        = "${local.resource_name}-frontend"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_lb_target_group" "jenkins_webhook" {
  name        = substr("${var.name_prefix}-${var.environment}-jenkins", 0, 32)
  port        = var.jenkins_webhook_node_port
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15
    matcher             = "200-399"
    path                = "/login"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3
  }

  tags = merge(var.common_tags, {
    Name        = "${local.resource_name}-jenkins-webhook"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

resource "aws_autoscaling_attachment" "frontend" {
  autoscaling_group_name = var.node_autoscaling_group_name
  lb_target_group_arn    = aws_lb_target_group.frontend.arn
}

resource "aws_autoscaling_attachment" "jenkins_webhook" {
  autoscaling_group_name = var.node_autoscaling_group_name
  lb_target_group_arn    = aws_lb_target_group.jenkins_webhook.arn
}

resource "aws_acm_certificate" "public" {
  count = var.public_tls_mode == "route53" ? 1 : 0

  domain_name       = local.normalized_hostname
  validation_method = "DNS"

  tags = merge(var.common_tags, {
    Name        = "${local.resource_name}-certificate"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "certificate_validation" {
  for_each = var.public_tls_mode == "route53" ? {
    for option in aws_acm_certificate.public[0].domain_validation_options :
    option.domain_name => {
      name   = option.resource_record_name
      record = option.resource_record_value
      type   = option.resource_record_type
    }
  } : {}

  allow_overwrite = true
  zone_id         = var.public_route53_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
}

resource "aws_acm_certificate_validation" "public" {
  count = var.public_tls_mode == "route53" ? 1 : 0

  certificate_arn         = aws_acm_certificate.public[0].arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = local.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }

  depends_on = [aws_acm_certificate_validation.public]
}

resource "aws_lb_listener_rule" "jenkins_webhook" {
  for_each = {
    for index, cidrs in local.github_cidr_batches : tostring(index) => cidrs
  }

  listener_arn = aws_lb_listener.https.arn
  priority     = 100 + tonumber(each.key)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins_webhook.arn
  }

  condition {
    path_pattern {
      values = ["/github-webhook/"]
    }
  }

  condition {
    source_ip {
      values = each.value
    }
  }
}

resource "aws_route53_record" "public" {
  count = var.public_tls_mode == "route53" ? 1 : 0

  zone_id = var.public_route53_zone_id
  name    = local.normalized_hostname
  type    = "A"

  alias {
    name                   = aws_lb.public.dns_name
    zone_id                = aws_lb.public.zone_id
    evaluate_target_health = true
  }
}