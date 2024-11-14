#!/bin/bash

# Define AWS CLI profile and region
profileName="default"
region="cn-northwest-1"

# Define EC2 configuration
imageid="ami-05b6f36b0f618c069"
keyname="YourKeyPem"
secgroupid="sg-05fb0b9exxxxxxx"
subid="subnet-0a927bxxxxxx"
instanceType="t3.nano"
volumeSizeRoot=10
volumeSizeData1=20
volumeSizeData2=30

# Parse tags argument passed to script
tags="${1:-NEWEC2}"

# Define user data (note the removal of space after userData and proper EOF formatting)
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
    
    # Create filesystem only if not already formatted
    if ! blkid $device; then
        echo "Formatting $device with XFS"
        mkfs.xfs $device
    fi
    
    # Create mount point and mount device
    mkdir -p $mount_point
    mount $device $mount_point
    
    # Add to fstab if not already present
    if ! grep -q "$device" /etc/fstab; then
        echo "$device $mount_point xfs defaults,nofail 0 0" >> /etc/fstab
    fi
done

echo "[COMPLETE] User Data Script Execution - $(date)"
EOF

# Base64 encode the user data (using printf to avoid newline issues)
#encodedUserData=$(printf '%s' "$userData" | base64 -w 0)

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

# Create EC2 instance
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

# Wait for instance to be running
echo "Waiting for instance to be running..."
aws ec2 wait instance-running \
  --instance-ids "$instanceId" \
  --profile "$profileName" \
  --region "$region"

# Describe instance
echo "Instance details:"
aws ec2 describe-instances \
  --instance-ids "$instanceId" \
  --query "Reservations[].Instances[].{InstanceId:InstanceId,LaunchTime:LaunchTime,PublicIP:PublicIpAddress,Name:Tags[?Key=='Name']|[0].Value,Status:State.Name}" \
  --profile "$profileName" \
  --region "$region" \
  --output table

