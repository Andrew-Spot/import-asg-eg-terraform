terraform {
  required_providers {
    spotinst = {
      source = "spotinst/spotinst"
    }
  }
}

#### Spot Provider and Auth ####
# Used TF_VAR Env Variables
# Run these commands from your machine with the proper values to avoid exposing tokens in code
# Examples:
# export TF_VAR_spot_token=123456789
# export TF_VAR_spot_account=act-123456

provider "spotinst" {
  token   = var.spot_token
  account = var.spot_account
}

variable "spot_token" {
  type        = string
  description = "Spot Personal Access token"
  # default = 123456789 # Don't need this line if you are using env. variables
}

variable "spot_account" {
  type        = string
  description = "Spot account ID"
}

# INPUT ASG NAME HERE
variable "asg_name" {
  type = string
  description = "ASG Name"
  default = "andrew_asg"
}

#INPUT REGION HERE
variable "region" {
  type = string
  description = "Region"
  default = "us-west-2"
}

/* ##Commenting out null_resource for now and using script3.sh in place
resource "null_resource" "api_call" {
    provisioner "local-exec" {
        command = <<EOT
curl -X POST \
-H "Authorization: Bearer ${var.spot_token}" \
"https://api.spotinst.io/aws/ec2/group/autoScalingGroup/import?accountId=${var.spot_account}&autoScalingGroupName=${var.asg_name}&region=${var.region}" \
-o api_response.json

# All parameters are already configured for you
# For reference, Elastigroup name and Elastigroup ID are pulled from the API server response, then fed to the terraform import command below

export TF_VAR_elastigroup_id=`jq '.response.items[0].id' api_response.json | tr -d '""'`
export TF_VAR_elastigroup_name=`jq '.response.items[0].name' api_response.json | tr -d '""'`

cat >> main.tf << EOF

locals {
  json_data = jsondecode(file("${path.module}/api_response.json"))
  elastigroup_id = jsondecode(file("${path.module}/api_response.json")).response.items[0].id
}

resource "spotinst_elastigroup_aws" "andrew_asg" {
  name = local.json_data.response.items[0].name
  description = local.json_data.response.items[0].description
  spot_percentage = 100 # 100 by default, harcoded to this
  orientation = local.json_data.response.items[0].strategy.availabilityVsCost
  # It may be worth updating instance_types_spot and instance_types_ondemand on the first terraform apply
  # We can pass data into the null_resource, or just update here afterward
  instance_types_spot = local.json_data.response.items[0].compute.instanceTypes["spot"]
  instance_types_ondemand = local.json_data.response.items[0].compute.instanceTypes["ondemand"]
  product = local.json_data.response.items[0].compute.product
  security_groups = local.json_data.response.items[0].compute.launchSpecification["securityGroupIds"]
  fallback_to_ondemand = true # true by default, hardcoded to true
  region = local.json_data.response.items[0].region
  key_name = local.json_data.response.items[0].compute.launchSpecification.keyPair
  image_id = local.json_data.response.items[0].compute.launchSpecification.imageId
  health_check_type = local.json_data.response.items[0].compute.launchSpecification.healthCheckType
  health_check_grace_period = local.json_data.response.items[0].compute.launchSpecification.healthCheckGracePeriod
  draining_timeout = local.json_data.response.items[0].strategy.drainingTimeout

  
  network_interface { 
    device_index                       = local.json_data.response.items[0].compute.launchSpecification["networkInterfaces"][0].deviceIndex
    description                        = local.json_data.response.items[0].compute.launchSpecification["networkInterfaces"][0].description
    delete_on_termination              = false
    associate_public_ip_address        = false # follow naming convention
    associate_ipv6_address              = local.json_data.response.items[0].compute.launchSpecification["networkInterfaces"][0].associateIpv6Address
  }
  
  tags {
    key = local.json_data.response.items[0].compute.launchSpecification["tags"][0].tagKey
    value = local.json_data.response.items[0].compute.launchSpecification["tags"][0].tagValue
  }
}
EOF
    echo "Import command: terraform import spotinst_elastigroup_aws.$TF_VAR_elastigroup_name $TF_VAR_elastigroup_id"
        EOT
    }
}
*/