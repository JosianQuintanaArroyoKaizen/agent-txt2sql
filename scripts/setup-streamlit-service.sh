#!/bin/bash
# Script to set up Streamlit as a systemd service on EC2
# Run this once on your EC2 instance

set -e

SERVICE_NAME="streamlit-txt2sql"
APP_DIR="/home/ubuntu/app/streamlit_app"
APP_FILE="app.py"
PORT=8501
USER="ubuntu"

# Create systemd service file
sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null <<EOF
[Unit]
Description=Streamlit Text2SQL Agent App
After=network.target

[Service]
Type=simple
User=${USER}
WorkingDirectory=${APP_DIR}
Environment="PATH=/home/ubuntu/.local/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=/home/ubuntu/.local/bin/streamlit run ${APP_FILE} --server.port=${PORT} --server.address=0.0.0.0
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl start ${SERVICE_NAME}

echo "Streamlit service '${SERVICE_NAME}' has been set up and started!"
echo "Check status with: sudo systemctl status ${SERVICE_NAME}"
echo "View logs with: sudo journalctl -u ${SERVICE_NAME} -f"

