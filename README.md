# EC2 Shell Launcher

**EC2 Shell Launcher** is a shell-based automation tool for launching and configuring AWS EC2 instances. This repository provides scripts for creating and managing EC2 instances, complete with user data initialization, security group setup, and volume configuration. Ideal for DevOps engineers, developers, and anyone looking to streamline AWS EC2 provisioning directly from the command line.

## Features

- **Automated Security Group Creation**  
  Automatically creates a security group with configurable inbound rules for SSH (22), HTTP (80), and HTTPS (443) access.

- **User Data Initialization**  
  Custom user data scripts install Apache, configure the server, and mount additional EBS volumes on instance startup.

- **Flexible Block Device Mapping**  
  Define and mount additional storage volumes on the EC2 instance with automatic formatting.

## Prerequisites

- AWS CLI installed and configured
- AWS IAM role with permissions to manage EC2 instances
- Git installed locally
- A GitHub token for authentication

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/<your-username>/ec2-shell-launcher.git
   cd ec2-shell-launcher

2. Update the script variables in ec2-launch.sh to match your AWS environment:

- `profileName` - AWS CLI profile to use.
- `region` - AWS region to deploy in.
- `imageid` - AMI ID for the EC2 instance.
- `vpcid`, `subid`, and `keyname` - Your VPC, Subnet ID, and key pair name.

3. Run the main launch script:
   ```bash
   ./ec2-launch.sh

## Usage
1. Run the shell script:
   ```bash
   ./ec2-launch.sh [instance-name]

Replace `[instance-name]` with a custom tag for the EC2 instance (default: NEWEC2).

2. The script will:

  - Check if a security group with the specified name already exists.
  - If not, create the security group and add inbound rules for ports 22, 80, and 443.
  - Launch an EC2 instance with the specified configuration and attach storage volumes.

3. The script provides details of the EC2 instance, including the public IP, instance ID, and launch time.

## Example
```bash
# Launch an EC2 instance with a custom tag
./ec2-launch.sh MyEC2Instance
```

## Customizing User Data
The `userData` section of the script allows you to customize initialization, such as software installation and configuration tasks. By default, it:

  - Installs Apache HTTP Server
  - Starts the Apache service and enables it on boot
  - Creates a simple HTML page to test the web server

## Security

  - Ensure your AWS credentials are secured and never committed to the repository.
  - Use GitHub token authentication when pushing changes.

## License

This project is licensed under the MIT License.

