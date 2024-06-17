#  Tweaking & Managing Elastic Beanstalk - Containerized Applications - SingleInstance / LoadBalanced - deployed with CICD, Built with IaC - Terrafrom

## Decription
Elastic Beanstalk is one of the popular PaaS AWS services which delivers an easy dashboard to setup an infrastructure for a variety of softewre [runtimes](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/concepts.platforms.html).

This article explains how to tweak and configure containerized applications (Docker runtime) in PaaS services like AWS Elastic Beanstalk, by deploying single instance type (not load balanced) and highly available autoscalable instance type (load balanced) that supports rolling back, and integrated it with continues integration and continues delivery (CI/CD) using infrastracture as code (IaC) with Terraform.

This infrastructure implements a secure and best practice solutions to build and deploy NodeJS application that uses AWS SSM Parameter store for secrets.

## Architecture
![Architecture](/architecture.png)

## Brief Intro
Elastic Beanstalk is one of the Platfrom as a service - PaaS - that AWS cloud offers. It mainly uses other aws services in the backend such as CloudFormation for deployments, Amazon Linux AMI with CodeDeploy, SSM, and CloudWatch buildin agents - to deliver the logs, allow patch updates for the environment and allow Continues delivery strategy - as well as EC2 for instances, S3 for data versioning storage, RDS for database, Autoscaling Group - even for a single instance - and Load Balancer for high availability and autoscalability.

It supports deploying database instances using AWS RDS as a part of its platform, and supports different deployment strategies including All-at-once, rolling release, immutable, and blue green deployment.

Elastic Beanstalk allows running applications based on multiple runtimes, but I have divided them to two types as each can be deployed and debugged in a different way - containerized; which runs the Docker runtime, and uncontainerized; which uses non-Docker runtime such as php, nodejs, python, etc.

This article explains using docking runtime with elastic beanstalk and demonstrates the possible methods to use envrionment variables with the runtime.


### Types of deployment strategies
Each deployment strategy has its pros and cons, for testing and quick deployment for example:

1. All-at-once; which directly replaces the old deployment with the new one by replacing the application files inside the same instance, this creates little downtime. The advantages of this is quick deployment process, the disadvantage is it doesn't have rolling back in case of failure, which can only be updated manually.
2. Rolling deployment; This is used for loadbalanced type with multiple instances running at the time, it'll deploy the new update inside the same instances but in batches, this will create no downtime, but doesn't support rolling back either, the updated instances will require terminating if the deployment didn't meet the health checks.
3. Rolling deployment with additional batches; it acts as same as the rolling deployment, but it creates a complete new instances in batches instead of updating the same onces, it also doesn't support a rollback and requires updating the environment with a healthy update to recover from the failure.
4. Immutable, this creates a complete seperate autoscaling group with new instances, once health checks are passed, they will be attached to the original autoscaling group and the old instances will be discarded. This also works with the single instance type, and support rolling back in case of failure. The disadvantage is long process of deployment, as it takes about ten to fifteen minutes for each update. This can be reduced if 
5. Blue/Green, this keeps two replicas of environments running, when one environment is updated (green), the traffic will be shifted to it from the old one (blue) using what's called swapping. This type of deployment is safe and highly available. The disadvantage is the high cost as the user would pay twice the price for two environments.

Rolling deployments, and rolling deployments with batches are comparatively faster than immutable but don't support rolling back in case of failure, for this, immutable seems the most suitable, safe and highly available strategy while keeping the cost down, comparing to the rest of deployment strategies. 

Docs: [AWS Docs](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/using-features.deploy-existing-version.html)

### Deployment Configuration

To configure how an application should be installed, and decide what steps should be done pre-installation and post-installation inside the EC2 instance, Elastic beanstalk provides a number of features:
#### .ebextensions - Elastic Beanstalk Extensions

