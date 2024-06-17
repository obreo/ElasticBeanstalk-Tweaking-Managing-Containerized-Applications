# Cloud Settings
variable "account_id" {
  description = "aws account id"
  type        = string
  sensitive   = true
  #default     = ""
}
variable "region" {
  description = "aws region"
  type        = string
  default     = ""
}

# Application settings
variable "name" {
  description = "application name"
  type        = string
  default     = ""
}
variable "instance_type" {
  description = "launch configuration instance type"
  type        = string
  default     = "t3.micro"
}
variable "ssh-key" {
  description = "public ssh key for instance access"
  type        = string
  default     = ""
}


# RDS
variable "rds_port" {
  description = "If any, keep this 0 if no resource to be created."
  type        = number
  default     = 0
}
variable "username" {
  description = "database username"
  type        = string
  sensitive   = true
  default     = ""
}
variable "password" {
  description = "database password"
  type        = string
  sensitive   = true
  default     = ""
}

# SSM Parameters
variable "parameter_path" {
  description = "ssm parameters path for secrets and environment variables - if any"
  type        = string
  sensitive   = false
  default     = ""
}


###############################################################################################
# environment counts:
# count = length(var.my_variable) == length("true") ? 1 : 0
# count = length(var.my_variable_a) == length("true") || length(var.my_variable_b) == length("true") ? 1 : 0
variable "Loadbalanced_resource_count" {
  description = "For Elastic Beanstalk Loadbalanced type. Determine wether to create relative resources or not"
  type        = string
  default     = "false" # Changing this value from true will cause removal of loadbalanced environment resources
}
variable "singleinstance_resource_count" {
  description = "For Elastic Beanstalk SingleInstance type. Determine wether to create relative resources or not"
  type        = string
  default     = "true" # Changing this value from true will cause removal of singleinstance environment resources
}
