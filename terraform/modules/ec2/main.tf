resource "aws_instance" "frontend" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = compact([var.frontend_security_group_id, var.ssh_admin_security_group_id])
  iam_instance_profile   = var.instance_profile_name

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-${var.frontend_name}"
    Environment = var.environment
    Role        = "frontend"
    ManagedBy   = "Terraform"
  })
}

resource "aws_instance" "backend" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = compact([var.backend_security_group_id, var.ssh_admin_security_group_id])
  iam_instance_profile   = var.instance_profile_name

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-${var.backend_name}"
    Environment = var.environment
    Role        = "backend"
    ManagedBy   = "Terraform"
  })
}

resource "aws_instance" "worker" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = compact([var.worker_security_group_id, var.ssh_admin_security_group_id])
  iam_instance_profile   = var.instance_profile_name

  tags = merge(var.common_tags, {
    Name        = "${var.name_prefix}-${var.environment}-${var.worker_name}"
    Environment = var.environment
    Role        = "worker"
    ManagedBy   = "Terraform"
  })
}

resource "aws_launch_template" "worker_template" {
  name = "${var.name_prefix}-${var.environment}-worker-template"

  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.instance_profile_name
  }

  block_device_mappings {
    device_name = "/dev/sdb"

    ebs {
      delete_on_termination = false
      encrypted             = false
      iops                  = 3000
      throughput            = 125
      volume_size           = 15
      volume_type           = "gp3"
    }
  }

  network_interfaces {
    associate_public_ip_address = true
    delete_on_termination       = true
    device_index                = 0
    security_groups             = compact([var.worker_security_group_id, var.ssh_admin_security_group_id])
    subnet_id                   = var.subnet_id
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    http_endpoint               = "enabled"
    http_protocol_ipv6          = "disabled"
    instance_metadata_tags      = "disabled"
  }

  monitoring {
    enabled = false
  }

  placement {
    availability_zone = var.public_availability_zone
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.common_tags, {
      Name        = "${var.name_prefix}-${var.environment}-${var.worker_name}"
      Environment = var.environment
      Role        = "worker"
      ManagedBy   = "Terraform"
    })
  }
}