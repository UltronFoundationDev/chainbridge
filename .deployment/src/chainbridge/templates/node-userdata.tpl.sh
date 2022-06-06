#!/bin/bash
export EC2_INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
export IP="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"

alias date="date +'%Y-%m-%dT%H:%M:%S%z'"
#Install packages
apt update && apt install unzip awscli amazon-ecr-credential-helper docker.io jq -y

# Install AWS CloudWatch agent -the CloudWatch Logs agent provides an automated way to send log data
# to CloudWatch Logs from Amazon EC2 instances. The agent is comprised of the following components:
#   * A plug-in to the AWS CLI that pushes log data to CloudWatch Logs.
#   * A script (daemon) that initiates the process to push data to CloudWatch Logs.
#   * A cron job that ensures that the daemon is always running.
# See https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/QuickStartEC2Instance.html for more details.
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
cat << __EOF__ > /opt/aws/amazon-cloudwatch-agent/bin/config.json
{
  "agent": {
      "run_as_user": "root",
      "logfile": "/var/log/cloud-init-output.log"
  },
  "logs": {
      "logs_collected": {
          "files": {
              "collect_list": [
                {
                  "file_path": "/var/log/cloud-init-output.log",
                  "log_group_name": "/${project_name}/${environment}/${aws_region}/${module_name}",
                  "log_stream_name": "${ec2_instance_name}/init_log",
                  "timestamp_format" :"%b %d %H:%M:%S"
                }
              ]
          }
      }
  }
}
__EOF__

#Start services
systemctl start docker && systemctl enable docker
# log_info "starting the CloudWatch Agent to watch some of the log files on the EC2 instance..."
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
systemctl enable amazon-cloudwatch-agent.service && service amazon-cloudwatch-agent start

#Preparing files before starting Docker container


#Login to Amazon ECR and run docker container
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com