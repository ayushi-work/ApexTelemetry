# ApexTelemetry — HA Demo Guide

## Overview

ApexTelemetry is a high-availability F1 telemetry demonstration system.

The demo shows:

- Live F1-style telemetry generation
- FastAPI backend
- React/Vite live dashboard
- Application Load Balancer (ALB)
- Two EC2 application instances in different Availability Zones
- Shared ElastiCache Redis for the latest telemetry
- Terraform infrastructure as code
- GitHub Actions CI/CD using AWS Systems Manager (SSM)

### Architecture

```text
                    AWS
                     │
                  ┌──▼──┐
                  │ ALB │
                  └──┬──┘
                     │
            ┌────────┴────────┐
            ▼                 ▼
         EC2-A              EC2-B
      ap-south-1a         ap-south-1b
            │                 │
            └────────┬────────┘
                     ▼
               ElastiCache
                  Redis
                     │
                     ▼
              Live Dashboard
```

The architecture eliminates the application compute layer as a single point of failure by providing multi-AZ redundancy.

> **Important:** The current demonstration uses a single Redis node. Therefore, the application compute layer is highly available, but Redis remains a potential single point of failure.

---

# 1. Start the Demo

## Terminal 1 — Simulator

```bash
cd ~/college/apex-telemetry/app/simulator
source .venv/bin/activate
BACKEND_URL="http://apex-telemetry-alb-72135987.ap-south-1.elb.amazonaws.com" python3 simulator.py
```

Expected output:

```text
[SIMULATOR] Lap 1 | 285 km/h | RPM 10342 | Backend EC2-A
```

or:

```text
[SIMULATOR] Lap 1 | 285 km/h | RPM 10342 | Backend EC2-B
```

Leave this terminal running.

The simulator sends telemetry to the AWS Application Load Balancer, not to the local FastAPI server.

---

# 2. Start the Dashboard

## Terminal 2 — React/Vite

Open a new terminal:

```bash
cd ~/college/apex-telemetry/app/frontend
```

Start the dashboard:

```bash
VITE_WS_URL="ws://apex-telemetry-alb-72135987.ap-south-1.elb.amazonaws.com/ws" npm run dev
```

Open:

```text
http://localhost:5173
```

The dashboard should show:

- LIVE status
- Processing EC2 instance
- Speed
- RPM
- Gear
- Lap
- Throttle
- Brake
- Fuel
- Tyre condition

---

# 3. Explain the AWS Architecture

Open the AWS Console and show:

**EC2 → Instances**

There should be two application instances:

```text
EC2-A
EC2-B
```

They are deployed in different Availability Zones:

```text
EC2-A → ap-south-1a
EC2-B → ap-south-1b
```

Then show:

**EC2 → Target Groups → Targets**

Both instances should normally show:

```text
Healthy
Healthy
```

Explain:

> "The Application Load Balancer distributes incoming requests between the two EC2 instances and uses health checks to determine which targets are available."

---

# 4. Live Telemetry Flow

Point to the simulator and dashboard.

Explain:

> "The simulator continuously generates F1 telemetry such as speed, RPM, gear, throttle, brake, fuel and tyre condition."

> "The simulator sends the telemetry to the Application Load Balancer. The ALB forwards the request to one of the healthy EC2 instances."

> "The FastAPI backend stores the latest telemetry in shared Redis."

> "The React dashboard maintains a WebSocket connection to the ALB and receives the latest telemetry through the backend."

The live flow is:

```text
Simulator
    ↓
Application Load Balancer
    ↓
EC2-A / EC2-B
    ↓
Redis
    ↓
WebSocket
    ↓
React Dashboard
```

---

# 5. High Availability Failure Demo

This is the main demonstration.

## Before the failure

Make sure:

- Simulator is running
- Dashboard is LIVE
- Both ALB targets are healthy

Note which EC2 instance is currently processing telemetry.

For example:

```text
Processing Instance: EC2-A
```

## Simulate a failure

Open:

**AWS Console → EC2 → Instances**

Terminate one application instance.

For example:

```text
EC2-A
```

Do not terminate both instances.

Explain:

> "I am now simulating a failure of one application instance."

Wait approximately 20–30 seconds for the ALB health checks to detect the failed target.

The Target Group should eventually show:

```text
EC2-A → Unhealthy
EC2-B → Healthy
```

The exact detection time can vary.

## Show the dashboard

The dashboard should continue receiving telemetry through the remaining healthy instance.

If the dashboard now shows:

```text
Processing Instance: EC2-B
```

say:

> "The ALB detected that EC2-A is unhealthy and stopped routing new traffic to it. EC2-B continues serving the application, so the dashboard remains operational."

### Key presentation sentence

> **"This demonstrates multi-AZ redundancy at the application compute layer."**

---

# 6. Restore the Failed Instance

After the failure demonstration, restore the infrastructure before finishing the demo.

From the Terraform directory:

```bash
cd ~/college/apex-telemetry/terraform
terraform apply
```

Confirm with:

```text
yes
```

Wait for the replacement instance to initialize.

Then check the ALB Target Group and make sure both targets are healthy again.

Do not leave an EC2 instance terminated after the demonstration.

---

# 7. GitHub Actions CI/CD Demo

Open:

**GitHub → ApexTelemetry → Actions**

Open the:

```text
Deploy ApexTelemetry
```

