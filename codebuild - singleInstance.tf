# Reference doc: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project
# Reference doc: https://docs.aws.amazon.com/codebuild/latest/APIReference/API_Types.html
# Reference doc: https://docs.aws.amazon.com/codebuild/latest/userguide/welcome.html
resource "aws_codebuild_project" "project_singleInstance" {
  count         = length(var.singleinstance_resource_count) == length("true") ? 1 : 0
  name          = "${var.name}-docker-elasticebanstalk"
  description   = "app on elastic beanstalk."
  build_timeout = 20 # Minutes
  service_role  = aws_iam_role.codebuild-elasticbeanstalk-role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  # You can save time when your project builds by using a cache. A cache can store reusable pieces of your build environment and use them across multiple builds. 
  # Your build project can use one of two types of caching: Amazon S3 or local. 
  cache {
    type     = "S3"
    location = aws_s3_bucket.bucket.bucket
  }

  environment {
    # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html
    compute_type = "BUILD_GENERAL1_SMALL"
    # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-available.html
    image = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    # https://docs.aws.amazon.com/codebuild/latest/userguide/build-env-ref-compute-types.html#environment.types
    # For Lmbda computes: Only available for environment type LINUX_LAMBDA_CONTAINER and ARM_LAMBDA_CONTAINER
    type = "LINUX_CONTAINER"
    # When you use a cross-account or private registry image, you must use SERVICE_ROLE credentials. When you use an AWS CodeBuild curated image, you must use CODEBUILD credentials.
    image_pull_credentials_type = "CODEBUILD"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "codebuild-log-group"
      stream_name = "codebuild-log-stream"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.bucket.id}/codebuild-build-log"
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = <<EOF
    # This is a buildspec script that will build docker script, compress it and uplode it to s3 bucket, then update the elastic beanstalk environment with it.
    # Make sure that CodeBuild has role to access all the resources mentioned in this script so it can use awscli without authentication.
  version: 0.2
    env:
      variables:
        S3_BUCKET: "${aws_s3_bucket.bucket.bucket}"
        S3_FOLDER: "beanstalk"
        ZIP_FILE_NAME: "${var.name}"
        EB_APP: "${aws_elastic_beanstalk_application.application_singleinstance[count.index].name}"
        EB_ENV: "${aws_elastic_beanstalk_environment.environment_singleinstance[count.index].name}"

    phases:
      pre_build:
        commands:
          # Login to ECR
          - echo 'Logging to ECR registry'
          - aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com
          # Export parameters
          - echo 'Exporting Parameters'
          - while read -r name value; do export_string="$${name##*/}=$value"; echo "$export_string" >> .env; done < <(aws ssm get-parameters-by-path --path "${var.parameter_path}" --with-decryption --query "Parameters[*].[Name,Value]" --output text)
      build:
        commands:
          # Building image
          - echo  'Building Image'
          - docker build -t ${var.name} .

          # Pushing Image to Registry
          - docker tag ${var.name}:latest ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name}:$${CODEBUILD_BUILD_NUMBER}
          - docker push ${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name}:$${CODEBUILD_BUILD_NUMBER}
          
          # Modifying the docker-compose.yml file with the new image tag
          - sed -i "s|<IMAGE>|${var.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.name}:$${CODEBUILD_BUILD_NUMBER}|g" docker-compose.yml

          # Zipping docker-compose.yml with .env file before pushing to s3 bucket.
          - zip $${FILE_NAME}.zip docker-compose.yml .env
      post_build:
        commands:
          # Pushing zip file to S3 bucket
          - echo Pushing $${FILE_NAME}.zip to $${S3_BUCKET}/$${S3_FOLDER} bucket directory.
          - aws s3 cp $${FILE_NAME}.zip s3://$${S3_BUCKET}/$${S3_FOLDER}/$${FILE_NAME}.zip
          
          # Updating Elastic Beanstalk application's version
          - echo Creating a new Elastic Beanstalk application version
          - aws elasticbeanstalk create-application-version --application-name $${EB_APP} --version-label $${CODEBUILD_BUILD_NUMBER} --source-bundle S3Bucket=$${S3_BUCKET},S3Key=$${S3_FOLDER}/$${FILE_NAME}.zip
          - echo Updating the Elastic Beanstalk environment.
          - aws elasticbeanstalk update-environment --environment-name $${EB_ENV} --version-label $${CODEBUILD_BUILD_NUMBER}

    EOF
  }
}

