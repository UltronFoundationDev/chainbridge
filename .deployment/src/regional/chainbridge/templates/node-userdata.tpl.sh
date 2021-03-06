Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0

--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.txt"

#cloud-config
cloud_final_modules:
- [scripts-user, always]

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"

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
mkdir -p /${module_name}/{blockstore,configs,keyfiles}

echo ${base64_file} | base64 -d > /${module_name}/keyfiles/${address}.key --ignore-garbage

sudo aws s3 cp "s3://${chainbridge_configs_s3_bucket}/${ec2_instance_name}.json" "/${module_name}/configs/config.json"

echo ${chainbridge_password} | base64 -d > /${module_name}/configs/password --ignore-garbage

export KEY_PASS="$(cat /chainbridge/configs/password)"

#Login to Amazon ECR and run docker container
aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com
#Start Docker container
sleep 10
docker run -d \
--restart always \
--name ${module_name}-${environment}-${aws_region}-node-${chainbridge_id} \
-v /${module_name}/keyfiles/${address}.key:/keys/${address}.key \
-v /${module_name}/configs/config.json:/config/config.json \
-v /${module_name}/blockstore/:/blockstore/ \
-e KEYSTORE_PASSWORD=$KEY_PASS \
--log-driver=awslogs \
--log-opt awslogs-region=${aws_region} \
--log-opt awslogs-group="/${project_name}/${environment}/${aws_region}/${module_name}/docker" \
--log-opt awslogs-stream="${module_name}-node-${chainbridge_id}" \
--log-opt awslogs-create-group=true \
${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com/${module_name}-${environment}:latest
