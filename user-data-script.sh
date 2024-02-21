#!/bin/bash

# Update and upgrade system packages
sudo apt-get update

# Install required packages for Redmine
sudo apt-get install -y build-essential ruby-dev libxslt1-dev libmariadb-dev gnupg2 bison libbison-dev libgdbm-dev libncurses-dev libncurses5-dev libxml2-dev zlib1g-dev imagemagick libmagickwand-dev libreadline-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 jq git awscli

# Add Redmine System User
sudo useradd -r -m -d /opt/redmine -s /bin/bash redmine

# Add web server user (www-data) to our redmine group.
sudo usermod -aG redmine www-data

# Install nginx
sudo apt-get install nginx -y

# Install Passenger packages
sudo apt-get install -y dirmngr gnupg apt-transport-https ca-certificates curl
sudo curl https://oss-binaries.phusionpassenger.com/auto-software-signing-gpg-key.txt | gpg --dearmor | tee /etc/apt/trusted.gpg.d/phusion.gpg >/dev/null
sudo sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger jammy main > /etc/apt/sources.list.d/passenger.list'
sudo apt-get update
sudo apt-get install libnginx-mod-http-passenger -y

# Download the CloudWatch Agent package
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb

# Install the CloudWatch Agent
sudo dpkg -i -E ./amazon-cloudwatch-agent.deb

# Restart nginx
sudo systemctl restart nginx

# Get the ServerName from metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Retrieve the instance identity document
identity_document=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/dynamic/instance-identity/document)

# Extract the region from the identity document using cut
region=$(echo $identity_document | grep -o '"region" : "[^"]*"' | cut -d'"' -f4)

# Retrieve database configuration from SSM Parameter Store
DB_NAME=$(aws ssm get-parameter --name "/redmine/db/name" --with-decryption --query "Parameter.Value" --region $region --output text)
DB_HOST=$(aws ssm get-parameter --name "/redmine/db/host" --with-decryption --query "Parameter.Value" --region $region --output text)
DB_USER=$(aws ssm get-parameter --name "/redmine/db/user" --with-decryption --query "Parameter.Value" --region $region --output text)
DB_PASSWORD=$(aws ssm get-parameter --name "/redmine/db/password" --with-decryption --query "Parameter.Value" --region $region --output text)
DB_ENCODING=$(aws ssm get-parameter --name "/redmine/db/encoding" --with-decryption --query "Parameter.Value" --region $region --output text)

# Download and extract Redmine
cd /tmp
sudo wget https://www.redmine.org/releases/redmine-5.1.1.tar.gz
sudo tar -xzvf redmine-5.1.1.tar.gz -C /opt/redmine/ --strip-components=1

# Install Redmine Issue Dynamic Edit Plugin
sudo git clone https://github.com/Ilogeek/redmine_issue_dynamic_edit.git /opt/redmine/plugins/redmine_issue_dynamic_edit

# Install OAuth plugin (example URL, replace with actual plugin repository)
sudo git clone https://github.com/kontron/redmine_oauth.git /opt/redmine/plugins/redmine_oauth

# Update redmine directories right
sudo chown -R redmine:redmine /opt/redmine/

# Configure Redmine files and permissions
sudo -u redmine cp -a /opt/redmine/config/configuration.yml{.example,}
sudo -u redmine cp -a /opt/redmine/public/dispatch.fcgi{.example,}

# Create the database.yml file with the retrieved values
sudo -u redmine bash -c "cat << EOF > /opt/redmine/config/database.yml
production:
  adapter: mysql2
  database: $DB_NAME
  host: $DB_HOST
  username: $DB_USER
  password: \"$DB_PASSWORD\"
  encoding: $DB_ENCODING
EOF"

# Install bundler and dependencies
cd /opt/redmine
sudo gem install bundler
sudo -u redmine bash -c "bundle config set --local path 'vendor/bundle'"
sudo -u redmine bash -c "bundle install"
sudo -u redmine bash -c "bundle update"

# Generate secret token
sudo -u redmine bundle exec rake generate_secret_token

# Perform database migration
sudo -u redmine RAILS_ENV=production bundle exec rake db:migrate

# Load default data
sudo -u redmine RAILS_ENV=production REDMINE_LANG=en bundle exec rake redmine:load_default_data

# Update bundler
sudo gem update

# Create and configure redmine.conf file with dynamic ServerName
sudo bash -c "cat <<'EOF' > /etc/nginx/conf.d/redmine.conf
server {
    listen 80;
    server_name redmine.argocd-agyla.cloud;

    root /opt/redmine/public;

    passenger_enabled on;

    passenger_min_instances 1;

    client_max_body_size 10m;

    error_page 404 /opt/redmine/public/404.html;
    error_page 500 502 503 504 /opt/redmine/public/500.html;

    location / {
        try_files $uri $uri/ @ruby;
    }

    location @ruby {
        passenger_enabled on;
    }

    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    error_log /var/log/nginx/redmine.error.log;
    access_log /var/log/nginx/redmine.access.log;
}
EOF"
cat <<EOF > /opt/aws/amazon-cloudwatch-agent/cloudwatch-agent-config.json
{
  "agent": {
    "metrics_collection_interval": 60,
    "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log"
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "\${aws:InstanceId}"
    },
    "metrics_collected": {
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "cpu": {
        "resources": [
          "*"
        ],
        "totalcpu": false,
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "nginx-access-logs",
            "log_stream_name": "{instance_id}-nginx-access",
            "timezone": "Local"
          },
          {
            "file_path": "/opt/redmine/log/production.log",
            "log_group_name": "redmine-logs",
            "log_stream_name": "{instance_id}-redmine",
            "timezone": "Local"
          }
        ]
      }
    }
  }
}
EOF

# Start the CloudWatch Agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/cloudwatch-agent-config.json -s

# Restart nginx to apply the new configuration
sudo systemctl restart nginx
