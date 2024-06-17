# Elastic beanstalk environment - SingleInstance type

# Elastic beanstalk version
resource "aws_elastic_beanstalk_application_version" "version_singleinstance" {
  count       = length(var.singleinstance_resource_count) == length("true") ? 1 : 0
  name        = "${var.name}-singleinstance"
  application = aws_elastic_beanstalk_application.application_singleinstance[count.index].name
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
resource "aws_elastic_beanstalk_application" "application_singleinstance" {
  count       = length(var.singleinstance_resource_count) == length("true") ? 1 : 0
  name        = "${var.name}-singleinstance"
  description = "Running ${var.name}"
  appversion_lifecycle {
    service_role          = aws_iam_role.elasticbeanstalk_service_role.arn
    max_count             = 3
    delete_source_from_s3 = "true"
  }
}

# Elastic beanstalk env
resource "aws_elastic_beanstalk_environment" "environment_singleinstance" {
  count         = length(var.singleinstance_resource_count) == length("true") ? 1 : 0
  name          = "${var.name}-singleinstance"
  application   = aws_elastic_beanstalk_application.application_singleinstance[count.index].id
  version_label = aws_elastic_beanstalk_application_version.version_singleinstance[count.index].id


  # Reference Doc: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/concepts.platforms.html
  solution_stack_name = "64bit Amazon Linux 2023 v4.3.3 running Docker"

  # Required
  cname_prefix = "${var.name}-singleinstance"

  # Reference Doc: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/command-options-general.html
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"
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
    value     = aws_subnet.subnet_a.id
  }
  # Ip Assoscaition
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "True"
  }
  # Instance Profile
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.instance_profile.name
  }
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
    value     = "1"
  }
  # Health reporting type
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  # Rolling upadtes type
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "DeploymentPolicy"
    value     = "Immutable"
  }

  # Patch Level
  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = "patch"
  }
  # Command Timeout
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name      = "Timeout"
    value     = "800"
  }
  # Environment Variables - if any
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
      setting,
      version_label, # Ignore changes
    ]
  }

}


/*
Sample settings:
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
    name = "AssociatePublicIpAddress"
    value = "false"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "IamInstanceProfile"
    value = "app-ec2-role"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "SecurityGroups"
    value = "${aws_security_group.app-prod.id}"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "EC2KeyName"
    value = "${aws_key_pair.app.id}"
  }
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name = "InstanceType"
    value = "t2.micro"
  }
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name = "ServiceRole"
    value = "aws-elasticbeanstalk-service-role"
  }
  setting {
    namespace = "aws:ec2:vpc"
    name = "ELBScheme"
    value = "public"
  }
  setting {
    namespace = "aws:elb:loadbalancer"
    name = "CrossZone"
    value = "true"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "BatchSize"
    value = "30"
  }
  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "BatchSizeType"
    value = "Percentage"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name = "Availability Zones"
    value = "Any 2"
  }
  setting {
    namespace = "aws:autoscaling:asg"
    name = "MinSize"
    value = "1"
  }
  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name = "RollingUpdateType"
    value = "Health"
  }


*/