workflow.

A successful deployment should show:

```text
✓ Checkout
✓ Configure AWS credentials
✓ Deploy to EC2-A
✓ Wait for EC2-A
✓ Deploy to EC2-B
✓ Deployment complete
```

Explain:

> "GitHub Actions automates deployment whenever changes are pushed to the main branch."

> "The workflow authenticates with AWS and uses AWS Systems Manager to execute the deployment commands on the EC2 instances."

> "This avoids manually SSHing into the servers for deployment."

---

# 8. CI/CD Flow

```text
Developer
    │
    ▼
GitHub Push
    │
    ▼
GitHub Actions
    │
    ▼
AWS Credentials
    │
    ▼
AWS Systems Manager
    │
    ├──────────────┐
    ▼              ▼
  EC2-A          EC2-B
    │              │
    └──────┬───────┘
           ▼
       Docker App
```

The current workflow deploys EC2-A first and then EC2-B.

---

# 9. Terraform Demo

Open:

```bash
cd ~/college/apex-telemetry/terraform
```

Run:

```bash
terraform plan
```

A clean infrastructure state should report:

```text
No changes. Your infrastructure matches the configuration.
```

Explain:

> "Terraform is used as Infrastructure as Code. The AWS networking, security groups, ALB, EC2 instances, Redis and supporting resources are defined in Terraform rather than created manually."

---

# 10. Useful Verification Commands

## Check Terraform

```bash
cd ~/college/apex-telemetry/terraform
terraform plan
```

## Check EC2 instances

```bash
aws ec2 describe-instances   --region ap-south-1   --filters "Name=tag:Project,Values=apex-telemetry"   --query "Reservations[*].Instances[*].[InstanceId,State.Name,Placement.AvailabilityZone]"   --output table
```

## Check SSM

```bash
aws ssm describe-instance-information   --region ap-south-1   --query "InstanceInformationList[*].[InstanceId,PingStatus]"   --output table
```

Both application instances should normally appear as:

```text
Online
Online
```

## Test SSM

```bash
aws ssm send-command   --region ap-south-1   --instance-ids <INSTANCE_ID>   --document-name "AWS-RunShellScript"   --parameters 'commands=["echo SSM-OK"]'
```

---

# 11. Common Questions

## Why two Availability Zones?

> "To avoid depending on a single Availability Zone. If one application instance becomes unavailable, the ALB can continue routing traffic to the healthy instance in the other Availability Zone."

## Why use an ALB?

> "The ALB distributes incoming traffic and performs health checks, so unhealthy application instances can be removed from traffic."

## Why Redis?

> "Redis provides shared storage for the latest telemetry, allowing either application instance to access the current telemetry state."

## Why Terraform?

> "Terraform makes the AWS infrastructure reproducible and manageable as code."

## Why GitHub Actions?

> "It automates the deployment process after changes are pushed to the main branch."

## Why SSM instead of SSH?

> "SSM allows GitHub Actions to execute commands on EC2 without storing SSH private keys in GitHub."

## What happens if EC2-A fails?

> "The ALB health checks detect the failure and stop routing new requests to EC2-A. EC2-B continues serving the application."

## Is the entire system fully highly available?

> "The application compute layer is highly available across two Availability Zones. The current demonstration uses a single Redis node, so Redis remains a potential single point of failure. A production implementation could use a highly available Redis configuration."

---

# 12. Final Demo Checklist

Before presenting:

- [ ] AWS infrastructure exists
- [ ] EC2-A is running
- [ ] EC2-B is running
- [ ] Both ALB targets are healthy
- [ ] Redis is available
- [ ] Simulator is running
- [ ] React dashboard is LIVE
- [ ] GitHub Actions has a successful deployment
- [ ] Terraform state is clean
- [ ] Failure demo has been rehearsed
- [ ] Failed EC2 instance has been restored after testing

---

# 13. 2–3 Minute Presentation Script

### Introduction

> "This is ApexTelemetry, a high-availability F1 telemetry demonstration system. The simulator continuously generates telemetry including speed, RPM, gear, throttle, brake, fuel and tyre condition. The objective is to demonstrate how the application can continue operating when one application instance becomes unavailable."

### Architecture

> "The simulator sends telemetry to an Application Load Balancer. The ALB distributes requests between two EC2 instances deployed across two Availability Zones. Both instances use shared Redis for the latest telemetry, and the React dashboard receives live data through WebSockets."

### Live Demo

> "Here we can see the live telemetry changing continuously. The dashboard also shows which EC2 instance is processing the request."

### Failure Test

> "I will now simulate an application instance failure."

Terminate one instance.

> "The ALB health check detects that the instance is unhealthy and removes it from the available targets."

Show the dashboard.

> "The second EC2 instance continues serving the application, so the dashboard remains operational. This demonstrates multi-AZ redundancy at the application compute layer."

### CI/CD

> "For deployment automation, GitHub Actions authenticates with AWS and uses Systems Manager to deploy the backend to the EC2 instances. This removes the need for manual SSH-based deployment."

### Conclusion

> "Overall, ApexTelemetry demonstrates Infrastructure as Code using Terraform, multi-AZ application redundancy using an ALB and EC2, shared telemetry state using Redis, WebSocket-based live monitoring, and automated deployment using GitHub Actions and AWS Systems Manager."