A hidden folder created in the source code which is used to control the installation and configuration of application's environment, such as running a set of scripts, environment variables, installing libraries, and do tweak the environment configuration before and after deploying the application. The commands are defined in *.config* execution files that can refer to other bash script files in the same folder.
#### .platfrom - Platfrom Hooks

Similar to .ebextensions, a hidden folder named *platfrom* which is created in the source code. Platfrom hooks have a similar purpose of ebextensions but use mainly to configure the elastic beanstalk environment - the instance running the depployment - rather than the deployment itself. It is used to run bash scripts before or after the build - compiling/extracting the applciation - and before or after the deployment - setting up/ running the application. 

Platform Hooks are also used to configure the deployment lifecycle - such as tracing, logs aggregation, environments properties setup inside the instance. 

#### Procfile and Buildfile

These are two files that are placed in the source code, both of these files are used to manage *compiling/building* the applciation - in case of Buildfile - and starting/running the application on runtime - in case of Profile. Each of these files can be defined by adding them in the application directory on the instance and set the commands using key:value method.

Deciding whether and when to use these features depends on realising the required phase to run your script within the order of running the extenions:

![Order of running extensions](https://docs.aws.amazon.com/images/elasticbeanstalk/latest/dg/images/platforms-linux-extend-order.png)

For more details:
[AWS Doc](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/platforms-linux-extend.html)

### Infrastructure Implemented Steps

1. Create a VPC with four subnets -  two for the EC2 instances and two for RDS backend in case it's used - Internet gateway, and route table to route the subnet networks to the Internet.
2. In case RDS to be used for external sources, attach it to the public route table - which routes to the internet gateway - and use ACLs to restrict access to the RDS resource.
3. For Single-Instance type of Elastic beanstalk, a load balancer won't be used, using singleinstance type, and with immutable deplyment strategy.
4. Create an Appliation load balancer, with a listener to port 80 targeting to target group forwards to port 80 instances. If HTTPS is required, then an SSL certificate can be released from ACM and use HTTPS as a listener that will forward the traffic to the target group.
5. Create Elastic beanstalk using loadbalanced type or Single instance type, with immutable strategy, instance autoscaling.
6. For caching and SSL certificate, along with DDos protection, we may use CloudFront and connect it to the elastic beanstalk endpoint, supported with AWS Shield Standard. However, to enable stikciness, an SSL certificate is required to be installed for the application load balancer, otherwise an *AWSALBCORS* error will show up.
7. For CloudFront settings, change the `domain_name` to the `CNAME_prefix` of the used elastic beanstalk environment - by default the loadbalanced type is set - make sure the protocol used aligns with the one the load balacner is using, and make sure that the 'Origin request policy' uses AllViewer policy, setting CORS policy could be needed as well.
8. Create RDS seperately, then connect it the application using environment variables, this could be safer and can be used for multi-purposes.
9. Create S3 bucket that is used to store the application's docker-compose.yml and env files, and allow elasticbeanstalk and codebuild to use it.
10. Create ECR to push the docker image to it.
11. Create CodeBuild application with the required policies, that uses a buildspec.yml file. then use codepipeline to use the codebuild appliation while processing.
12. Once everything is configured, save the elastic beanstalk configuration for future use.

### IaC - Terraform

1. Create VPC, Securtiy groups, and subnet, IG and route tables.
2. Create RDS.
3. Create Service role to attach it with elastic beanstalk that includes the following policies:

   1. AWSElasticBeanstalkEnhancedHealth
   2. AWSElasticBeanstalkManagedUpdatesCustomerRolePolicy
   3. AmazonS3FullAccess - to allow S3 lifecycle policy configuration
   4. custom policy that allows:
      1. "ec2:DescribeNetworkAcls", "ec2:DescribeRouteTables"
      2. AllowingaccesstoECRrepositories
      3. AllowingAccessToELBResources
      4. AllowAccessToCustomS3bucketCreatedEarlier
      5. AllowSSM - to allow patch updates

4. Create EC2 Instance profile that will have a role to do the following:

   1. AWSElasticBeanstalkWebTier
   2. AWSElasticBeanstalkMulticontainerDocker
   3. AWSElasticBeanstalkWorkerTier
   4. AWSEC2RoleForCodeDeploy
   5. custom policy that allows:
      1. "ec2:DescribeNetworkAcls", "ec2:DescribeRouteTables"
      2. AllowSSM - for parameters retrieval.

5. Points 3.4.1 and 4.5.1 are required to avoid authorization errors while deployment from CICD.

6. Create terraform elastic beanstalk resource that includes the following:

   1. Elastic bean stalk application with s3 lifecycle policy.
   2. Elastic beanstalk application version: it will be linked with the elastic beanstalk applcation resource, and will assign the initial version name which will use a nodejs sample that will be stored in the s3 bucket.
   3. Elastic beanstalk enviroenmnt: here we will assign all the requirements of our elastic beanstalk application - using the keys and settings blocks.

7. S3, ECR, LoadBalancer, CodeBuild, Cloudfront resources to be created.

8. For codepipeline, create it manually as it requires OAuth authentication which is not supported by terraform API. We may create codeBuild applciation and then connect it manually with codepipeline.

### CICD

Elastic beanstalk can be integrated with CI/CD using CI tools to build and deploy the application.

#### Using CI: CodeBuild, Jenkins, Github actions, BitBucket pipelines or other third party CI tools:

To run appliactions with Docker runtime, we can do one of the following options:

**Method A**: Deploy the application source code with a dockerfile in a zip file. Elastic beanstalk will take care of building and running the image.

1. Clone the repository (checkscm)
2. Zip the source code along with its dockerfile then push it to s3 bucket.
3. Update elastic beanstalk with the new version.

**Method B**: Build a docker image, push it to ECR registry, then use docker-compose.yml of dockerrun.json file to run the image.

1. Clone the repository (checkscm)
2. In case the application requires environment variables to be inserted while compiling, then we can add an addtional step to retreive them from SSM parameters store or other resources. This can be done as the following:
   1. A custom policy allows `GetParameter`, `GetParametersByPath`, for the stored envrionment variables in SSM parameter store as a path.
   2. This policy will be attached to CodeBuild and Elastic Beanstalk roles.
   3. In the Codebuild Buildspec.yml, we'll use a bash script that will call the parameters and save them in .env file:

   ```
   while read -r name value; do export_string="${name##*/}=$value"; echo "$export_string" >> .env; done < <(aws ssm get-parameters-by-path --path "${parameter_path}" --with-decryption --query "Parameters[*].[Name,Value]" --output text)
   ```
   Where:

      **while; do; done**: This is a while loop which will run the following code:
         
      **read**: This reads the user input per line, created two variables; name and value, which are defined based on whitespaces of the output. This will store the environment varaibles as inputs to get exported in the shell.
      
      **export**: This will export the variable *export_string*, which stored `"${name##*/}=$value"`, the `##*/` removes the context upto the slash from the left of the value.
      
      **< <(...)**: `<` is an input redirection from a *file*, where `<(...)` is an execution block called process redirection which treats the output of command inside the brackets as a file that's values will be redirected to the *export* command line by line.
      
      **aws ssm**: using AWS CLI, ssm parameters were called by path with filtering name and value.
   
3. Build the Dockerfile image, tag it and push it to the ECR registry.
4. Patch Docker-Compose.yml with the new image tag.
5. Zip the docker-compose.yml and .env - in case willing to added enviroment variables on runtime - files then push them to a secured s3 bucket.
6. Create and update the elastic beanstalk version with the zip file.

*NOTE: The user signed to the AWS CLI must have the authentication to use S3, and Elastic Beanstalk, ECR, while the S3 bucket's policy and Elastic beanstalk should have the roles required to allow each other use their resources.*

##### Using CodeBuild

Give IAM role policy to CodeBuild with the following:
    1. AdministratorAccess-AWSElasticBeanstalk policy,
    2. custom policy that allows:
       1.  S3 access to bucket.
       2.  SSM parameter store - in case of available secrets and variables.
       3.  ECR registry where the docker image will be stored.
    3. codebuild's generic policy. - created by codebuild, which includes:
       1. VPC related policies.
       2. logs and reports generation policies.
       3. s3 access for codepipeline policies.


#### CodePipeline

1. Create a pipeline, choose the repository, for the building stage, choose the codebuild applciation created earlier.
2. If created with codeDeploy with elastic beanstalk, then skip the building stage and choose codedeploy with elastic beanstalk.

### Managing Environment Variables
There are two methods to call environment variables in Elastic Beanstalk for Docker runtime:
   1. Using environment properties from elastic beanstalk environment's dashboard.
   2. Using .env file along with docker-compose.yml file in a zip.
In case the application requires building with the envrionment variables existed, we can do one of the following:
* Deploying Dockerfile in Zip to elastic beanstalk:
   1. We can set limited credentials in the dockerfile as ENV, install aws cli during build step, create the .aws configurations and credentials in the build image, then call SSM parameter store and store the key=values in .env file.
   2. Build the application using the .env, then copy the neccessary files including .env in the new image.
* Deploying docker-compose.yml file:
   1. Call environment variables using SSM parameter store and store them in .env file.
   2. Let dockerfile build the image using the source code and .env files in a builder image.
   3. Copy the neccessary files including the .env file to the ECR regsitry if willing to include the .env with the base image. OR exclude the .env file from the final docker image, push it to ECR, then push a zip file includes the docker-compose.yml and .env file in a secured s3 bucket. The later option is more seucred.

### DNS setup

#### Shared load balacner
In shared load balacners, Elastic Beanstalk uses alias records to route the Application's DNS to the application load balancer, then the load balacner routes the request to the target group. 

The Application load balancer identifies the target group by setting rules - the path based rule, and the hostname rule. 

So a custom domain name should be routed to the elastic beanstalk's application DNS, not the load balancer's endpoint.

[Doc: AWS Shared Load Balancer](https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/environments-cfg-alb-shared.html) | 
[Doc: Host based routing](https://digitalcloud.training/load-balanced-architecture-with-advanced-request-routing/#:~:text=Host%2Dbased%20routing%20allows%20you,to%20as%20URL%2Dbased%20routing)

#### Dedicated load balacner

In dedicated load balancers, the load balancer is used only for a single environment, so routing a custom domain name to either of the Elastic beanstalk application's DNS or the dedicated application load balancer's endpoint isn't a problem (unless the elastic beanstalk environment is modified to a singleisntance or shared load balancer type)

#### Using Third-Party DNS Registrars

For DNS records, If an external DNS registrar is used, then ACM certificate is required, it should be added as a record in the DNS configuration of the domain, then it shall be used by cloudfront, in addition to adding the domain name Aliases in cloudfront.

Once approved, routing the domain to the cloudfront will be possible using CNAME records for the subdomain and Forward record for the host-domain that directs to the root domains.

#### Using Route53

For Route53, an alias can be created to route the custom DNS to the cloudfront endpoint that uses the elastic beanstalk environment.

### Notes & Troubleshooting

1. The application's port can be modified using a predefined AWS environment variable `PORT`.
2. For t2/3.micro instance, running npm run build causes memory full, so create a swap script and run it by .ebextensions
2. If npm requires permission while building, use .npmrc file with `unsafe-perm=true`.
3. Always trace the problems using the logs in /var/log directory.
4. For Immutable deployment logs, check elastic beanstalk's bucket's logs, they persist for one hour after each event.
5. Use ebextensions to run npm install before depoyment in elastic beanstalk to solve error `sh: not found`.
6. Save configuration when setting the elastic beanstalk environment to use it later as endpoint restore when required.
7. Enabling Stickiness in the load balancer requires an SSL certitificate particularily for the ALB, this can be created using ACM.
