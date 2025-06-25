#!/bin/bash
# This script creates EC2 instances for a Roboshop application and updates Route 53 DNS records.

AMI_ID="ami-09c813fb71547fc4f"
SG_ID="sg-0afb0733333250162" # replace with your SG ID
INSTANCES=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend")
ZONE_ID="Z08186589VBOFNQARTE2" # replace with your ZONE ID
DOMAIN_NAME="akashabalaji.site" # replace with your domain

#for instance in ${INSTANCES[@]}
for instance in $@ # Use command line arguments to specify instances
do
    INSTANCE_ID=$(aws ec2 run-instances --image-id ami-09c813fb71547fc4f --instance-type t3.micro --security-group-ids sg-0afb0733333250162 --tag-specifications "ResourceType=instance,Tags=[{Key=Name, Value=$instance}]" --query "Instances[0].InstanceId" --output text) # replace with your AMI ID and SG ID
    if [ $instance != "frontend" ] # If the instance is not frontend, use private IP
    then
        IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PrivateIpAddress" --output text) # Get the private IP address
        # Use the instance name as the record name, appending the domain name
        
        RECORD_NAME="$instance.$DOMAIN_NAME" # Append the instance name to the domain name
    else
        IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PublicIpAddress" --output text) # Get the public IP address for frontend
        # Use the domain name as the record name for frontend
        RECORD_NAME="$DOMAIN_NAME" # Use the domain name as the record name for frontend
    fi
    echo "$instance IP address: $IP" # Print the IP address of the instance
   
   # Create or update the Route 53 record set
    aws route53 change-resource-record-sets \
    --hosted-zone-id $ZONE_ID \
    --change-batch '
    {
        "Comment": "Creating or Updating a record set for cognito endpoint"
        ,"Changes": [{
        "Action"              : "UPSERT"
        ,"ResourceRecordSet"  : {
            "Name"              : "'$RECORD_NAME'"
            ,"Type"             : "A"
            ,"TTL"              : 1
            ,"ResourceRecords"  : [{
                "Value"         : "'$IP'"
            }]
        }
        }]
    }'
done