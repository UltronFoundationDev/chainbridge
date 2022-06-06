#!/usr/bin/env bash

rm -f /userdata.done

DEBIAN_FRONTEND="noninteractive"
TERM="xterm"
PAGER="more"

EC2_INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
EC2_INSTANCE_PUBLIC_IP="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"

alias date="date +'%Y-%m-%dT%H:%M:%S%z'"

# Install packages
apt-get -yq update > /dev/null
apt-get -yq upgrade > /dev/null
apt-get -yq install --no-install-recommends \
    software-properties-common \
    curl \
    git \
    unzip \
    awscli \
    docker.io \
    jq

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
                    "log_group_name": "${log_group_name}",
                    "log_stream_name": "$EC2_INSTANCE_ID",
                    "timestamp_format" :"%b %d %H:%M:%S"
                  }
              ]
          }
      }
  }
}
__EOF__
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
systemctl enable amazon-cloudwatch-agent.service \
    && systemctl start amazon-cloudwatch-agent

# add default 'ubuntu' user to 'docker' group
usermod -a -G docker ubuntu
# Make sure Docker service is started
systemctl enable docker \
  && systemctl restart docker

# get the latest image URL from SSM
docker_image_url=$(aws ssm get-parameter --region ${aws_region} --name /${project_name}/${environment}/${module}/docker_image_url | jq -r .Parameter.Value)
# log into Amazon ECR
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin $(echo $docker_image_url | cut -d'/' -f1)

# start Docker container running graph-node
docker run -d --name=${project_name}-${environment}-graph-node -p 80:16761 --log-driver=awslogs --log-opt awslogs-region=${aws_region} --log-opt awslogs-group=${log_group_name} $docker_image_url

touch /userdata.done
