# Elastic beanstalk environment - loadbalanced type with shared load balancer.

# Elastic beanstalk version
resource "aws_elastic_beanstalk_application_version" "version" {
  count       = length(var.Loadbalanced_resource_count) == length("true") ? 1 : 0
  name        = var.name
  application = aws_elastic_beanstalk_application.application[count.index].name
  description = "application version"
  bucket      = aws_s3_bucket.bucket.id
  key         = aws_s3_object.object.id
  lifecycle {
    ignore_changes = [
      bucket, # Ignore changes to the bucket source
      key,    # Ignore changes to the key source
      name    # Ignore changes to the version name
    ]
  }
}

# Elastic beanstalk app
resource "aws_elastic_beanstalk_application" "application" {
  count       = length(var.Loadbalanced_resource_count) == length("true") ? 1 : 0
  name        = var.name
  description = "Running ${var.name}"
  appversion_lifecycle {
    service_role          = aws_iam_role.elasticbeanstalk_service_role.arn
    max_count             = 3
    delete_source_from_s3 = "true"
  }
}

# Elastic beanstalk env
resource "aws_elastic_beanstalk_environment" "environment" {
  count         = length(var.Loadbalanced_resource_count) == length("true") ? 1 : 0
  name          = var.name
  application   = aws_elastic_beanstalk_application.application[count.index].id
  version_label = aws_elastic_beanstalk_application_version.version[count.index].id

  # Reference Doc: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/concepts.platforms.html
  solution_stack_name = "64bit Amazon Linux 2023 v4.3.3 running Docker"

  # Required
  cname_prefix = var.name

  # Reference Doc: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options-general.html

  # SingleInstance OR LoadBalanced (Default)
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "LoadBalanced"
  }
  #################################
  # Load Balancer Configuration
  # Load Balancer: Shared or Dedicated (shared is only supported for ALB).
  # Doc: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/environments-cfg-alb-shared.html
  #################################
  # Load balancer type
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }
  # Application load balancer type
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerIsShared"
    value     = "true"
  }

  # Load Balancer ARN
  setting {
    namespace = "aws:elbv2:loadbalancer"
    name      = "SharedLoadBalancer"
    value     = aws_lb.elb[count.index].arn
  }

  # CossZone: required if stickiness is enabled.
  setting {
    namespace = "aws:elb:loadbalancer"
    name      = "CrossZone"
    value     = "true"
  }

  # Stickiness: requires SSL certificate for the ALB.
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "StickinessEnabled"
    value     = "false"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "StickinessLBCookieDuration"
    value     = "86400"
  }
  #####################################
  # End of Load Balancer Configuration
  #####################################

  # Setting other than immutable deployment policy and patch updatelevel may reset the preserved credits for T.type instances.
  # Patch Level
  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = "patch"
  }
  # Rolling upadtes type
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = "Immutable"
  }
  # VPC
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.vpc.id
  }
  # Subnets
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = "${aws_subnet.subnet_a.id},${aws_subnet.subnet_b.id}"
  }
  # Ip Assoscaition
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "true"
  }
  # Instance Profile
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.instance_profile.name
  }
  # Service role
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = aws_iam_role.elasticbeanstalk_service_role.name
  }
  # Health Check
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "MatcherHTTPCode"
    value     = "200"
  }
  # Instance type
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = var.instance_type
  }
  # Security Group
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.allow_access.id
  }
  # Keypair
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "EC2KeyName"
    value     = aws_key_pair.elastic_beanstalk_keypair.id
  }
  # Autoscaling - Elastic beanstalk uses autoscaling for all types. If singleInstance used, then 1min/1max.
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "1"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "4"
  }
  # Health reporting type
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }
  #########################################################################################
  # SCALABILITY
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/cloudwatch_concepts.html
  #########################################################################################

  # Scaling Cooldown - 5 min at least for basic resolution.
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "Cooldown"
    value     = "300"
  }
  # BreachDuration = Period * EvaluationPeriods | It should be aligned with the Metrics Resolution Strategy used in CloudWatch.
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Period"
    value     = "5" # min
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "EvaluationPeriods"
    value     = "1" # no of periods
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "BreachDuration"
    value     = "5"
  }
  # Measure types: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/viewing_metrics_with_cloudwatch.html
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "MeasureName"
    value     = "NetworkOut"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "Unit"
    value     = "Bytes"
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "UpperThreshold"
    value     = "6000,000" # bytes
  }
  setting {
    namespace = "aws:autoscaling:trigger"
    name      = "LowerThreshold"
    value     = "200,000" # bytes
  }
  # Command Timeout
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "Timeout"
    value     = "800" # Seconds
  }

  #########################################################################################

  # Environment Variables - If any
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "NPM_USE_PRODUCTION" # To allow elastic beanstalk install Dev dependencies when using `npm install`.
    value     = "false"
  }
  /*
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = ""
    value     = ""
  }
  ...
  */
  lifecycle {
    ignore_changes = [
      #setting,
      version_label, # Ignore changes
    ]
  }
}



/*
Samples:
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateType"
    value     = "Health"
  }

  setting {
    namespace = "aws:elb:loadbalancer"
    name      = "CrossZone"
    value     = "false"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.medium"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBScheme"
    value     = "internet facing"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = 1
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = 2
  }
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

    setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = "${aws_vpc.id}"
  }

  # Listener rule settings
  setting {
    namespace = "aws:elbv2:listenerrule:rule"
    name      = "PathPatterns"
    value     = "/*"
  }
  setting {
    namespace = "aws:elbv2:listenerrule:rule"
    name      = "Process"
    value     = "default"
  }
  setting {
    namespace = "aws:elbv2:listenerrule:rule"
    name      = "Priority"
    value     = "1"
  }

  setting {
    namespace = "aws:elbv2:listenerrule:rule"
    name      = "HostHeaders"
    value     = ""
  }

  setting {
    namespace = "aws:elbv2:listener:80"
    name      = "Rules"
    value     = "rule"
  }
  */




