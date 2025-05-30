# EKS Security Pipeline

A comprehensive end-to-end EKS security pipeline demonstrating container security best practices, vulnerability scanning, network policies, and monitoring. **Perfect for maximizing your AWS credits with hands-on security learning!**

## 🎯 Project Objectives

- ✅ Deploy production-grade EKS cluster with security hardening
- ✅ Implement container image scanning with ECR
- ✅ Automated vulnerability alerting with Lambda + SNS
- ⏳ Deploy and secure vulnerable applications
- ⏳ Configure network policies with Calico
- ⏳ Set up comprehensive monitoring and alerting
- ⏳ Implement secrets management best practices

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Developer     │───▶│  ECR Registry    │───▶│  EKS Cluster    │
│   Workstation   │    │  + SCANNING ✅   │    │  + Security ✅  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │                        │
                              ▼                        ▼
                    ┌──────────────────┐    ┌─────────────────┐
                    │  Security Tools  │    │   Monitoring    │
                    │  - Falco  (⏳)   │    │  - Prometheus⏳ │
                    │  - OPA Gatekeeper│    │  - Grafana  ⏳  │
                    └──────────────────┘    └─────────────────┘
```

## 💰 Cost Breakdown (Expected: $300-400/day)

| Component | Hourly Cost | Daily Cost |
|-----------|-------------|------------|
| EKS Control Plane | $0.10 | $2.40 |
| Worker Nodes (3x m5.large) | $0.30 | $7.20 |
| NAT Gateways (3x) | $0.135 | $3.24 |
| Load Balancers | $0.025 each | $0.60+ |
| ECR Storage | $0.10/GB/month | ~$0.10 |
| Data Transfer | Variable | $5-15 |
| **TOTAL ESTIMATE** | **~$15-20/hour** | **$360-480/day** |

## 🚀 Quick Start (5 minutes to deployment!)

### Step 1: Clone and Setup
```bash
git clone https://github.com/sivolko/eks-security-pipeline.git
cd eks-security-pipeline
chmod +x setup.sh && ./setup.sh
```

### Step 2: Configure AWS Credentials
```bash
aws configure
# Enter your AWS credentials
```

### Step 3: Customize Configuration (Optional)
```bash
# Edit terraform/terraform.tfvars with your preferences
# Default settings work fine for testing!
```

### Step 4: Deploy Everything
```bash
./scripts/deploy.sh
```

### Step 5: Verify Deployment
```bash
kubectl get nodes
kubectl get pods -A
```

## 📁 Current Project Structure

```
├── terraform/                  ✅ Complete Infrastructure as Code
│   ├── main.tf                ✅ Provider configuration
│   ├── vpc.tf                 ✅ Secure networking with flow logs
│   ├── eks.tf                 ✅ Hardened EKS cluster
│   ├── ecr.tf                 ✅ Container registry with scanning
│   ├── user-data.sh           ✅ Node security hardening
│   ├── scan-processor.py      ✅ Vulnerability alert processing
│   └── outputs.tf             ✅ Comprehensive deployment info
├── scripts/                   ✅ Automated deployment scripts
│   ├── deploy.sh              ✅ One-click deployment
│   └── cleanup.sh             ✅ Safe resource cleanup
├── k8s-manifests/             ⏳ Coming next (vulnerable apps)
├── security-policies/         ⏳ Coming next (network policies)
├── monitoring/                ⏳ Coming next (Prometheus/Grafana)
└── docker/                    ⏳ Coming next (sample containers)
```

## 🛡️ Security Features Implemented

### ✅ Infrastructure Security
- **VPC with Flow Logs**: Complete network monitoring
- **Private Subnets**: Worker nodes in private networks
- **Security Groups**: Restrictive ingress/egress rules
- **KMS Encryption**: EKS secrets and ECR images encrypted
- **Node Hardening**: Custom user data with security configs
- **IAM Roles**: Least-privilege access with IRSA

### ✅ Container Security
- **ECR Vulnerability Scanning**: Automatic on push
- **Image Lifecycle Policies**: Cost optimization
- **Scan Result Processing**: Lambda-powered alerting
- **SNS Notifications**: Real-time security alerts
- **Encrypted Storage**: All images encrypted at rest

### ⏳ Coming Next (Phase 2)
- **Network Policies**: Calico implementation
- **Pod Security Standards**: Kubernetes native security
- **Admission Controllers**: OPA Gatekeeper policies
- **Runtime Security**: Falco monitoring
- **Secret Management**: External Secrets Operator

## 🔧 What You'll Learn

1. **EKS Architecture**: Production-grade cluster setup
2. **Container Security**: Image scanning and vulnerability management
3. **Network Security**: VPC design and security groups
4. **Automation**: Infrastructure as Code with Terraform
5. **Monitoring**: CloudWatch integration and alerting
6. **Cost Management**: Resource optimization strategies
7. **Security Best Practices**: Defense in depth implementation

## 📊 Monitoring & Alerting

The pipeline includes comprehensive monitoring:

- **EKS Control Plane Logs**: API, audit, authenticator logs
- **Node-level Monitoring**: CloudWatch agent with custom metrics
- **VPC Flow Logs**: Network traffic analysis
- **Security Alerts**: Automated vulnerability notifications
- **Cost Tracking**: Resource tagging for cost allocation

## 🧹 Cleanup (IMPORTANT!)

When you're done exploring:

```bash
./scripts/cleanup.sh
```

This will safely destroy all resources and help you verify nothing is left running.

## 🎓 Next Steps After Deployment

1. **Explore the cluster**: `kubectl get all -A`
2. **Check ECR repositories**: Build and push a test image
3. **Monitor costs**: Check AWS Cost Explorer
4. **Security testing**: Deploy vulnerable applications (Phase 2)
5. **Learn from logs**: Explore CloudWatch logs
6. **Experiment**: Try different configurations

## 🆘 Troubleshooting

**Deployment fails?**
- Check AWS credentials: `aws sts get-caller-identity`
- Verify region availability: Some regions may not have EKS
- Check service limits: Especially VPC limits

**High costs?**
- Run cleanup script immediately: `./scripts/cleanup.sh`
- Check for orphaned load balancers in EC2 console
- Verify all resources are terminated

**Can't connect to cluster?**
- Update kubeconfig: `aws eks update-kubeconfig --region us-west-2 --name eks-security-cluster`
- Check security groups: Ensure your IP is allowed

## 📚 Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)
- [Container Security](https://sysdig.com/learn-cloud-native/kubernetes-security/kubernetes-security-101/)

---

**⚡ Ready to maximize your AWS credits with hands-on security learning?**

```bash
git clone https://github.com/sivolko/eks-security-pipeline.git
cd eks-security-pipeline && ./setup.sh && ./scripts/deploy.sh
```

*Built for rapid learning and practical experience with AWS security and architecture* 🛡️
