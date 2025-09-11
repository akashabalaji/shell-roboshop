#!/bin/bash
# This script creates EC2 instances for the Roboshop application
# and updates Route 53 DNS records accordingly.

set -euo pipefail

# Configuration
AMI_ID="ami-09c813fb71547fc4f"
SG_ID="sg-06afdd0919175d247"   # Replace with your Security Group ID
ZONE_ID="Z00173281MRJFFPM52LSY" # Replace with your Route 53 Zone ID
DOMAIN_NAME="akashabalaji.site" # Replace with your domain
LOG_FILE="roboshop-deploy-$(date +%F-%H%M%S).log"

# Redirect all stdout/stderr to log file AND console
exec > >(tee -a "$LOG_FILE") 2>&1

# Default instance list (if no args are passed)
DEFAULT_INSTANCES=("mongodb" "redis" "mysql" "rabbitmq" "catalogue" "user" "cart" "shipping" "payment" "dispatch" "frontend")

# Use command line args if provided, else fall back to default
INSTANCES=("$@")
if [ ${#INSTANCES[@]} -eq 0 ]; then
  INSTANCES=("${DEFAULT_INSTANCES[@]}")
fi

echo "============================================="
echo " Roboshop Deployment Started: $(date) "
echo " Log file: $LOG_FILE "
echo "============================================="

for instance in "${INSTANCES[@]}"; do
  echo "Launching EC2 instance: $instance"

  # Create EC2 instance
  INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t3.micro \
    --security-group-ids "$SG_ID" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$instance}]" \
    --query "Instances[0].InstanceId" \
    --output text)

  echo "Instance created with ID: $INSTANCE_ID"

  # Get IP (private for app services, public for frontend)
  if [ "$instance" != "frontend" ]; then
    IP=$(aws ec2 describe-instances \
      --instance-ids "$INSTANCE_ID" \
      --query "Reservations[0].Instances[0].PrivateIpAddress" \
      --output text)
    RECORD_NAME="$instance.$DOMAIN_NAME"
  else
    IP=$(aws ec2 describe-instances \
      --instance-ids "$INSTANCE_ID" \
      --query "Reservations[0].Instances[0].PublicIpAddress" \
      --output text)
    RECORD_NAME="$DOMAIN_NAME"
  fi

  echo "$instance IP: $IP"

  # Create/Update DNS record in Route 53
  aws route53 change-resource-record-sets \
    --hosted-zone-id "$ZONE_ID" \
    --change-batch "{
      \"Comment\": \"Creating or Updating record for $instance\",
      \"Changes\": [{
        \"Action\": \"UPSERT\",
        \"ResourceRecordSet\": {
          \"Name\": \"$RECORD_NAME\",
          \"Type\": \"A\",
          \"TTL\": 1,
          \"ResourceRecords\": [{ \"Value\": \"$IP\" }]
        }
      }]
    }"

  echo "DNS record updated: $RECORD_NAME -> $IP"
  echo "---------------------------------------------"
done

echo "Deployment finished successfully at $(date)"
echo "Log saved in: $LOG_FILE"
