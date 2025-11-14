# Deploy Streamlit to AWS App Runner

AWS App Runner is a fully managed service that can run containerized Streamlit apps.

## Prerequisites
- Docker installed locally
- AWS CLI configured
- ECR repository created

## Steps

1. **Create Dockerfile** (already in repo if exists, or create one):
```dockerfile
FROM python:3.12-slim

WORKDIR /app

COPY streamlit_app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY streamlit_app/ .

EXPOSE 8501

CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0"]
```

2. **Build and push to ECR**:
```bash
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-central-1.amazonaws.com

docker build -t txt2sql-streamlit .
docker tag txt2sql-streamlit:latest <account-id>.dkr.ecr.eu-central-1.amazonaws.com/txt2sql-streamlit:latest
docker push <account-id>.dkr.ecr.eu-central-1.amazonaws.com/txt2sql-streamlit:latest
```

3. **Create App Runner service** via AWS Console or CLI:
- Source: ECR image
- Port: 8501
- Auto-deploy: Enabled

## Cost
- ~$0.007/hour (~$5/month) for minimal instance
- Auto-scales based on traffic
- No EC2 management needed

