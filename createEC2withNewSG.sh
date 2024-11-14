#!/bin/bash

# Define AWS CLI profile and region
profileName="default"
region="cn-northwest-1"

# Define EC2 configuration
imageid="ami-05b6f36b0f618c069"
keyname="YourKeyPem"
subid="subnet-0a927bxxxxxx"
vpcid="vpc-0fd888xxxxx"
instanceType="t3.nano"
volumeSizeRoot=10
volumeSizeData1=20
volumeSizeData2=30

# Parse tags argument passed to script
tags="${1:-NEWEC2}"
groupName="new-sec-group-$tags"

# Check if security group already exists
echo "Checking if security group $groupName exists..."
secgroupid=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values="$groupName" Name=vpc-id,Values="$vpcid" \
  --query "SecurityGroups[0].GroupId" \
  --output text \
  --profile "$profileName" \
  --region "$region")

if [ "$secgroupid" != "None" ]; then
  echo "Security group $groupName already exists with ID: $secgroupid"
else
  # Create security group
  echo "Creating security group $groupName..."
  secgroupid=$(aws ec2 create-security-group \
    --group-name "$groupName" \
    --description "Security group for new EC2 instance with ports 22, 80, and 443 open" \
    --vpc-id "$vpcid" \
    --query 'GroupId' \
    --output text \
    --profile "$profileName" \
    --region "$region")

  echo "Security Group ID: $secgroupid"

  # Add inbound rules to security group for SSH (22), HTTP (80), and HTTPS (443)
  echo "Adding inbound rules to security group..."
  aws ec2 authorize-security-group-ingress \
    --group-id "$secgroupid" \
    --protocol tcp --port 22 --cidr 0.0.0.0/0 \
    --profile "$profileName" \
    --region "$region"

  aws ec2 authorize-security-group-ingress \
    --group-id "$secgroupid" \
    --protocol tcp --port 80 --cidr 0.0.0.0/0 \
    --profile "$profileName" \
    --region "$region"

  aws ec2 authorize-security-group-ingress \
    --group-id "$secgroupid" \
    --protocol tcp --port 443 --cidr 0.0.0.0/0 \
    --profile "$profileName" \
    --region "$region"
fi

# Define user data (unchanged)
read -r -d '' userData <<'EOF'
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "[START] User Data Script Execution - $(date)"

# Update the system
dnf update -y
dnf install -y wget curl

# Install Apache HTTPD
dnf install -y httpd.x86_64

# Start and enable Apache HTTPD service
systemctl start httpd.service
systemctl enable httpd.service

# Create a simple index page with hostname
echo "Hello World from $(hostname -f)" > /var/www/html/index.html

# Wait for devices to be available
echo "Waiting for devices to become available..."
while [ ! -e /dev/nvme1n1 ] || [ ! -e /dev/nvme2n1 ]; do
    sleep 5
    echo "Still waiting for devices..."
done

# Format and mount additional volumes
for device in /dev/nvme1n1 /dev/nvme2n1; do
    mount_point="/data${device: -3:1}"

    echo "Processing device: $device with mount point: $mount_point"

    if ! blkid $device; then
        echo "Formatting $device with XFS"
        mkfs.xfs $device
    fi

    mkdir -p $mount_point
    mount $device $mount_point

    if ! grep -q "$device" /etc/fstab; then
        echo "$device $mount_point xfs defaults,nofail 0 0" >> /etc/fstab
    fi
done

echo "[COMPLETE] User Data Script Execution - $(date)"
EOF

# Block device mapping configuration
blockDeviceMappings="[{
  \"DeviceName\":\"/dev/xvda\",
  \"Ebs\":{
    \"VolumeType\":\"gp3\",
    \"VolumeSize\":$volumeSizeRoot,
    \"DeleteOnTermination\":true
  }
}, {
  \"DeviceName\":\"/dev/sdb\",
  \"Ebs\":{
    \"VolumeType\":\"gp3\",
    \"VolumeSize\":$volumeSizeData1,
    \"DeleteOnTermination\":true
  }
}, {
  \"DeviceName\":\"/dev/sdc\",
  \"Ebs\":{
    \"VolumeType\":\"gp3\",
    \"VolumeSize\":$volumeSizeData2,
    \"DeleteOnTermination\":true
  }
}]"

# Create EC2 instance (unchanged)
echo "Creating EC2 instance..."
instanceId=$(aws ec2 run-instances \
  --image-id "$imageid" \
  --instance-type "$instanceType" \
  --key-name "$keyname" \
  --user-data "$userData" \
  --security-group-ids "$secgroupid" \
  --subnet-id "$subid" \
  --associate-public-ip-address \
  --block-device-mappings "$blockDeviceMappings" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$tags}]" \
  --query "Instances[0].InstanceId" \
  --output text \
  --profile "$profileName" \
  --region "$region")

echo "Instance ID: $instanceId"

# Wait for instance to be running (unchanged)
echo "Waiting for instance to be running..."
aws ec2 wait instance-running \
  --instance-ids "$instanceId" \
  --profile "$profileName" \
  --region "$region"

# Describe instance (unchanged)
echo "Instance details:"
aws ec2 describe-instances \
  --instance-ids "$instanceId" \
  --query "Reservations[].Instances[].{InstanceId:InstanceId,LaunchTime:LaunchTime,PublicIP:PublicIpAddress,Name:Tags[?Key=='Name']|[0].Value,Status:State.Name}" \
  --profile "$profileName" \
  --region "$region" \
  --output table

