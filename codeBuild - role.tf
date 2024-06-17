# Attach this role with codebuild application and check the option that allows role modification while codebuild app environment creation.


# Service Role to pass to elastic beanstalk
resource "aws_iam_role" "codebuild-elasticbeanstalk-role" {
  name               = "codebuild-elasticbeanstalk-role-terraform"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.codebuild-service-role.json
}

# Assumed role (resource) used for the role
data "aws_iam_policy_document" "codebuild-service-role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

# Access Elastic beanstalk for environment and applciation update.
resource "aws_iam_role_policy_attachment" "codebuild_policy_1" {
  role       = aws_iam_role.codebuild-elasticbeanstalk-role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-AWSElasticBeanstalk"
}
# Custom policy - expained below:
resource "aws_iam_role_policy_attachment" "codebuild_policy_2" {
  role       = aws_iam_role.codebuild-elasticbeanstalk-role.name
  policy_arn = aws_iam_policy.codebuild-elasticbeanstalk-role.arn
}


####################################

resource "aws_iam_policy" "codebuild-elasticbeanstalk-role" {
  name        = "codebuild-elasticbeanstalk-role-terraform"
  path        = "/"
  description = "Additional policies required for elastic beanstalk with codebuild cicd"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowingECRAccess",
        Effect = "Allow",
        Action = [
          "ecr:PutLifecyclePolicy",
          "ecr:PutImageTagMutability",
          "ecr:DescribeImageScanFindings",
          "ecr:StartImageScan",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:GetDownloadUrlForLayer",
          "ecr:PutImageScanningConfiguration",
          "ecr:DescribeImageReplicationStatus",
          "ecr:ListTagsForResource",
          "ecr:UploadLayerPart",
          "ecr:BatchDeleteImage",
          "ecr:BatchGetRepositoryScanningConfiguration",
          "ecr:PutImage",
          "ecr:BatchGetImage",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:StartLifecyclePolicyPreview",
          "ecr:InitiateLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:ReplicateImage",
          "ecr:GetRepositoryPolicy",
          "ecr:GetLifecyclePolicy",
          "ecr:DescribeRepositoryCreationTemplate",
          "ecr:GetRegistryPolicy",
          "ecr:CreateRepository",
          "ecr:DescribeRegistry",
          "ecr:GetAuthorizationToken",
          "ecr:PutRegistryScanningConfiguration",
          "ecr:CreatePullThroughCacheRule",
          "ecr:GetRegistryScanningConfiguration",
          "ecr:ValidatePullThroughCacheRule",
          "ecr:CreateRepositoryCreationTemplate",
          "ecr:BatchImportUpstreamImage",
          "ecr:UpdatePullThroughCacheRule",
          "ecr:PutReplicationConfiguration"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowEBAccessToAvoidEnvironmentUpdateAuthorizationErrors",
        Effect = "Allow",
        Action = [
          "elasticbeanstalk:*",
          "s3:ListAllMyBuckets",
          "cloudformation:*"
        ],
        Resource = "*"
      },
      {
        Sid    = "AllowS3ToPushBuilds",
        Effect = "Allow",
        Action = [
          "s3:PutObject",
          "s3:GetObjectAcl",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:GetBucketPolicy",
          "s3:PutObjectAcl",
          "s3:ListBucketMultipartUploads",
          "s3:ListMultipartUploadParts",
          "s3:AbortMultipartUpload"
        ],
        Resource = [
          "${aws_s3_bucket.bucket.arn}",
          "${aws_s3_bucket.bucket.arn}/*",
        ]
      },
      {
        Sid    = "AllowCloudWatchAccessLogs"
        Effect = "Allow",
        Resource = [
          "arn:aws:logs:${var.region}:${var.account_id}:log-group:*",
          "arn:aws:logs:${var.region}:${var.account_id}:log-group:*:*"
        ],
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
      },
      {
        Sid    = "ArtifactsToS3CodepipelineDefaultBucket"
        Effect = "Allow",
        Resource = [
          "arn:aws:s3:::codepipeline-${var.region}-*"
        ],
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
      },
      {
        Sid    = "CodeBuildSpecific"
        Effect = "Allow",
        Action = [
          "codebuild:CreateReportGroup",
          "codebuild:CreateReport",
          "codebuild:UpdateReport",
          "codebuild:BatchPutTestCases",
          "codebuild:BatchPutCodeCoverages"
        ],
        Resource = [
          "arn:aws:codebuild:${var.region}:${var.account_id}:report-group/*"
        ]
      },
      {
        Sid    = "CodebuildVPCEC2Related"
        Effect = "Allow",
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeVpcs"
        ],
        Resource = ["*"]
      },
      {
        Sid      = "required"
        Effect   = "Allow",
        Action   = ["ec2:CreateNetworkInterfacePermission"],
        Resource = ["arn:aws:ec2:${var.region}:${var.account_id}:network-interface/*"]
      },
      {
        "Sid" : "AllowSSMParameterAccess",
        "Effect" : "Allow",
        "Action" : ["ssm:GetParametersByPath"]
        "Resource" : "arn:aws:ssm:${var.region}:${var.account_id}:parameter/*"
      }
    ]
  })
}
