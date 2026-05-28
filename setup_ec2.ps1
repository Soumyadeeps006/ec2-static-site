# PowerShell script to create an EC2 instance, configure security group, install Nginx, and deploy a static website
# Prerequisites:
#   - AWS CLI installed and configured with proper credentials (aws configure)
#   - PowerShell 5+ (comes with Windows) or PowerShell Core
#   - An existing SSH key pair file (e.g., my-key.pem) in this directory or specify a new name to create one
#   - This script uses the default VPC and subnet in the selected region

param(
    [string]$Region = "us-east-1",
    [string]$InstanceType = "t2.micro",
    [string]$AmiId = "ami-0dba2cb6798deb6d8", # Ubuntu Server 22.04 LTS (update as needed)
    [string]$KeyName = "my-ec2-key",
    [string]$SecurityGroupName = "ec2-ssh-http-sg",
    [string]$HtmlFilePath = "index.html"
)

function Ensure-KeyPair {
    Write-Host "Checking for existing key pair '$KeyName'..."
    $existing = aws ec2 describe-key-pairs --region $Region --key-names $KeyName --output json 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Key pair not found. Creating a new one..."
        $keyOut = aws ec2 create-key-pair --region $Region --key-name $KeyName --query 'KeyMaterial' --output text
        if ($LASTEXITCODE -ne 0) { Throw "Failed to create key pair" }
        $pemPath = "${KeyName}.pem"
        $keyOut | Out-File -Encoding ascii $pemPath
        # Restrict permissions
        icacls $pemPath /inheritance:r /grant:r "${env:USERNAME}:R"
        Write-Host "Key pair saved to $pemPath"
    } else {
        Write-Host "Key pair already exists. Ensure you have the .pem file locally for SSH."
    }
}

function Ensure-SecurityGroup {
    Write-Host "Creating (or retrieving) security group '$SecurityGroupName'..."
    $sg = aws ec2 describe-security-groups --region $Region --group-names $SecurityGroupName --output json 2>$null
    if ($LASTEXITCODE -ne 0) {
        $vpcId = aws ec2 describe-vpcs --region $Region --query 'Vpcs[0].VpcId' --output text
        $sgId = aws ec2 create-security-group --region $Region --group-name $SecurityGroupName --description "Allow SSH and HTTP" --vpc-id $vpcId --query 'GroupId' --output text
        Write-Host "Security group created with ID $sgId"
        # Inbound rules: SSH (22) and HTTP (80)
        aws ec2 authorize-security-group-ingress --region $Region --group-id $sgId --protocol tcp --port 22 --cidr 0.0.0.0/0
        aws ec2 authorize-security-group-ingress --region $Region --group-id $sgId --protocol tcp --port 80 --cidr 0.0.0.0/0
    } else {
        $sgId = ($sg | ConvertFrom-Json).SecurityGroups[0].GroupId
        Write-Host "Security group already exists with ID $sgId"
    }
    return $sgId
}

function Launch-Instance ($sgId) {
    Write-Host "Launching EC2 instance..."
    $instanceId = aws ec2 run-instances \
        --region $Region \
        --image-id $AmiId \
        --count 1 \
        --instance-type $InstanceType \
        --key-name $KeyName \
        --security-group-ids $sgId \
        --query 'Instances[0].InstanceId' \
        --output text
    if ($LASTEXITCODE -ne 0) { Throw "Failed to launch instance" }
    Write-Host "Instance ID: $instanceId"
    # Wait until running and get public IP
    aws ec2 wait instance-running --region $Region --instance-ids $instanceId
    $publicIp = aws ec2 describe-instances --region $Region --instance-ids $instanceId --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
    Write-Host "Public IP: $publicIp"
    return @{Id=$instanceId; Ip=$publicIp}
}

function Setup-WebServer ($publicIp) {
    $pemPath = "${KeyName}.pem"
    if (-Not (Test-Path $pemPath)) { Throw "SSH key file $pemPath not found" }
    Write-Host "Connecting via SSH to install Nginx and deploy site..."
    $sshCmd = "ssh -o StrictHostKeyChecking=no -i $pemPath ubuntu@$publicIp"
    # Update and install Nginx
    $installCmd = "sudo apt-get update && sudo apt-get install -y nginx"
    & $sshCmd "$installCmd"
    # Copy HTML file
    scp -o StrictHostKeyChecking=no -i $pemPath $HtmlFilePath ubuntu@$publicIp:/tmp/
    $moveCmd = "sudo mv /tmp/$(Split-Path $HtmlFilePath -Leaf) /var/www/html/index.html && sudo chown www-data:www-data /var/www/html/index.html"
    & $sshCmd "$moveCmd"
    Write-Host "Website should be reachable at http://$publicIp"
}

# Main execution flow
Ensure-KeyPair
$sgId = Ensure-SecurityGroup
$instanceInfo = Launch-Instance $sgId
Setup-WebServer $instanceInfo.Ip

Write-Host "All done!"
