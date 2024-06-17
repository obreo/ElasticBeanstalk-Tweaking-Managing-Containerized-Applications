# ALB
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb
resource "aws_lb" "elb" {
  count                      = length(var.Loadbalanced_resource_count) == length("true") ? 1 : 0
  name                       = "${var.name}-elb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = ["${aws_security_group.load_balancer[count.index].id}"]
  subnets                    = ["${aws_subnet.subnet_a.id}", "${aws_subnet.subnet_b.id}"]
  enable_deletion_protection = false
  tags = {
    Environment = "${var.name}"
  }
  lifecycle {
    ignore_changes = [
      security_groups, # Ignore changes
      tags             # Ignore changes
    ]
  }
}

# Listener
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener
resource "aws_lb_listener" "http" {
  count             = length(var.Loadbalanced_resource_count) == length("true") ? 1 : 0
  load_balancer_arn = aws_lb.elb[count.index].arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.elb[count.index].arn
  }
}

# Target Group
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group
resource "aws_lb_target_group" "elb" {
  count    = length(var.Loadbalanced_resource_count) == length("true") ? 1 : 0
  name     = "${var.name}-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id
}

