# Technical Architecture Document
## Amazon Bedrock Text-to-SQL Agent System

**Version:** 1.0  
**Date:** November 18, 2025  
**Author:** System Architecture Team  
**Status:** Production

---

## Executive Summary

This document describes the technical architecture of an AI-powered Natural Language to SQL (Text2SQL) system built on AWS services. The system enables non-technical users to query relational databases using natural language, with automatic SQL generation and execution powered by Amazon Bedrock's generative AI capabilities.

### Key Capabilities
- **Natural Language Query Processing**: Convert plain English questions into SQL queries
- **Automated Query Execution**: Execute generated queries against Amazon Athena
- **Multi-Interface Support**: Web UI (Streamlit), Static Frontend, and API access
- **Enterprise-Grade Security**: IAM-based access control, encryption at rest and in transit
- **GDPR Compliant**: EU data residency with cross-region inference profile
- **Fully Serverless**: Auto-scaling with AWS managed services

---

## Table of Contents

1. [System Architecture Overview](#system-architecture-overview)
2. [Component Architecture](#component-architecture)
3. [Data Flow & Processing Pipeline](#data-flow--processing-pipeline)
4. [Technology Stack](#technology-stack)
5. [Infrastructure as Code](#infrastructure-as-code)
6. [Security Architecture](#security-architecture)
7. [Deployment Architecture](#deployment-architecture)
8. [API Specifications](#api-specifications)
9. [Data Model](#data-model)
10. [Scalability & Performance](#scalability--performance)
11. [Monitoring & Observability](#monitoring--observability)
12. [CI/CD Pipeline](#cicd-pipeline)
13. [Cost Optimization](#cost-optimization)

---

## 1. System Architecture Overview

### 1.1 High-Level Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                         User Interfaces                             │
├─────────────────┬──────────────────┬───────────────────────────────┤
│  Streamlit UI   │  Static Web UI   │  Direct API Access            │
│  (EC2/ECS/      │  (S3 + CloudFront│  (SDK Integration)            │
│   App Runner)   │   + API Gateway) │                               │
└────────┬────────┴─────────┬────────┴────────────┬──────────────────┘
         │                  │                      │
         └──────────────────┴──────────────────────┘
                            │
                            ▼
         ┌──────────────────────────────────────────┐
         │      Amazon Bedrock Agent                │
         │  (AI Orchestration & Reasoning Layer)    │
         │  - Claude 3.5 Sonnet / Haiku            │
         │  - Chain-of-Thought Processing           │
         │  - Action Group Management               │
         └───────────────┬──────────────────────────┘
                         │
                         ▼
         ┌──────────────────────────────────────────┐
         │      Action Group                        │
         │  (OpenAPI Schema Definition)             │
         │  - Query Parameter Validation            │
         │  - Response Structure Definition         │
         └───────────────┬──────────────────────────┘
                         │
                         ▼
         ┌──────────────────────────────────────────┐
         │   AWS Lambda Function                    │
         │   (Query Execution Engine)               │
         │   - SQL Query Processing                 │
         │   - Athena Integration                   │
         │   - Result Formatting                    │
         └───────────────┬──────────────────────────┘
                         │
                         ▼
         ┌──────────────────────────────────────────┐
         │   Amazon Athena + AWS Glue              │
         │   (SQL Query Engine & Data Catalog)      │
         │   - Serverless SQL Execution             │
         │   - Schema Management                    │
         │   - Query Optimization                   │
         └───────────────┬──────────────────────────┘
                         │
                         ▼
         ┌──────────────────────────────────────────┐
         │   Amazon S3                              │
         │   (Data Lake Storage)                    │
         │   - CSV/Parquet Data Files               │
         │   - Query Results Cache                  │
         │   - Logging & Audit Trail                │
         └──────────────────────────────────────────┘
```

### 1.2 Architectural Principles

1. **Serverless-First**: Minimize operational overhead with managed services
2. **Security by Design**: Multi-layer security with least privilege access
3. **Event-Driven**: Asynchronous processing with decoupled components
4. **Infrastructure as Code**: All resources defined in CloudFormation
5. **Multi-Environment**: Support for dev, staging, and production deployments
6. **Cost-Optimized**: Pay-per-use model with automatic scaling

---

## 2. Component Architecture

### 2.1 Frontend Layer

#### 2.1.1 Streamlit Application (Primary UI)
- **Location**: EC2 Instance, ECS with ALB, or AWS App Runner
- **Technology**: Python 3.12, Streamlit Framework
- **Features**:
  - Interactive chat interface
  - Real-time query execution
  - Result visualization (tables, charts)
  - Session management
  - Conversation history
- **Components**:
  - `app.py`: Main Streamlit application
  - `invoke_agent.py`: Bedrock Agent SDK integration

**Deployment Options**:
```yaml
Option 1: EC2 with Elastic IP
  - Instance Type: t3.small (2 vCPU, 2GB RAM)
  - Port: 8501
  - Auto-start: systemd service
  
Option 2: ECS Fargate with ALB
  - Task CPU: 512
  - Task Memory: 1024MB
  - Load Balanced: Application Load Balancer
  
Option 3: AWS App Runner
  - Auto-scaling: 1-10 instances
  - CPU/Memory: 1 vCPU / 2GB RAM
  - Health checks: /healthz endpoint
```

#### 2.1.2 Static Web Frontend
- **Location**: S3 Static Website + CloudFront (optional)
- **Technology**: Vanilla JavaScript, HTML5, CSS3
- **Features**:
  - Lightweight interface
  - No backend server required
  - Direct Bedrock Agent invocation via Lambda proxy
  - LocalStorage for conversation history
- **Components**:
  - `index.html`: Single-page application
  - `app.js`: Client-side application logic
  - `lambda-proxy.py`: API Gateway Lambda proxy

#### 2.1.3 API Gateway Layer
- **Purpose**: Proxy frontend requests to Bedrock Agent
- **Authentication**: AWS SigV4 signing
- **Endpoints**:
  - `POST /chat`: Send natural language query
  - `OPTIONS /*`: CORS preflight handling
- **CORS Configuration**: Allow all origins (configurable)

### 2.2 AI Orchestration Layer

#### 2.2.1 Amazon Bedrock Agent
**Configuration**:
```yaml
Foundation Model: anthropic.claude-3-5-sonnet-20240620-v1:0
  - For EU regions: eu.anthropic.claude-3-haiku-20240307-v1:0
Idle Session Timeout: 600 seconds (10 minutes)
Instruction Prompt: Enhanced EMIR-specific instructions
Knowledge Base: None (direct action group execution)
```

**Agent Capabilities**:
- **Natural Language Understanding**: Parse user intent from free-form text
- **SQL Generation**: Create optimized SQL queries for Athena
- **Context Management**: Maintain conversation state across requests
- **Chain-of-Thought Reasoning**: Break down complex queries into steps
- **Error Handling**: Gracefully handle ambiguous or invalid requests

**Instruction Prompt Strategy**:
The agent uses a comprehensive system prompt that includes:
1. Database schema with field descriptions
2. Query best practices (column selection, date handling)
3. Output formatting guidelines (5-10 relevant columns)
4. EMIR-specific domain knowledge
5. Error handling patterns

#### 2.2.2 Action Group
**OpenAPI Schema** (`schema/athena-schema.json`):
```json
{
  "openapi": "3.0.1",
  "paths": {
    "/athenaQuery": {
      "post": {
        "requestBody": {
          "properties": {
            "Query": {
              "type": "string",
              "description": "SQL Query"
            }
          }
        },
        "responses": {
          "200": {
            "description": "Query results",
            "schema": { "type": "object" }
          }
        }
      }
    }
  }
}
```

**Action Group Configuration**:
- **Name**: AthenaQueryActionGroup
- **Lambda Function**: AthenaQueryLambda
- **Execution Method**: Synchronous
- **Timeout**: 120 seconds

### 2.3 Compute Layer

#### 2.3.1 AWS Lambda Function - Query Executor
**Specifications**:
```python
Function Name: AthenaQueryLambda-{Alias}-{Region}-{AccountId}
Runtime: Python 3.12
Memory: 1024 MB
Timeout: 120 seconds
Concurrency: Reserved (optional, default: unreserved)
```

**Environment Variables**:
```bash
S3Output: s3://sl-athena-output-{alias}-{account}-{region}/
DatabaseName: {alias}_athena_db
```

**Execution Flow**:
1. Receive event from Bedrock Agent
2. Extract SQL query from request body
3. Handle empty/greeting queries gracefully
4. Execute query via Athena SDK
5. Poll for query completion (1-second intervals)
6. Retrieve and format results
7. Return structured response to Agent

**Key Code Sections**:
```python
def lambda_handler(event, context):
    # Extract query from Bedrock Agent request
    query = event['requestBody']['content']['application/json']['properties'][0]['value']
    
    # Handle greetings
    if not query or query.strip() == '':
        return friendly_greeting_response()
    
    # Execute Athena query
    execution_id = execute_athena_query(query, s3_output, database_name)
    
    # Poll and retrieve results
    result = get_query_results(execution_id)
    
    return format_response_for_agent(result)
```

**IAM Role Permissions**:
- `AmazonAthenaFullAccess`: Query execution and management
- `AmazonS3FullAccess`: Read data, write results
- `CloudWatchLogsPolicy`: Create logs

### 2.4 Data Layer

#### 2.4.1 Amazon Athena
**Configuration**:
```yaml
Workgroup: primary (default)
Query Result Location: s3://sl-athena-output-{alias}-{account}-{region}/
Data Catalog: AWS Glue Data Catalog
Query Engine: Trino (PrestoDB fork)
```

**Database Structure**:
```sql
Database: {alias}_athena_db
Tables:
  - customers (legacy demo data)
  - procedures (legacy demo data)
  - test_population (primary EMIR data - 7,867 records)
```

**Query Optimization Features**:
- **Partitioning**: By date fields (reporting_date_1_1)
- **Compression**: GZIP for CSV storage
- **Column Pruning**: Select only required columns
- **Result Caching**: Reuse recent query results

#### 2.4.2 AWS Glue Data Catalog
**Purpose**: Metadata repository for Athena tables

**Crawler Configuration**:
```yaml
Name: glue-crawler-{alias}
Role: GlueCrawlerRole
Targets: s3://sl-data-store-{alias}/
Schedule: On-demand (manual trigger)
Output Database: {alias}_athena_db
```

**Table Metadata**:
- Schema inference from CSV headers
- Data type detection
- Partition discovery
- Statistics collection

#### 2.4.3 Amazon S3 Storage Architecture
**Bucket Strategy**:
```
1. Data Store Bucket: sl-data-store-{alias}-{account}-{region}
   Purpose: Source data files (CSV, Parquet)
   Structure:
     /custom/
       /test_population/
         - *.csv files
       /customers/
       /procedures/
     /uploads/ (user-uploaded data)
   
2. Athena Output Bucket: sl-athena-output-{alias}-{account}-{region}
   Purpose: Query results and metadata
   Structure:
     /{query-execution-id}/
       - *.csv (result file)
       - *.csv.metadata
   
3. Replication Bucket: sl-replication-{alias}-{account}-{region}
   Purpose: Disaster recovery
   Replication: Cross-region (same-region for GDPR)
   
4. Logging Bucket: logging-bucket-{alias}-{account}-{region}
   Purpose: Access logs for audit
```

**Security Configuration**:
```yaml
Encryption: AES-256 (server-side)
Versioning: Enabled
Object Lock: Enabled (compliance mode)
Public Access: Blocked (all settings)
Replication: Enabled (to replication bucket)
Lifecycle Policies:
  - Athena results: Delete after 30 days
  - Logs: Transition to Glacier after 90 days
```

---

## 3. Data Flow & Processing Pipeline

### 3.1 User Query Flow

```
1. User Input
   │
   ├─→ Streamlit UI: Text input field
   ├─→ Static Web UI: Chat input box
   └─→ Direct API: SDK/REST call
   
2. Request Routing
   │
   ├─→ Streamlit: invoke_agent.py → bedrock-agent-runtime API
   ├─→ Static Web: API Gateway → Lambda Proxy → bedrock-agent-runtime API
   └─→ Direct API: SDK → bedrock-agent-runtime API
   
3. Bedrock Agent Processing
   │
   ├─→ Parse natural language query
   ├─→ Consult instruction prompt (database schema)
   ├─→ Generate SQL query using Claude LLM
   ├─→ Validate query structure
   └─→ Determine action group to invoke
   
4. Action Group Execution
   │
   └─→ Invoke Lambda with generated SQL
   
5. Lambda Query Execution
   │
   ├─→ Extract SQL from event payload
   ├─→ Call athena_client.start_query_execution()
   ├─→ Poll query status (QUEUED → RUNNING → SUCCEEDED/FAILED)
   └─→ Retrieve results via get_query_results()
   
6. Athena Query Processing
   │
   ├─→ Parse SQL query
   ├─→ Consult Glue Data Catalog for table schema
   ├─→ Read data from S3 (CSV files)
   ├─→ Execute query using Trino engine
   ├─→ Write results to S3 output bucket
   └─→ Return result metadata
   
7. Response Formatting
   │
   ├─→ Lambda formats result as JSON
   ├─→ Bedrock Agent processes response
   ├─→ Natural language summary generated
   └─→ Structured data + narrative returned
   
8. User Interface Display
   │
   ├─→ Streamlit: DataFrame table + markdown
   ├─→ Static Web: HTML table + formatting
   └─→ API: JSON response
```

### 3.2 Data Ingestion Pipeline

```
1. CSV Upload
   │
   └─→ Manual upload to S3 or use ingest_csv_to_athena.py script
   
2. Schema Detection
   │
   ├─→ Read CSV header row
   ├─→ Sanitize column names (lowercase, remove special chars)
   ├─→ Detect data types (all STRING for flexibility)
   └─→ Handle duplicate column names
   
3. Table Creation
   │
   ├─→ Generate CREATE EXTERNAL TABLE DDL
   ├─→ Define S3 LOCATION
   ├─→ Set ROW FORMAT (CSV with headers)
   └─→ Execute via Athena
   
4. Optional View Creation
   │
   └─→ Create view with original column names for user-friendliness
   
5. Glue Crawler (Optional)
   │
   ├─→ Scan S3 prefix
   ├─→ Infer schema
   ├─→ Update Glue Data Catalog
   └─→ Detect partitions
   
6. Validation
   │
   ├─→ Run test query: SELECT COUNT(*) FROM table
   ├─→ Verify row count matches source
   └─→ Spot-check data samples
```

---

## 4. Technology Stack

### 4.1 AWS Services

| Service | Purpose | Configuration |
|---------|---------|---------------|
| **Amazon Bedrock** | AI model hosting & orchestration | Claude 3.5 Sonnet, Agent framework |
| **AWS Lambda** | Serverless compute | Python 3.12, 1024MB memory, 120s timeout |
| **Amazon Athena** | SQL query engine | Trino-based, serverless |
| **AWS Glue** | Data catalog & ETL | Schema registry, crawlers |
| **Amazon S3** | Object storage | AES-256 encryption, versioning |
| **Amazon EC2** | Streamlit hosting (option 1) | t3.small, Amazon Linux 2023 |
| **Amazon ECS** | Container orchestration (option 2) | Fargate, ALB integration |
| **AWS App Runner** | PaaS deployment (option 3) | Dockerfile-based, auto-scaling |
| **API Gateway** | HTTP API proxy | REST API, CORS enabled |
| **CloudFormation** | Infrastructure as Code | YAML templates, nested stacks |
| **IAM** | Access control | Roles, policies, least privilege |
| **CloudWatch** | Logging & monitoring | Lambda logs, custom metrics |

### 4.2 Programming Languages & Frameworks

| Technology | Version | Purpose |
|------------|---------|---------|
| **Python** | 3.12 | Lambda functions, Streamlit app |
| **Boto3** | Latest | AWS SDK for Python |
| **Streamlit** | Latest | Web UI framework |
| **JavaScript** | ES6+ | Static web frontend |
| **HTML5/CSS3** | - | Web UI markup & styling |
| **Bash** | 4.x | Deployment scripts |
| **YAML** | 1.2 | CloudFormation templates |
| **JSON** | - | API schemas, configuration |

### 4.3 Third-Party Libraries

```python
# Python Dependencies
boto3>=1.34.0          # AWS SDK
streamlit>=1.30.0      # Web UI framework
pandas>=2.0.0          # Data manipulation
requests>=2.31.0       # HTTP client
botocore>=1.34.0       # AWS core library
```

---

## 5. Infrastructure as Code

### 5.1 CloudFormation Templates

#### Template 1: Data Layer (`1-athena-glue-s3-template.yaml`)
**Resources Created**:
- S3 buckets (data, output, replication, logging)
- Glue database and crawler
- Athena workgroup configuration
- IAM roles for Glue and S3 replication

**Parameters**:
```yaml
AthenaDatabaseName: athena_db
Alias: txt2sql-dev
AliasDb: txt2sql_dev (underscores only)
```

**Outputs**:
```yaml
DataBucketName: sl-data-store-{alias}-{account}-{region}
AthenaOutputBucket: sl-athena-output-{alias}-{account}-{region}
GlueDatabaseName: {alias}_athena_db
```

#### Template 2: Compute Layer (`2-bedrock-agent-lambda-template.yaml`)
**Resources Created**:
- Lambda function (AthenaQueryLambda)
- Bedrock Agent with action group
- IAM execution roles
- Lambda permissions for Bedrock invocation
- CloudWatch log groups

**Parameters**:
```yaml
FoundationModel: anthropic.claude-3-5-sonnet-20240620-v1:0
Alias: txt2sql-dev
AthenaDatabaseName: athena_db
AliasDb: txt2sql_dev
```

**Agent Configuration**:
```yaml
AgentInstruction: |
  You are an expert SQL analyst for EMIR trade repository data.
  Database: {alias}_athena_db
  Tables: customers, procedures, test_population
  
  Key Instructions:
  1. Generate accurate SQL queries for Amazon Athena
  2. Select only 5-10 relevant columns (not all 200+)
  3. Use proper date column: reporting_date_1_1
  4. Always execute queries, don't just return SQL
  5. Format results clearly with column headers
```

#### Template 3: Frontend Layer (`3-ec2-streamlit-template.yaml`, `4-ecs-alb-streamlit-template.yaml`)
**EC2 Deployment**:
- Instance: t3.small
- AMI: Amazon Linux 2023
- Elastic IP: Auto-assigned
- Security Group: Port 8501 (Streamlit), 22 (SSH via EC2 Instance Connect)
- User Data: Install dependencies, configure systemd service

**ECS Deployment**:
- Cluster: Fargate
- Task Definition: 1 vCPU, 2GB RAM
- Service: Auto-scaling 1-10 tasks
- Load Balancer: Application Load Balancer
- Target Group: Port 8501, health check `/healthz`

### 5.2 Deployment Scripts

```bash
# deploy.sh - Main deployment orchestrator
./deploy.sh
  ├─→ Validates AWS credentials
  ├─→ Deploys template 1 (data layer)
  ├─→ Waits for stack completion
  ├─→ Deploys template 2 (compute layer)
  ├─→ Waits for stack completion
  ├─→ Deploys template 3 (frontend layer)
  └─→ Outputs access URLs and configuration

# deploy-production.sh - Production deployment
ENVIRONMENT=prod ./deploy-production.sh
  ├─→ Uses prod-specific parameters
  ├─→ Enables stack protection
  ├─→ Requires manual approval for sensitive changes
  └─→ Deploys to production account/region

# cleanup.sh - Resource teardown
./cleanup.sh
  ├─→ Deletes CloudFormation stacks (reverse order)
  ├─→ Empties S3 buckets before deletion
  ├─→ Removes orphaned resources
  └─→ Confirms all resources deleted
```

### 5.3 Multi-Environment Support

**Parameter File Strategy**:
```bash
config/
  ├─ dev-parameters.json
  ├─ staging-parameters.json
  └─ prod-parameters.json
```

**Example Parameters**:
```json
{
  "Alias": "txt2sql-dev",
  "AliasDb": "txt2sql_dev",
  "FoundationModel": "anthropic.claude-3-5-sonnet-20240620-v1:0",
  "Environment": "dev"
}
```

**Stack Naming Convention**:
```
{Template}-{Alias}-{Environment}
Example: BedrockAgentStack-txt2sql-dev
```

---

## 6. Security Architecture

### 6.1 Identity & Access Management

#### 6.1.1 IAM Roles

**BedrockAgentExecutionRole**:
```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "arn:aws:bedrock:*::foundation-model/*"
    },
    {
      "Effect": "Allow",
      "Action": "lambda:InvokeFunction",
      "Resource": "arn:aws:lambda:*:*:function:AthenaQueryLambda-*"
    }
  ]
}
```

**AthenaQueryLambdaExecutionRole**:
```json
{
  "ManagedPolicies": [
    "AmazonAthenaFullAccess",
    "AmazonS3FullAccess"
  ],
  "InlinePolicy": {
    "CloudWatchLogs": {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/lambda/*"
    }
  }
}
```

**EC2StreamlitInstanceRole**:
```json
{
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "bedrock-agent-runtime:InvokeAgent"
      ],
      "Resource": "arn:aws:bedrock:*:*:agent/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter"
      ],
      "Resource": "arn:aws:ssm:*:*:parameter/bedrock-txt2sql/*"
    }
  ]
}
```

### 6.2 Network Security

#### Security Group Configuration

**Streamlit EC2 Instance**:
```yaml
Inbound Rules:
  - Port 8501: Source 0.0.0.0/0 (Streamlit UI)
  - Port 22: Source {EC2_INSTANCE_CONNECT_CIDR} (SSH)
    # US regions: 18.206.107.24/29
    # EU regions: 3.120.181.40/29
Outbound Rules:
  - All traffic: Destination 0.0.0.0/0
```

**ALB Security Group (ECS Deployment)**:
```yaml
Inbound Rules:
  - Port 80: Source 0.0.0.0/0 (HTTP)
  - Port 443: Source 0.0.0.0/0 (HTTPS)
Outbound Rules:
  - Port 8501: Target ECS tasks
```

### 6.3 Data Encryption

#### Encryption at Rest
- **S3 Buckets**: AES-256 server-side encryption (SSE-S3)
- **Athena Results**: Encrypted using same S3 encryption
- **Lambda Environment Variables**: AWS-managed keys
- **Optional**: Customer-managed KMS keys for enhanced control

#### Encryption in Transit
- **HTTPS/TLS 1.2+**: All API communications
- **SigV4 Signing**: AWS API requests authenticated
- **VPC Endpoints** (optional): Private connectivity to AWS services

### 6.4 GDPR Compliance (EU Deployments)

**Data Residency**:
- All resources deployed in EU regions (eu-central-1 default)
- Cross-region inference profile for Bedrock: `eu.anthropic.claude-3-haiku-20240307-v1:0`
- No data transfer outside EU

**Right to Erasure**:
- S3 versioning enables soft deletes
- Lifecycle policies for automatic data expiration
- Manual deletion procedures documented

**Data Protection**:
- Access logging enabled for all S3 operations
- CloudTrail logging for API audit trail
- Encryption at rest and in transit enforced

---

## 7. Deployment Architecture

### 7.1 Deployment Options Comparison

| Aspect | EC2 | ECS + ALB | App Runner |
|--------|-----|-----------|------------|
| **Complexity** | Low | Medium | Low |
| **Scalability** | Manual | Auto-scale | Auto-scale |
| **Cost** | Fixed ($17/mo) | Variable | Variable |
| **Management** | Manual updates | Container-based | Fully managed |
| **Load Balancing** | Optional (ALB) | Included | Built-in |
| **Health Checks** | Custom | ALB health checks | Automatic |
| **Deployment** | User data script | ECS task definition | Dockerfile |
| **Best For** | Dev/Testing | Production | Production |

### 7.2 High Availability (ECS Deployment)

```
┌─────────────────────────────────────────────────────┐
│             Application Load Balancer               │
│  (Multi-AZ: eu-central-1a, eu-central-1b)          │
└──────────────┬──────────────────────┬───────────────┘
               │                      │
               ▼                      ▼
    ┌─────────────────┐    ┌─────────────────┐
    │  ECS Task (AZ-a)│    │  ECS Task (AZ-b)│
    │  Streamlit App  │    │  Streamlit App  │
    │  1 vCPU, 2GB RAM│    │  1 vCPU, 2GB RAM│
    └─────────────────┘    └─────────────────┘
```

**Features**:
- Multi-AZ deployment (2+ availability zones)
- Health checks: `/healthz` endpoint (30s interval)
- Auto-scaling: Target tracking on CPU utilization (70%)
- Rolling deployments: Zero-downtime updates
- Connection draining: 30-second grace period

### 7.3 Disaster Recovery

**Backup Strategy**:
- **S3 Replication**: Cross-region replication enabled for data bucket
- **CloudFormation Templates**: Version-controlled in GitHub
- **RTO (Recovery Time Objective)**: < 1 hour
- **RPO (Recovery Point Objective)**: < 15 minutes (S3 replication lag)

**Recovery Procedure**:
1. Deploy CloudFormation stacks in backup region
2. Update S3 bucket references to replica bucket
3. Re-upload Athena table definitions (if Glue not replicated)
4. Update DNS/routing to new region
5. Verify application functionality

---

## 8. API Specifications

### 8.1 Bedrock Agent Invocation API

**Endpoint**: `bedrock-agent-runtime:InvokeAgent`

**Request**:
```python
response = bedrock_runtime.invoke_agent(
    agentId='AGENT_ID',
    agentAliasId='ALIAS_ID',
    sessionId='unique-session-id',
    inputText='Show me 10 records from test_population'
)
```

**Response** (Streaming):
```python
for event in response['completion']:
    if 'chunk' in event:
        chunk = event['chunk']
        if 'bytes' in chunk:
            data = chunk['bytes'].decode('utf-8')
            # Process streamed response
```

### 8.2 Lambda Proxy API (Static Frontend)

**Endpoint**: `https://{api-id}.execute-api.{region}.amazonaws.com/prod/chat`

**Request**:
```json
POST /chat
Content-Type: application/json

{
  "question": "How many records are in test_population?",
  "sessionId": "web-session-12345"
}
```

**Response**:
```json
HTTP/1.1 200 OK
Content-Type: application/json
Access-Control-Allow-Origin: *

{
  "response": "There are 7,867 records in the test_population table.",
  "trace": {
    "sqlQuery": "SELECT COUNT(*) FROM txt2sql_dev_athena_db.test_population",
    "executionTime": "1.23s",
    "resultCount": 1
  }
}
```

### 8.3 Action Group API Schema

**OpenAPI Specification**: `/athenaQuery` endpoint

**Request Body**:
```json
{
  "Query": "SELECT * FROM test_population LIMIT 5"
}
```

**Response**:
```json
{
  "ResultSet": {
    "Rows": [
      {
        "Data": [
          {"VarCharValue": "Column1Value"},
          {"VarCharValue": "Column2Value"}
        ]
      }
    ],
    "ResultSetMetadata": {
      "ColumnInfo": [
        {"Name": "column1", "Type": "varchar"},
        {"Name": "column2", "Type": "varchar"}
      ]
    }
  }
}
```

---

## 9. Data Model

### 9.1 Primary Table: test_population

**Description**: EMIR (European Market Infrastructure Regulation) derivatives trade repository data

**Row Count**: 7,867 records

**Schema** (200+ columns, key fields shown):
```sql
CREATE EXTERNAL TABLE txt2sql_dev_athena_db.test_population (
  -- Identifiers
  incident_code VARCHAR,
  incident_description VARCHAR,
  uti_2_1 VARCHAR,  -- Unique Transaction Identifier
  kr_record_key VARCHAR,
  isin_2_7 VARCHAR,
  source_file_name VARCHAR,
  
  -- Counterparty Information
  counterparty_1_reporting_counterparty_1_4 VARCHAR,
  counterparty_2_1_9 VARCHAR,
  nature_of_the_counterparty_1_1_5 VARCHAR,
  nature_of_the_counterparty_2_1_11 VARCHAR,
  country_of_the_counterparty_2_1_10 VARCHAR,
  
  -- Date Columns (PRIMARY DATE FIELD: reporting_date_1_1)
  reporting_date_1_1 STRING,
  reporting_timestamp_1_1 STRING,
  execution_date_2_42 STRING,
  execution_timestamp_2_42 STRING,
  effective_date_2_43 STRING,
  expiration_date_2_44 STRING,
  valuation_date_2_23 STRING,
  confirmation_date_2_28 STRING,
  clearing_date_2_32 STRING,
  
  -- Financial Information
  valuation_amount_2_21 STRING,
  valuation_currency_2_22 VARCHAR,
  notional_amount_of_leg_1_2_55 STRING,
  notional_amount_of_leg_2_2_64 STRING,
  notional_currency_1_2_56 VARCHAR,
  notional_currency_2_2_65 VARCHAR,
  price_2_48 STRING,
  price_currency_2_49 VARCHAR
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION 's3://sl-data-store-txt2sql-dev-{account}-{region}/custom/test_population/'
TBLPROPERTIES ('skip.header.line.count'='1');
```

### 9.2 Legacy Tables (Demo Data)

#### customers
```sql
CREATE EXTERNAL TABLE customers (
  customer_id VARCHAR,
  name VARCHAR,
  vip VARCHAR,
  balance DECIMAL(10,2)
)
LOCATION 's3://.../customers/';
```

#### procedures
```sql
CREATE EXTERNAL TABLE procedures (
  procedure_id VARCHAR,
  procedure_name VARCHAR,
  cost DECIMAL(10,2)
)
LOCATION 's3://.../procedures/';
```

---

## 10. Scalability & Performance

### 10.1 Scalability Characteristics

| Component | Scaling Model | Limits | Notes |
|-----------|---------------|--------|-------|
| **Bedrock Agent** | Auto-scaling | Throttling: 10 TPS (default) | Request quota increase for production |
| **Lambda** | Auto-scaling | 1000 concurrent executions (default) | Reserved concurrency configurable |
| **Athena** | Serverless | 20 concurrent queries (default) | Can request increase |
| **S3** | Infinite | No practical limit | Pay per request |
| **ECS Fargate** | Auto-scaling | 1-10 tasks (configurable) | CPU-based scaling |

### 10.2 Performance Optimization

#### Query Optimization
- **Column Selection**: Agent instructed to select only 5-10 relevant columns
- **Partition Pruning**: Use date columns in WHERE clauses
- **Result Caching**: Athena caches results for 24 hours
- **Compression**: Store data in Parquet for 3-10x performance improvement

#### Lambda Optimization
- **Memory Allocation**: 1024MB (optimal for network I/O)
- **Connection Pooling**: Reuse Athena client across invocations
- **Cold Start Mitigation**: Reserved concurrency (optional)

#### Frontend Optimization
- **Session Management**: Reuse session IDs to maintain context
- **Client-Side Caching**: Store conversation history locally
- **Lazy Loading**: Paginate large result sets

### 10.3 Benchmark Results

**Test Query**: `SELECT * FROM test_population LIMIT 100`

| Metric | Value | Notes |
|--------|-------|-------|
| **Bedrock Agent Latency** | 2-5s | Includes LLM inference time |
| **Lambda Execution Time** | 3-8s | Includes Athena query time |
| **Athena Query Time** | 1-3s | Small dataset, cached |
| **Total End-to-End** | 6-16s | First query (cold start) |
| **Subsequent Queries** | 3-8s | Warm Lambda, result caching |

---

## 11. Monitoring & Observability

### 11.1 CloudWatch Metrics

**Lambda Function**:
- Invocations
- Duration (p50, p90, p99)
- Errors
- Throttles
- Concurrent Executions

**Athena**:
- Query Execution Time
- Data Scanned per Query
- Query Success Rate
- Cost per Query

**ECS (if applicable)**:
- CPU Utilization
- Memory Utilization
- Task Count
- Target Response Time

### 11.2 Logging Strategy

**Lambda Logs** (`/aws/lambda/AthenaQueryLambda-*`):
```python
logger.info(f"Executing query: {query}")
logger.info(f"Query execution ID: {execution_id}")
logger.info(f"Query status: {status}")
logger.error(f"Query failed: {error_message}")
```

**Streamlit Application Logs**:
```
/home/ubuntu/app/streamlit_app/app.log
  - User queries
  - Response times
  - Error traces
```

**Athena Query History**:
- Accessible via AWS Console → Athena → Query History
- Programmatic access via `get_query_execution()` API

### 11.3 Alerting

**CloudWatch Alarms**:
1. **Lambda Errors > 5 in 5 minutes**: SNS notification
2. **Athena Query Failures > 10%**: Email alert
3. **ECS Target Response Time > 10s**: Auto-scaling trigger
4. **Bedrock Agent Throttling**: Quota increase request

---

## 12. CI/CD Pipeline

### 12.1 GitHub Actions Workflow

**Workflow File**: `.github/workflows/deploy.yml`

**Stages**:
```yaml
1. Validate (on PR and push)
   - Lint CloudFormation templates
   - Validate JSON/YAML syntax
   - Check IAM policy validity
   
2. Deploy to Dev (on push to main)
   - Deploy stack 1 (data layer)
   - Deploy stack 2 (compute layer)
   - Deploy stack 3 (frontend layer)
   - Run smoke tests
   
3. Deploy to Prod (manual trigger)
   - Require manual approval
   - Deploy to production account
   - Verify deployment
   - Rollback on failure
```

**Environment Variables**:
```yaml
env:
  AWS_REGION: eu-central-1
  ALIAS: txt2sql-dev
  ENVIRONMENT: dev
```

**Secrets Required**:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 12.2 Deployment Strategy

**Blue-Green Deployment** (ECS):
1. Deploy new task definition (green)
2. ALB routes traffic to green tasks
3. Monitor health checks
4. Deregister old tasks (blue)
5. Rollback if errors detected

**Rolling Deployment** (EC2):
1. Create new EC2 instance with updated code
2. Test new instance
3. Update DNS/load balancer to new instance
4. Terminate old instance

### 12.3 Testing Strategy

**Unit Tests**:
- Lambda function logic
- SQL query sanitization
- Response formatting

**Integration Tests**:
- End-to-end query flow
- Bedrock Agent invocation
- Athena query execution

**Smoke Tests** (post-deployment):
```bash
# Test 1: Agent reachability
aws bedrock-agent-runtime invoke-agent \
  --agent-id $AGENT_ID \
  --agent-alias-id $ALIAS_ID \
  --session-id test-session \
  --input-text "Hello"

# Test 2: Query execution
curl -X POST $API_ENDPOINT/chat \
  -H "Content-Type: application/json" \
  -d '{"question": "Count records in test_population"}'
```

---

## 13. Cost Optimization

### 13.1 Monthly Cost Breakdown (100k requests)

| Service | Usage | Cost (USD) | Optimization |
|---------|-------|------------|--------------|
| **Bedrock** | 700K tokens | $575 | Use Haiku model ($75 vs $575) |
| **Lambda** | 100K invocations | $0.20 | Optimize memory allocation |
| **Athena** | $5/TB scanned | <$1 | Use Parquet, partitioning |
| **S3** | 1.1 KB data | <$1 | Lifecycle policies |
| **EC2** | t3.small 24/7 | $17.74 | Use ECS with auto-scaling |
| **Data Transfer** | Minimal | <$1 | VPC endpoints |
| **Total** | - | **~$595** | **~$95 (optimized)** |

### 13.2 Cost Optimization Strategies

1. **Model Selection**:
   - Use Claude 3 Haiku instead of Sonnet for 90% cost reduction
   - Haiku: $0.25 per 1M input tokens (vs $3 for Sonnet)

2. **Compute Optimization**:
   - ECS auto-scaling: Scale to zero during off-hours
   - Lambda reserved concurrency: Only for predictable loads
   - Spot instances: 70% savings for non-critical workloads

3. **Data Optimization**:
   - Convert CSV to Parquet: 3-10x reduction in data scanned
   - Partition by date: Only scan relevant data
   - Compress with GZIP/Snappy: Reduce storage costs

4. **Query Optimization**:
   - Column pruning: Select only needed columns
   - Result caching: Reuse recent query results (24h)
   - Query timeout: Prevent runaway costs

5. **Architecture Optimization**:
   - App Runner: Pay only for active requests
   - S3 Intelligent-Tiering: Automatic cost optimization
   - VPC endpoints: Avoid data transfer charges

**Projected Optimized Monthly Cost**: **~$95** (85% reduction)

---

## Appendix A: Quick Start Checklist

```
□ Grant Bedrock model access (Claude 3 Haiku/Sonnet)
□ Clone repository
□ Configure AWS CLI (aws configure)
□ Set environment variables (AWS_REGION, ALIAS)
□ Run deployment script (./deploy.sh)
□ Upload data to S3 (./scripts/ingest_csv_to_athena.py)
□ Test agent via AWS Console → Bedrock → Agents
□ Access Streamlit UI (http://{ec2-public-ip}:8501)
□ Configure frontend API endpoint (lambda-proxy URL)
□ Set up CloudWatch alarms
□ Enable CloudTrail logging
□ Review IAM policies for least privilege
□ Document agent ID and alias ID
□ Create backup of CloudFormation parameters
```

---

## Appendix B: Troubleshooting Guide

### Common Issues

1. **Agent returns SQL instead of executing**:
   - Check instruction prompt includes "Always execute queries"
   - Verify action group Lambda has proper permissions
   - Review CloudWatch logs for Lambda errors

2. **Athena query timeout**:
   - Increase Lambda timeout (max 15 minutes)
   - Optimize query (add partitions, use WHERE clause)
   - Check data volume and complexity

3. **CORS errors in static frontend**:
   - Verify API Gateway CORS configuration
   - Check Access-Control-Allow-Origin header
   - Ensure OPTIONS preflight is handled

4. **Bedrock throttling errors**:
   - Request quota increase (10 TPS → 100 TPS)
   - Implement exponential backoff
   - Use SQS queue for rate limiting

5. **Lambda out of memory**:
   - Increase memory allocation (1024MB → 2048MB)
   - Optimize result set size
   - Implement pagination for large results

---

## Appendix C: Glossary

- **Action Group**: Bedrock Agent component defining executable tasks
- **Athena**: Serverless SQL query service for S3 data
- **Chain-of-Thought**: AI reasoning technique breaking down complex tasks
- **EMIR**: European Market Infrastructure Regulation (derivatives reporting)
- **Glue Data Catalog**: Metadata repository for Athena tables
- **OpenAPI Schema**: API specification format for action groups
- **SigV4**: AWS signature version 4 authentication protocol
- **Trino**: Distributed SQL query engine (Athena backend)
- **UTI**: Unique Transaction Identifier (EMIR requirement)

---

## Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-18 | System Architecture Team | Initial release |

---

**End of Document**
