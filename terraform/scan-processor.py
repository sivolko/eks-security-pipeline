import json
import boto3
import os
import logging
from datetime import datetime

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
ecr_client = boto3.client('ecr')
sns_client = boto3.client('sns')

def handler(event, context):
    """
    Process ECR scan results and send alerts for high/critical vulnerabilities
    """
    try:
        logger.info(f"Processing ECR scan event: {json.dumps(event)}")
        
        # Extract event details
        detail = event.get('detail', {})
        repository_name = detail.get('repository-name')
        image_tag = detail.get('image-tags', ['latest'])[0] if detail.get('image-tags') else 'latest'
        scan_status = detail.get('scan-status')
        
        if scan_status != 'COMPLETE':
            logger.info(f"Scan not complete for {repository_name}:{image_tag}")
            return
        
        # Get scan findings
        response = ecr_client.describe_image_scan_findings(
            repositoryName=repository_name,
            imageId={'imageTag': image_tag}
        )
        
        scan_results = response.get('imageScanFindings', {})
        findings = scan_results.get('findings', [])
        finding_counts = scan_results.get('findingCounts', {})
        
        # Analyze severity
        critical_count = finding_counts.get('CRITICAL', 0)
        high_count = finding_counts.get('HIGH', 0)
        medium_count = finding_counts.get('MEDIUM', 0)
        low_count = finding_counts.get('LOW', 0)
        
        # Calculate risk score
        risk_score = (critical_count * 10) + (high_count * 5) + (medium_count * 2) + (low_count * 1)
        
        # Determine alert level
        alert_level = "INFO"
        if critical_count > 0:
            alert_level = "CRITICAL"
        elif high_count > 5:
            alert_level = "HIGH"
        elif high_count > 0:
            alert_level = "MEDIUM"
        
        # Extract top vulnerabilities
        top_vulnerabilities = []
        for finding in sorted(findings, key=lambda x: x.get('severity', 'LOW'), reverse=True)[:5]:
            vuln_info = {
                'name': finding.get('name', 'Unknown'),
                'severity': finding.get('severity', 'UNKNOWN'),
                'description': finding.get('description', 'No description available')[:200],
                'uri': finding.get('uri', ''),
                'package': finding.get('attributes', {}).get('PACKAGE_NAME', 'Unknown')
            }
            top_vulnerabilities.append(vuln_info)
        
        # Create alert message
        alert_message = create_alert_message(
            repository_name, image_tag, finding_counts, 
            risk_score, alert_level, top_vulnerabilities
        )
        
        # Send alert if needed
        if alert_level in ['CRITICAL', 'HIGH', 'MEDIUM']:
            send_alert(alert_message, alert_level)
        
        # Log summary
        logger.info(f"Scan processed for {repository_name}:{image_tag} - "
                   f"Risk Score: {risk_score}, Alert Level: {alert_level}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Scan processed successfully',
                'repository': repository_name,
                'tag': image_tag,
                'riskScore': risk_score,
                'alertLevel': alert_level
            })
        }
        
    except Exception as e:
        logger.error(f"Error processing scan results: {str(e)}")
        send_error_alert(str(e))
        raise e

def create_alert_message(repo_name, tag, counts, risk_score, alert_level, top_vulns):
    """
    Create formatted alert message
    """
    timestamp = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')
    cluster_name = os.environ.get('CLUSTER_NAME', 'Unknown')
    
    message = f"""
🚨 ECR Security Scan Alert - {alert_level}

Cluster: {cluster_name}
Repository: {repo_name}
Image Tag: {tag}
Scan Time: {timestamp}
Risk Score: {risk_score}

📊 Vulnerability Summary:
• Critical: {counts.get('CRITICAL', 0)}
• High: {counts.get('HIGH', 0)}  
• Medium: {counts.get('MEDIUM', 0)}
• Low: {counts.get('LOW', 0)}

🔍 Top Vulnerabilities:
"""
    
    for i, vuln in enumerate(top_vulns, 1):
        message += f"""
{i}. {vuln['name']} ({vuln['severity']})
   Package: {vuln['package']}
   Description: {vuln['description']}
   URI: {vuln['uri']}
"""
    
    message += f"""
🎯 Recommended Actions:
"""
    
    if counts.get('CRITICAL', 0) > 0:
        message += "• IMMEDIATE: Block deployment of this image\n"
        message += "• Update base image and rebuild\n"
    
    if counts.get('HIGH', 0) > 0:
        message += "• Update vulnerable packages\n"
        message += "• Review and patch within 24 hours\n"
    
    message += "• Run security testing in staging environment\n"
    message += "• Consider using distroless or minimal base images\n"
    
    message += f"""
📈 Security Dashboard: https://console.aws.amazon.com/ecr/repositories/{repo_name}
"""
    
    return message

def send_alert(message, alert_level):
    """
    Send alert to SNS topic
    """
    topic_arn = os.environ.get('SNS_TOPIC_ARN')
    if not topic_arn:
        logger.error("SNS_TOPIC_ARN not configured")
        return
    
    subject = f"[{alert_level}] ECR Security Alert - {os.environ.get('CLUSTER_NAME', 'EKS')}"
    
    try:
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=subject,
            Message=message,
            MessageAttributes={
                'AlertLevel': {
                    'DataType': 'String',
                    'StringValue': alert_level
                },
                'Source': {
                    'DataType': 'String', 
                    'StringValue': 'ECR-Scanner'
                }
            }
        )
        logger.info(f"Alert sent successfully - Level: {alert_level}")
    except Exception as e:
        logger.error(f"Failed to send alert: {str(e)}")

def send_error_alert(error_message):
    """
    Send error alert
    """
    topic_arn = os.environ.get('SNS_TOPIC_ARN')
    if not topic_arn:
        return
    
    cluster_name = os.environ.get('CLUSTER_NAME', 'Unknown')
    timestamp = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')
    
    message = f"""
❌ ECR Scan Processor Error

Cluster: {cluster_name}
Time: {timestamp}
Error: {error_message}

Please check CloudWatch logs for detailed information.
"""
    
    try:
        sns_client.publish(
            TopicArn=topic_arn,
            Subject=f"[ERROR] ECR Scan Processor - {cluster_name}",
            Message=message
        )
    except Exception as e:
        logger.error(f"Failed to send error alert: {str(e)}")
