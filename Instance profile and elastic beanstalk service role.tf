# Instance profile
# Use an instance profile to pass an IAM role to an EC2 instance. 
resource "aws_iam_instance_profile" "instance_profile" {
  name = "elaticbeanstalk_instance_profile"
  role = aws_iam_role.assume_role.name
}

# Role to be passed
resource "aws_iam_role" "assume_role" {
  name               = "elasticbeanstalk_assume_role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

# Assumed role (resource) used for the role
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# WebTier Profile
resource "aws_iam_role_policy_attachment" "elastic_beanstalk_policy" {
  role       = aws_iam_role.assume_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

# Container Tier profile
resource "aws_iam_role_policy_attachment" "elastic_beanstalk_policy_2" {
  role       = aws_iam_role.assume_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkMulticontainerDocker"
}

# Worker Tier profile
resource "aws_iam_role_policy_attachment" "elastic_beanstalk_policy_3" {
  role       = aws_iam_role.assume_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWorkerTier"
}

# Provides EC2 access to S3 bucket to download revision. This role is needed by the CodeDeploy agent on EC2 instances (codedeploy elastic beanstalk deployment)
resource "aws_iam_role_policy_attachment" "elastic_beanstalk_policy_4" {
  role       = aws_iam_role.assume_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforAWSCodeDeploy"
}

# Custom policy below
resource "aws_iam_role_policy_attachment" "elastic_beanstalk_policy_5" {
  role       = aws_iam_role.assume_role.name
  policy_arn = aws_iam_policy.ebstalk-additionals.arn
}

##########################################################################
# Service Role to pass to elastic beanstalk
resource "aws_iam_role" "elasticbeanstalk_service_role" {
  name               = "elasticbeanstalk-service-role-terraform"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.elasticbeanstalk-service-role.json
}

# Assumed role (resource) used for the role
data "aws_iam_policy_document" "elasticbeanstalk-service-role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["elasticbeanstalk.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# To allow s3 lifecycle modification
resource "aws_iam_role_policy_attachment" "elasticbeanstalk_service_policy_0" {
  role       = aws_iam_role.elasticbeanstalk_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}
# To allow healthchecks
resource "aws_iam_role_policy_attachment" "elasticbeanstalk_service_policy_1" {
  role       = aws_iam_role.elasticbeanstalk_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticBeanstalkEnhancedHealth"
}
# To manage updates of environment
resource "aws_iam_role_policy_attachment" "elasticbeanstalk_service_policy_2" {
  role       = aws_iam_role.elasticbeanstalk_service_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy"
}
# Custom policy below
resource "aws_iam_role_policy_attachment" "elasticbeanstalk_service_policy_4" {
  role       = aws_iam_role.elasticbeanstalk_service_role.name
  policy_arn = aws_iam_policy.ebstalk-additionals.arn
}

####################################
# ebstalk-additionals Policy details
resource "aws_iam_policy" "ebstalk-additionals" {
  name        = "ebstalk-additionals"
  path        = "/"
  description = "Additional policies required for elstic beanstalk with codebuild cicd"

  # Terraform expression result to valid JSON syntax.
  # Below, ECR resources used for ECR repository - in case of using docker runner.
  # S3 resources to use the s3 bucket for retrieval of app version.
  # Elastic load balancer policies used for elastic beanstalk load balanced type, for the instance profile so ec2 instances allow routing to the load balancer.
  # EC2 policies to resolve authorization error.
  # SSM policies for elastic beanstalk patch updates and parameter store access.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "AllowingaccesstoECRrepositories",
        "Effect" : "Allow",
        "Action" : [
          "ecr:DescribeRepositoryCreationTemplate",
          "ecr:GetRegistryPolicy",
          "ecr:DescribeImageScanFindings",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeRegistry",
          "ecr:DescribePullThroughCacheRules",
          "ecr:DescribeImageReplicationStatus",
          "ecr:GetAuthorizationToken",
          "ecr:ListTagsForResource",
          "ecr:BatchGetRepositoryScanningConfiguration",
          "ecr:GetRegistryScanningConfiguration",
          "ecr:ValidatePullThroughCacheRule",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetRepositoryPolicy",
          "ecr:GetLifecyclePolicy",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "AllowingAccessToELBResources",
        "Effect" : "Allow",
        "Action" : [
          "elasticloadbalancing:DescribeLoadBalancerPolicyTypes",
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTrustStoreAssociations",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeLoadBalancerPolicies",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeInstanceHealth",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DescribeTrustStoreRevocations",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeTrustStores",
          "elasticloadbalancing:DescribeAccountLimits",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:*"
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "Additonals",
        "Effect" : "Allow",
        "Action" : [
          "s3:ListAllMyBuckets",
          "ec2:DescribeNetworkAcls",
          "ec2:DescribeRouteTables",
        ],
        "Resource" : "*"
      },
      {
        "Sid" : "AllowaccesstocustomS3buckett",
        "Effect" : "Allow",
        "Action" : [
          "s3:PutObject",
          "s3:GetObjectAcl",
          "s3:GetObject",
          "s3:GetBucketPolicy",
          "s3:ListBucketMultipartUploads",
          "s3:AbortMultipartUpload",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:PutObjectAcl",
          "s3:ListMultipartUploadParts"
        ],
        "Resource" : [
          "arn:aws:s3:::${var.name}.bucket",
          "arn:aws:s3:::${var.name}.bucket/*"
        ]
      },
      {
        "Sid" : "AllowSSM",
        "Effect" : "Allow",
        "Action" : ["ssm:GetParametersByPath", "ssm:GetParameters", "ssm:UpdateInstanceInformation"]
        "Resource" : "arn:aws:ssm:${var.region}:${var.account_id}:parameter/*"
      }
    ]
  })
}


# Keypair
resource "aws_key_pair" "elastic_beanstalk_keypair" {
  key_name   = "${var.name}-sshkey"
  public_key = var.ssh-key

}