#!/bin/bash
sudo yum update -y
sudo yum install httpd -y
echo "Hello, World" > /var/wwww/html/index.html
sudo systemctl enable httpd
sudo systemctl start httpd
