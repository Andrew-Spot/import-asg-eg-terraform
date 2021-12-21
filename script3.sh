#!/bin/bash
ASG_NAME="andrew_asg"
REGION="us-west-2"

# Use locals if not using environmental variables, e.g.
# SPOTINST_ACCOUNT=""
# SPOTINST_TOKEN=""

curl -X POST \
-H "Authorization: Bearer ${SPOTINST_TOKEN}" \
"https://api.spotinst.io/aws/ec2/group/autoScalingGroup/import?accountId=${SPOTINST_ACCOUNT}&autoScalingGroupName=${ASG_NAME}&region=${REGION}" \
-o api_response.json

# All parameters are already configured for you
# For reference, Elastigroup name and Elastigroup ID are pulled from the API server response, then fed to the terraform import command below

ELASTIGROUP_NAME=`jq '.response.items[0].name' api_response.json | tr -d '""'`
ELASTIGROUP_ID=`jq '.response.items[0].id' api_response.json | tr -d '""'`

# Script to create terraform resource
# Must create terraform resource before terraform import
# Script leverages json file output from API call above
# Future update will use API server response directly for all args

cat >> main.tf << EOF

locals {
  json_data = jsondecode(file("${path.module}/api_response.json"))
  elastigroup_id = jsondecode(file("${path.module}/api_response.json")).response.items[0].id
  elastigroup_name = jsondecode(file("${path.module}/api_response.json")).response.items[0].name
}

resource "spotinst_elastigroup_aws" "andrew_asg" {
  name = local.json_data.response.items[0].name
  description = local.json_data.response.items[0].description
  #monitoring = false #local.json_data.response.items[0].compute.launchSpecification.healthCheckType
  spot_percentage = 100 # This value can be hardcoded. This is a Spot feature, not imported from ASG. 100 by default
  orientation = "availabilityOriented" # could likely hardcode this to "balanced"
  # It may be worth updating instance_types_spot and instance_types_ondemand on the first terraform apply
  # We can pass data into the script, or just update here afterward
  # * Verifying the source of these
  instance_types_spot = local.json_data.response.items[0].compute.instanceTypes["spot"]
  instance_types_ondemand = local.json_data.response.items[0].compute.instanceTypes["ondemand"]
  product = local.json_data.response.items[0].compute.product
  security_groups = local.json_data.response.items[0].compute.launchSpecification["securityGroupIds"] # need to test w/ multiple security groups, should be fine
  fallback_to_ondemand = true # Fine to go ahead and hardcode this true; will be true by default
  #subnet_ids = [local.json_data.response.items[0].compute.availabilityZones[0].subnetIds,local.json_data.response.items[0].compute.availabilityZones[1].subnetIds]
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
    #### Terraform command to import state from existing Elastigroup (that was created by Import ASG call)
    sleep 5
    terraform import spotinst_elastigroup_aws.${ELASTIGROUP_NAME} ${ELASTIGROUP_ID}

#### How do I validate this worked? ####
# Check for "Import Successful!" message in terminal
# Verify terraform.tfstate file was created and/or updated

# Run Terraform Plan next, followed by Terraform Apply when ready
# In main.tf, there is already a resource configuration set with the API server response
# Please see main.tf for more details


#### Things to consider: ####

# You can review the API response in api_response.json (these are now your Elastigroup configurations)
# In general, most Elastigroup configurations can remain very similar to your ASG, which is why this API call is so effective
# API Call Documentation (for reference): https://docs.spot.io/api/#operation/elastigroupAwsImportAsg
 
# Although the API call requires minimial configuration (and imports configuration from your ASGs);
# Keep in mind that you may want to configure additional parameters in your Elastigroup, such as spot instance types, etc.
# If so, I can add code to pass in a data object into the API call above
# OR we can simply update the configuration in Terraform soon thereafter. This may be easier.