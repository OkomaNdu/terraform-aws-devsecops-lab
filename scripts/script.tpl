#!/bin/bash

# wait 60 seconds until instance fully initialised
sleep 60

# update package repos
sudo apt update

# Install docker on Ubuntu 22.04
sudo apt  install docker.io -y

# Add gitlab-runner & ubuntu users to docker group
sudo usermod -aG docker ubuntu

# Start docker to apply the above change
systemctl restart docker

# Install AWS CLI 
sudo apt install awscli -y

