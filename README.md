# EC2 Static Site Provisioning

This repository contains a **PowerShell script** (`setup_ec2.ps1`) that creates an Ubuntu t2.micro EC2 instance on AWS, installs Nginx, and deploys a tiny static website (`index.html`).  The goal is to give you a hands‑on introduction to:

- AWS account and IAM basics
- Launching an EC2 instance with a security group
- Connecting via SSH and installing software
- Serving a static site from a cloud server

## Prerequisites

- An AWS account with access keys configured (`aws configure`).
- AWS CLI v2 installed on Windows.
- PowerShell 5+ (built‑in to Windows) or PowerShell Core.
- (Optional) A custom `index.html` you’d like to serve.

## Quick start

```powershell
# Open PowerShell in the repository folder
cd C:\Users\deeps\.gemini\antigravity\scratch

# Run the provisioning script (creates key pair, security group, instance, installs Nginx, copies site)
.\setup_ec2.ps1
```

When the script finishes it prints the public IP address. Open a browser and navigate to `http://<PUBLIC_IP>` – you should see the message from `index.html`.

## Manual workflow

If you prefer to perform the steps yourself, see the **step‑by‑step guide** in `setup_ec2.ps1` comments.  The script is essentially a series of AWS CLI calls wrapped in PowerShell functions.

## Customising the site

Edit `index.html` before running the script, or re‑run the `Setup-WebServer` function (or manually `scp` a new file) to replace the page after the instance is up.

## Stretch goals (optional)

- Add a custom domain via Route 53.
- Secure the site with Let’s Encrypt certificates.
- Build a CI/CD pipeline with CodePipeline.
- Convert the provisioning logic to CloudFormation or Terraform for declarative infrastructure.

## Clean‑up

When you are done, terminate the EC2 instance to avoid charges:

```powershell
aws ec2 terminate-instances --instance-ids <INSTANCE_ID>
```

Delete the security group and key pair if you no longer need them.

---

Happy cloud‑building!
