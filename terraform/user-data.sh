#!/bin/bash
# EKS Node Security Hardening Script

# Variables passed from Terraform
CLUSTER_NAME="${cluster_name}"

# Enable CloudWatch agent for enhanced monitoring
yum update -y
yum install -y amazon-cloudwatch-agent

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/messages",
                        "log_group_name": "/aws/ec2/$CLUSTER_NAME/var/log/messages",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/var/log/secure",
                        "log_group_name": "/aws/ec2/$CLUSTER_NAME/var/log/secure",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    },
    "metrics": {
        "namespace": "EKS/Security/$CLUSTER_NAME",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Security hardening
# Disable unused services
systemctl disable rpcbind
systemctl stop rpcbind

# Configure kernel parameters for security
cat >> /etc/sysctl.conf << EOF
# Network security
net.ipv4.ip_forward = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Kernel security
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 1
EOF

sysctl -p

# Configure fail2ban for SSH protection
yum install -y epel-release
yum install -y fail2ban

cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[ssh]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/secure
maxretry = 3
bantime = 3600
EOF

systemctl enable fail2ban
systemctl start fail2ban

# Install and configure auditd for security monitoring
yum install -y audit
systemctl enable auditd
systemctl start auditd

# Add audit rules
cat >> /etc/audit/rules.d/audit.rules << EOF
# Monitor file system changes
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k identity

# Monitor network changes
-w /etc/hosts -p wa -k network
-w /etc/network/ -p wa -k network

# Monitor Docker/containerd
-w /var/lib/docker/ -p wa -k docker
-w /etc/docker/ -p wa -k docker

# Monitor Kubernetes
-w /etc/kubernetes/ -p wa -k kubernetes
-w /var/lib/kubelet/ -p wa -k kubernetes
EOF

# Restart auditd to apply rules
service auditd restart

# Configure log rotation for audit logs
cat > /etc/logrotate.d/audit << EOF
/var/log/audit/audit.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0600 root root
    postrotate
        /sbin/service auditd restart > /dev/null 2>&1 || true
    endscript
}
EOF

# Install SSM agent for secure access
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Install security monitoring tools
yum install -y htop iotop nethogs

# Set secure file permissions
chmod 644 /etc/passwd
chmod 644 /etc/group
chmod 000 /etc/shadow
chmod 440 /etc/sudoers

echo "Security hardening completed for EKS node in cluster: $CLUSTER_NAME"
