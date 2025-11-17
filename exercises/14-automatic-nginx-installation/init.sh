#!/bin/bash

# System aktualisieren
apt update && apt upgrade -y

# Nginx installieren
apt install -y nginx

# Nginx Service managen
systemctl start nginx
systemctl enable nginx