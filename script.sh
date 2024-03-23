#!/bin/bash

# Install Nginx
sudo yum update -y
sudo yum install -y nginx

# Enable Nginx to start automatically on boot
sudo systemctl enable nginx

# Start Nginx service
sudo systemctl start nginx
