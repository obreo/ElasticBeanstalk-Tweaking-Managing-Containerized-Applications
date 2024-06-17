# VPC
resource "aws_vpc" "vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.name}"
  }
}

# EC2 Subnet - Primary
resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true

  tags = {
    Purpose = "${var.name}"
    Name    = "subnet_a"
  }
}

# EC2 Subnet - Secondary
resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region}b"
  map_public_ip_on_launch = true

  tags = {
    Purpose = "${var.name}"
    Name    = "subnet_b"
  }
}

# RDS Subnet - Primary
resource "aws_subnet" "subnet_c" {
  count                   = var.rds_port > 0 ? 1 : 0
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "${var.region}c"
  map_public_ip_on_launch = true

  tags = {
    Purpose = "${var.name}"
    Name    = "subnet_c"
  }
}

# RDS Subnet - Secondary
resource "aws_subnet" "subnet_d" {
  count                   = var.rds_port > 0 ? 1 : 0
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "${var.region}d"
  map_public_ip_on_launch = true

  tags = {
    Purpose = "${var.name}"
    Name    = "subnet_d"
  }
}


# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.name}"
  }
}


# Route table
# Routing all subnet to the internet / and later restricting access using ACLs
resource "aws_route_table" "route" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.name}"
  }
}

resource "aws_route_table_association" "subnet_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.route.id
}

resource "aws_route_table_association" "subnet_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.route.id
}

resource "aws_route_table_association" "subnet_c" {
  count          = var.rds_port > 0 ? 1 : 0
  subnet_id      = aws_subnet.subnet_c[count.index].id
  route_table_id = aws_route_table.route.id
}

resource "aws_route_table_association" "subnet_d" {
  count          = var.rds_port > 0 ? 1 : 0
  subnet_id      = aws_subnet.subnet_d[count.index].id
  route_table_id = aws_route_table.route.id
}

# ACL for RDS. Autoscaling groups don't support ACL, so we'll skip this step for the subnet_a & subnet_b, but would require modification if RDS was created:
resource "aws_network_acl" "acl" {
  count      = var.rds_port > 0 ? 1 : 0
  vpc_id     = aws_vpc.vpc.id
  subnet_ids = [aws_subnet.subnet_c[count.index].id, aws_subnet.subnet_d[count.index].id]

  egress {
    protocol   = "-1"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 101
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = var.rds_port
    to_port    = var.rds_port
  }

  tags = {
    Name = "${var.name}"
  }
}


# Security Groups
#Instances - Allowing ports 80 & 443 & 22
resource "aws_security_group" "allow_access" {
  name        = "${var.name}_allow_inbound"
  description = "Allow inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name  = "inbound"
    Ports = "80/443/22"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.allow_access.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_http" {
  security_group_id = aws_security_group.allow_access.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_ingress_rule" "allow_ssh0" {
  security_group_id = aws_security_group.allow_access.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
resource "aws_vpc_security_group_egress_rule" "instacne_allow_all_egress" {
  security_group_id = aws_security_group.allow_access.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


# Database - Allowing port for RDS
resource "aws_security_group" "rds" {
  count       = var.rds_port > 0 ? 1 : 0
  name        = "RDS-${var.name}"
  description = "Allow access"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name  = "${var.name}-RDS"
    Ports = "${var.rds_port}"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_database" {
  count             = var.rds_port > 0 ? 1 : 0
  security_group_id = aws_security_group.rds[count.index].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = var.rds_port
  ip_protocol       = "tcp"
  to_port           = var.rds_port
}

resource "aws_vpc_security_group_egress_rule" "allow_database_egress" {
  count             = var.rds_port > 0 ? 1 : 0
  security_group_id = aws_security_group.rds[count.index].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


# Load balancer

#Instances - Allowing ports 80 & 443
resource "aws_security_group" "load_balancer" {
  count       = length(var.Loadbalanced_resource_count) == length("true") ? 1 : 0
  name        = "load_balancer_allow_tls"
  description = "Allow inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name  = "allow_http"
    Ports = "80/443"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_access_https" {
  count       = length(var.Loadbalanced_resource_count) == length("true") ? 1 : 0
  security_group_id = aws_security_group.load_balancer[count.index].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "allow_access_http" {
  count       = length(var.Loadbalanced_resource_count) == length("true") ? 1 : 0
  security_group_id = aws_security_group.load_balancer[count.index].id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "instacne_allow_access_all_egress" {
  count       = length(var.Loadbalanced_resource_count) == length("true") ? 1 : 0
  security_group_id = aws_security_group.load_balancer[count.index].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}
