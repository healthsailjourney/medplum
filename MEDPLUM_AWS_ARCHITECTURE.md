# Medplum AWS Cloud Architecture

**Version:** 1.0  
**Date:** December 7, 2025  
**Region:** ap-south-2 (Asia Pacific - Hyderabad)  
**Environment:** Development/Production

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Current Development Architecture](#current-development-architecture)
3. [Production Architecture (Recommended)](#production-architecture-recommended)
4. [Network Architecture](#network-architecture)
5. [Security Architecture](#security-architecture)
6. [Data Flow Diagrams](#data-flow-diagrams)
7. [High Availability Architecture](#high-availability-architecture)
8. [Disaster Recovery Architecture](#disaster-recovery-architecture)
9. [Cost Optimization Architecture](#cost-optimization-architecture)
10. [Monitoring & Logging Architecture](#monitoring--logging-architecture)

---

## Architecture Overview

### Design Principles

- **Scalability:** Auto-scaling capabilities for varying workloads
- **High Availability:** Multi-AZ deployment for fault tolerance
- **Security:** Defense in depth with multiple security layers
- **Performance:** Optimized data flow and caching strategies
- **Cost Efficiency:** Right-sizing resources and utilizing reserved instances
- **Compliance:** HIPAA-ready infrastructure for healthcare data

---

## Current Development Architecture

### Single Instance Development Setup

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│                        AWS Region: ap-south-2                               │
│                     (Asia Pacific - Hyderabad)                              │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                          VPC (10.0.0.0/16)                            │ │
│  │                                                                       │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐ │ │
│  │  │              Availability Zone: ap-south-2a                     │ │ │
│  │  │                                                                 │ │ │
│  │  │  ┌───────────────────────────────────────────────────────────┐ │ │ │
│  │  │  │      Public Subnet (10.0.1.0/24)                          │ │ │ │
│  │  │  │                                                           │ │ │ │
│  │  │  │  ┌─────────────────────────────────────────────────────┐ │ │ │ │
│  │  │  │  │                                                     │ │ │ │ │
│  │  │  │  │   EC2 Instance (t3.xlarge)                         │ │ │ │ │
│  │  │  │  │   ID: i-0fb6659bcf6a77951                          │ │ │ │ │
│  │  │  │  │   Private IP: 10.0.1.45                            │ │ │ │ │
│  │  │  │  │                                                     │ │ │ │ │
│  │  │  │  │   ┌─────────────────────────────────────────┐     │ │ │ │ │
│  │  │  │  │   │  Medplum Web App (Port 3000)            │     │ │ │ │ │
│  │  │  │  │   │  - React Frontend                       │     │ │ │ │ │
│  │  │  │  │   │  - Node.js 22.x                         │     │ │ │ │ │
│  │  │  │  │   └─────────────────────────────────────────┘     │ │ │ │ │
│  │  │  │  │                       ↓                            │ │ │ │ │
│  │  │  │  │   ┌─────────────────────────────────────────┐     │ │ │ │ │
│  │  │  │  │   │  Medplum API Server (Port 8103)         │     │ │ │ │ │
│  │  │  │  │   │  - REST API                             │     │ │ │ │ │
│  │  │  │  │   │  - FHIR R4 Compliant                    │     │ │ │ │ │
│  │  │  │  │   │  - Node.js Express                      │     │ │ │ │ │
│  │  │  │  │   └─────────────────────────────────────────┘     │ │ │ │ │
│  │  │  │  │          ↓                    ↓                   │ │ │ │ │
│  │  │  │  │   ┌──────────────┐    ┌──────────────┐           │ │ │ │ │
│  │  │  │  │   │ PostgreSQL   │    │   Redis      │           │ │ │ │ │
│  │  │  │  │   │   (Docker)   │    │  (Docker)    │           │ │ │ │ │
│  │  │  │  │   │   Port 5432  │    │  Port 6379   │           │ │ │ │ │
│  │  │  │  │   │  Version 16  │    │  Version 7   │           │ │ │ │ │
│  │  │  │  │   └──────────────┘    └──────────────┘           │ │ │ │ │
│  │  │  │  │                                                     │ │ │ │ │
│  │  │  │  │   Storage: 100 GB EBS (gp3, encrypted)            │ │ │ │ │
│  │  │  │  │                                                     │ │ │ │ │
│  │  │  │  └─────────────────────────────────────────────────────┘ │ │ │ │
│  │  │  │                                                           │ │ │ │
│  │  │  │      Security Group: sg-03a819f7bdb78369e               │ │ │ │
│  │  │  │      ┌─────────────────────────────────────┐            │ │ │ │
│  │  │  │      │  Inbound Rules:                     │            │ │ │ │
│  │  │  │      │  - SSH (22)         ← 0.0.0.0/0     │            │ │ │ │
│  │  │  │      │  - HTTP (3000)      ← 0.0.0.0/0     │            │ │ │ │
│  │  │  │      │  - API (8103)       ← 0.0.0.0/0     │            │ │ │ │
│  │  │  │      │  - VS Code (8080)   ← 0.0.0.0/0     │            │ │ │ │
│  │  │  │      └─────────────────────────────────────┘            │ │ │ │
│  │  │  │                                                           │ │ │ │
│  │  │  └───────────────────────────────────────────────────────────┘ │ │ │
│  │  │                                                                 │ │ │
│  │  └─────────────────────────────────────────────────────────────────┘ │ │
│  │                                                                       │ │
│  │  ┌─────────────────────────────────────────────────────────────────┐ │ │
│  │  │                    Internet Gateway                             │ │ │
│  │  │                   igw-028e6d69cc5286b72                         │ │ │
│  │  └─────────────────────────────────────────────────────────────────┘ │ │
│  │                                ↕                                      │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                   ↕                                        │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                      Elastic IP: 16.112.103.205                     │  │
│  │                   Allocation: eipalloc-00dea5a54e99446d7            │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                                   ↕
                          ┌──────────────────┐
                          │   Internet       │
                          │   Users          │
                          └──────────────────┘
```

### Current Architecture Components

| Layer | Component | Technology | Purpose |
|-------|-----------|------------|---------|
| **Presentation** | Web App | React, Node.js | User interface |
| **Application** | API Server | Node.js, Express | Business logic, FHIR API |
| **Data** | PostgreSQL | Docker, PostgreSQL 16 | Persistent storage |
| **Cache** | Redis | Docker, Redis 7 | Session, cache management |
| **Network** | VPC | AWS VPC | Network isolation |
| **Compute** | EC2 | t3.xlarge | Application hosting |
| **Storage** | EBS | gp3, 100GB | Data persistence |

---

## Production Architecture (Recommended)

### Multi-Tier, High Availability Setup

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                         │
│                            AWS Region: ap-south-2                                       │
│                                                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                                 │   │
│  │                        Route 53 DNS                                             │   │
│  │                    medplum.yourdomain.com                                       │   │
│  │                                                                                 │   │
│  └────────────────────────────────────┬────────────────────────────────────────────┘   │
│                                       ↓                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                                 │   │
│  │                    CloudFront CDN (Optional)                                    │   │
│  │                  - Global Content Delivery                                      │   │
│  │                  - SSL/TLS Termination                                          │   │
│  │                  - DDoS Protection                                              │   │
│  │                                                                                 │   │
│  └────────────────────────────────────┬────────────────────────────────────────────┘   │
│                                       ↓                                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                                                                                 │   │
│  │                          AWS WAF (Web Application Firewall)                     │   │
│  │                       - SQL Injection Protection                                │   │
│  │                       - XSS Protection                                          │   │
│  │                       - Rate Limiting                                           │   │
│  │                                                                                 │   │
│  └────────────────────────────────────┬────────────────────────────────────────────┘   │
│                                       ↓                                                 │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐  │
│  │                       VPC (10.0.0.0/16)                                          │  │
│  │                                                                                  │  │
│  │  ┌────────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                    Application Load Balancer                               │ │  │
│  │  │                    - SSL Termination (ACM)                                 │ │  │
│  │  │                    - Health Checks                                         │ │  │
│  │  │                    - Path-based Routing                                    │ │  │
│  │  └──────────────────────────┬──────────────────┬──────────────────────────────┘ │  │
│  │                             ↓                  ↓                                 │  │
│  │  ┌──────────────────────────────────────────────────────────────────────────┐   │  │
│  │  │         AZ: ap-south-2a          │         AZ: ap-south-2b              │   │  │
│  │  ├──────────────────────────────────┼──────────────────────────────────────┤   │  │
│  │  │                                  │                                      │   │  │
│  │  │  ┌─────────────────────────┐     │     ┌─────────────────────────┐      │   │  │
│  │  │  │   Public Subnet         │     │     │   Public Subnet         │      │   │  │
│  │  │  │   10.0.1.0/24           │     │     │   10.0.2.0/24           │      │   │  │
│  │  │  │                         │     │     │                         │      │   │  │
│  │  │  │  ┌──────────────────┐   │     │     │  ┌──────────────────┐   │      │   │  │
│  │  │  │  │  NAT Gateway     │   │     │     │  │  NAT Gateway     │   │      │   │  │
│  │  │  │  └──────────────────┘   │     │     │  └──────────────────┘   │      │   │  │
│  │  │  └─────────────────────────┘     │     └─────────────────────────┘      │   │  │
│  │  │              ↓                   │              ↓                        │   │  │
│  │  │  ┌─────────────────────────┐     │     ┌─────────────────────────┐      │   │  │
│  │  │  │   Private Subnet        │     │     │   Private Subnet        │      │   │  │
│  │  │  │   10.0.10.0/24          │     │     │   10.0.20.0/24          │      │   │  │
│  │  │  │                         │     │     │                         │      │   │  │
│  │  │  │  ┌──────────────────┐   │     │     │  ┌──────────────────┐   │      │   │  │
│  │  │  │  │ EC2 Auto Scaling │   │     │     │  │ EC2 Auto Scaling │   │      │   │  │
│  │  │  │  │                  │   │     │     │  │                  │   │      │   │  │
│  │  │  │  │ ┌──────────────┐ │   │     │     │  │ ┌──────────────┐ │   │      │   │  │
│  │  │  │  │ │ Web App      │ │   │     │     │  │ │ Web App      │ │   │      │   │  │
│  │  │  │  │ │ Instance 1   │ │   │     │     │  │ │ Instance 2   │ │   │      │   │  │
│  │  │  │  │ └──────────────┘ │   │     │     │  │ └──────────────┘ │   │      │   │  │
│  │  │  │  │ ┌──────────────┐ │   │     │     │  │ ┌──────────────┐ │   │      │   │  │
│  │  │  │  │ │ API Server   │ │   │     │     │  │ │ API Server   │ │   │      │   │  │
│  │  │  │  │ │ Instance 1   │ │   │     │     │  │ │ Instance 2   │ │   │      │   │  │
│  │  │  │  │ └──────────────┘ │   │     │     │  │ └──────────────┘ │   │      │   │  │
│  │  │  │  └──────────────────┘   │     │     │  └──────────────────┘   │      │   │  │
│  │  │  └─────────────────────────┘     │     └─────────────────────────┘      │   │  │
│  │  │              ↓                   │              ↓                        │   │  │
│  │  │  ┌─────────────────────────┐     │     ┌─────────────────────────┐      │   │  │
│  │  │  │   Database Subnet       │     │     │   Database Subnet       │      │   │  │
│  │  │  │   10.0.11.0/24          │     │     │   10.0.21.0/24          │      │   │  │
│  │  │  │                         │     │     │                         │      │   │  │
│  │  │  │  ┌──────────────────┐   │     │     │  ┌──────────────────┐   │      │   │  │
│  │  │  │  │  RDS PostgreSQL  │◄──┼─────┼────►│  │  RDS PostgreSQL  │   │      │   │  │
│  │  │  │  │     Primary      │   │     │     │  │    Standby       │   │      │   │  │
│  │  │  │  │   Multi-AZ       │   │     │     │  │  (Sync Replica)  │   │      │   │  │
│  │  │  │  └──────────────────┘   │     │     │  └──────────────────┘   │      │   │  │
│  │  │  │                         │     │     │                         │      │   │  │
│  │  │  │  ┌──────────────────┐   │     │     │  ┌──────────────────┐   │      │   │  │
│  │  │  │  │ ElastiCache      │   │     │     │  │ ElastiCache      │   │      │   │  │
│  │  │  │  │   Redis          │◄──┼─────┼────►│  │   Redis          │   │      │   │  │
│  │  │  │  │  Cluster Mode    │   │     │     │  │  Replica Node    │   │      │   │  │
│  │  │  │  └──────────────────┘   │     │     │  └──────────────────┘   │      │   │  │
│  │  │  └─────────────────────────┘     │     └─────────────────────────┘      │   │  │
│  │  │                                  │                                      │   │  │
│  │  └──────────────────────────────────┴──────────────────────────────────────┘   │  │
│  │                                                                                  │  │
│  │  ┌────────────────────────────────────────────────────────────────────────────┐ │  │
│  │  │                         S3 Buckets                                         │ │  │
│  │  │  - medplum-files (FHIR Binary resources, medical images)                  │ │  │
│  │  │  - medplum-backups (Automated backups)                                    │ │  │
│  │  │  - medplum-logs (Application & access logs)                               │ │  │
│  │  │  - Versioning Enabled, Encryption at Rest (KMS)                           │ │  │
│  │  └────────────────────────────────────────────────────────────────────────────┘ │  │
│  │                                                                                  │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                         │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐  │
│  │                        Supporting Services                                       │  │
│  │                                                                                  │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐                │  │
│  │  │  CloudWatch     │  │   Secrets       │  │   KMS            │                │  │
│  │  │  - Metrics      │  │   Manager       │  │   - Encryption   │                │  │
│  │  │  - Logs         │  │   - DB Creds    │  │   - Key Mgmt     │                │  │
│  │  │  - Alarms       │  │   - API Keys    │  │                  │                │  │
│  │  └─────────────────┘  └─────────────────┘  └──────────────────┘                │  │
│  │                                                                                  │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐                │  │
│  │  │  Systems        │  │   IAM           │  │   AWS Backup     │                │  │
│  │  │  Manager        │  │   - Roles       │  │   - Automated    │                │  │
│  │  │  - Patching     │  │   - Policies    │  │   - Scheduled    │                │  │
│  │  │  - Session Mgr  │  │   - Users       │  │                  │                │  │
│  │  └─────────────────┘  └─────────────────┘  └──────────────────┘                │  │
│  │                                                                                  │  │
│  └──────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### Production Components

| Component | Service | Configuration | Purpose |
|-----------|---------|---------------|---------|
| **DNS** | Route 53 | Multi-region failover | Domain management |
| **CDN** | CloudFront | Edge locations | Global content delivery |
| **WAF** | AWS WAF | Custom rules | Security filtering |
| **Load Balancer** | ALB | Multi-AZ | Traffic distribution |
| **Compute** | EC2 Auto Scaling | Min: 2, Max: 10 | Horizontal scaling |
| **Database** | RDS PostgreSQL | Multi-AZ, db.r6g.2xlarge | Primary data store |
| **Cache** | ElastiCache Redis | Cluster mode | Session & cache |
| **Storage** | S3 | Standard, versioned | Object storage |
| **Monitoring** | CloudWatch | Custom metrics | Observability |
| **Secrets** | Secrets Manager | Automatic rotation | Credential management |
| **Encryption** | KMS | Customer managed keys | Data encryption |
| **Backup** | AWS Backup | Daily snapshots | Disaster recovery |

---

## Network Architecture

### VPC Network Design

```
┌────────────────────────────────────────────────────────────────────────────┐
│                        VPC: 10.0.0.0/16                                    │
│                                                                            │
│  ┌──────────────────────────────────────────────────────────────────────┐ │
│  │                    Internet Gateway                                  │ │
│  └────────────────────────────┬─────────────────────────────────────────┘ │
│                               ↓                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                      Public Subnets                                 │  │
│  │  ┌──────────────────────┐         ┌──────────────────────┐          │  │
│  │  │  AZ-A: 10.0.1.0/24   │         │  AZ-B: 10.0.2.0/24   │          │  │
│  │  │  - NAT Gateway       │         │  - NAT Gateway       │          │  │
│  │  │  - Bastion Host      │         │  - Bastion Host      │          │  │
│  │  │  - ALB               │         │  - ALB               │          │  │
│  │  └──────────────────────┘         └──────────────────────┘          │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                               ↓                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                    Private Subnets (Application)                    │  │
│  │  ┌──────────────────────┐         ┌──────────────────────┐          │  │
│  │  │  AZ-A: 10.0.10.0/24  │         │  AZ-B: 10.0.20.0/24  │          │  │
│  │  │  - EC2 Instances     │         │  - EC2 Instances     │          │  │
│  │  │  - App Servers       │         │  - App Servers       │          │  │
│  │  │  - API Servers       │         │  - API Servers       │          │  │
│  │  └──────────────────────┘         └──────────────────────┘          │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                               ↓                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                    Private Subnets (Database)                       │  │
│  │  ┌──────────────────────┐         ┌──────────────────────┐          │  │
│  │  │  AZ-A: 10.0.11.0/24  │         │  AZ-B: 10.0.21.0/24  │          │  │
│  │  │  - RDS Primary       │         │  - RDS Standby       │          │  │
│  │  │  - ElastiCache       │         │  - ElastiCache       │          │  │
│  │  │  - No Internet       │         │  - No Internet       │          │  │
│  │  └──────────────────────┘         └──────────────────────┘          │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐  │
│  │                    VPC Endpoints (Optional)                         │  │
│  │  - S3 Gateway Endpoint                                              │  │
│  │  - DynamoDB Gateway Endpoint                                        │  │
│  │  - Interface Endpoints (SSM, CloudWatch, Secrets Manager)          │  │
│  └─────────────────────────────────────────────────────────────────────┘  │
│                                                                            │
└────────────────────────────────────────────────────────────────────────────┘
```

### Network Security Layers

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Network Security Layers                         │
└────────────────────────────────────────────────────────────────────────┘

Layer 1: Internet Edge
├── CloudFront (DDoS Protection)
├── AWS Shield Standard
└── Route 53 (DNS Security)

Layer 2: Application Edge
├── AWS WAF (Web Application Firewall)
│   ├── SQL Injection Rules
│   ├── XSS Protection
│   ├── Rate Limiting
│   └── Geographic Restrictions
└── Application Load Balancer
    ├── SSL/TLS Termination (ACM)
    └── Security Groups (ALB-SG)

Layer 3: Application Tier
├── Security Groups (App-SG)
│   ├── Allow: ALB → EC2 (3000, 8103)
│   ├── Deny: All other inbound
│   └── Allow: All outbound
└── Network ACLs
    ├── Subnet-level filtering
    └── Stateless rules

Layer 4: Data Tier
├── Security Groups (DB-SG)
│   ├── Allow: App-SG → RDS (5432)
│   ├── Allow: App-SG → Redis (6379)
│   └── Deny: All other inbound
├── RDS Encryption at Rest (KMS)
└── VPC Isolation (No public IPs)

Layer 5: Data Storage
├── S3 Bucket Policies
│   ├── Encryption at rest (KMS)
│   ├── Encryption in transit (TLS)
│   └── Versioning enabled
└── IAM Policies
    ├── Least privilege access
    └── MFA required for sensitive operations
```

---

## Security Architecture

### Defense in Depth Strategy

```
┌────────────────────────────────────────────────────────────────────────┐
│                                                                        │
│                   External Threat Landscape                            │
│                                                                        │
└────────────────────────────────┬───────────────────────────────────────┘
                                 ↓
┌────────────────────────────────────────────────────────────────────────┐
│  Layer 1: Edge Security                                                │
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │ • AWS Shield (DDoS)                                              │ │
│  │ • Route 53 (DNS security)                                        │ │
│  │ • CloudFront (Edge caching, geo-blocking)                        │ │
│  └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────┬───────────────────────────────────────┘
                                 ↓
┌────────────────────────────────────────────────────────────────────────┐
│  Layer 2: Perimeter Security                                           │
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │ • AWS WAF (OWASP Top 10 protection)                              │ │
│  │ • SSL/TLS Termination (ACM certificates)                         │ │
│  │ • IP whitelisting / blacklisting                                 │ │
│  └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────┬───────────────────────────────────────┘
                                 ↓
┌────────────────────────────────────────────────────────────────────────┐
│  Layer 3: Network Security                                             │
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │ • VPC Isolation                                                  │ │
│  │ • Security Groups (stateful firewall)                            │ │
│  │ • Network ACLs (stateless firewall)                              │ │
│  │ • Private Subnets (no direct internet access)                    │ │
│  │ • VPC Flow Logs (network monitoring)                             │ │
│  └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────┬───────────────────────────────────────┘
                                 ↓
┌────────────────────────────────────────────────────────────────────────┐
│  Layer 4: Application Security                                         │
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │ • IAM Roles & Policies (least privilege)                         │ │
│  │ • Application-level authentication (OAuth 2.0, SMART on FHIR)   │ │
│  │ • API rate limiting                                              │ │
│  │ • Input validation & sanitization                                │ │
│  │ • Security headers (HSTS, CSP, X-Frame-Options)                  │ │
│  └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────┬───────────────────────────────────────┘
                                 ↓
┌────────────────────────────────────────────────────────────────────────┐
│  Layer 5: Data Security                                                │
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │ • Encryption at Rest (KMS)                                       │ │
│  │   - RDS PostgreSQL (AES-256)                                     │ │
│  │   - EBS Volumes (AES-256)                                        │ │
│  │   - S3 Buckets (SSE-KMS)                                         │ │
│  │ • Encryption in Transit (TLS 1.2+)                               │ │
│  │ • Database access controls                                       │ │
│  │ • Secrets Manager (credential rotation)                          │ │
│  │ • Audit logging (CloudTrail, CloudWatch)                         │ │
│  └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────┬───────────────────────────────────────┘
                                 ↓
┌────────────────────────────────────────────────────────────────────────┐
│  Layer 6: Monitoring & Response                                        │
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │ • CloudWatch Alarms (anomaly detection)                          │ │
│  │ • GuardDuty (threat detection)                                   │ │
│  │ • Security Hub (compliance monitoring)                           │ │
│  │ • AWS Config (configuration compliance)                          │ │
│  │ • CloudTrail (audit trail)                                       │ │
│  │ • SNS Notifications (security alerts)                            │ │
│  └──────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────┘
```

### HIPAA Compliance Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                   HIPAA Compliance Requirements                        │
└────────────────────────────────────────────────────────────────────────┘

1. Administrative Safeguards
   ├── IAM Users with MFA
   ├── Role-based access control (RBAC)
   ├── AWS Organizations for account management
   ├── Regular security training
   └── Incident response procedures

2. Physical Safeguards
   ├── AWS data centers (SOC 2 compliant)
   ├── Physical access controls (AWS managed)
   └── Workstation security policies

3. Technical Safeguards
   ├── Access Control
   │   ├── Unique user IDs (IAM)
   │   ├── Emergency access procedures
   │   ├── Automatic logoff (session timeout)
   │   └── Encryption & decryption (KMS)
   │
   ├── Audit Controls
   │   ├── CloudTrail (all API calls)
   │   ├── VPC Flow Logs (network traffic)
   │   ├── CloudWatch Logs (application logs)
   │   └── Access logging (S3, RDS, ALB)
   │
   ├── Integrity Controls
   │   ├── Data validation
   │   ├── Digital signatures
   │   └── Hash verification
   │
   └── Transmission Security
       ├── TLS 1.2+ for all connections
       ├── VPN for administrative access
       └── PrivateLink for AWS services

4. PHI Data Handling
   ├── Encrypted at rest (AES-256)
   ├── Encrypted in transit (TLS)
   ├── Access logging for all PHI access
   ├── Data retention policies
   └── Secure data disposal (S3 lifecycle, RDS snapshots)

5. Business Associate Agreement (BAA)
   ├── Sign BAA with AWS
   ├── Use only BAA-eligible services:
   │   ├── EC2, EBS, VPC ✓
   │   ├── RDS, S3 ✓
   │   ├── ELB, CloudWatch ✓
   │   ├── ElastiCache ✓
   │   └── KMS, Secrets Manager ✓
   └── Regular compliance audits
```

---

## Data Flow Diagrams

### User Authentication Flow

```
┌─────────┐
│  User   │
│ Browser │
└────┬────┘
     │
     │ 1. HTTPS Request (Login)
     ↓
┌────────────────┐
│  CloudFront    │
│  (Optional)    │
└────┬───────────┘
     │
     │ 2. Forward to ALB
     ↓
┌────────────────┐
│  ALB + WAF     │
│  SSL Terminate │
└────┬───────────┘
     │
     │ 3. Route to API Server
     ↓
┌──────────────────────────┐
│  Medplum API Server      │
│  (EC2 Auto Scaling)      │
│                          │
│  ┌────────────────────┐  │
│  │ 4. Validate OAuth  │  │
│  │    SMART on FHIR   │  │
│  └─────────┬──────────┘  │
│            ↓             │
│  ┌────────────────────┐  │
│  │ 5. Query User DB   │  │
│  └─────────┬──────────┘  │
└────────────┼─────────────┘
             │
             │ 6. Database Query
             ↓
┌──────────────────────────┐
│  RDS PostgreSQL          │
│  (Multi-AZ)              │
│  ┌────────────────────┐  │
│  │ Users Table        │  │
│  │ - username         │  │
│  │ - password_hash    │  │
│  │ - mfa_secret       │  │
│  └─────────┬──────────┘  │
└────────────┼─────────────┘
             │
             │ 7. Return User Data
             ↓
┌──────────────────────────┐
│  Medplum API Server      │
│  ┌────────────────────┐  │
│  │ 8. Create Session  │  │
│  │    Generate JWT    │  │
│  └─────────┬──────────┘  │
└────────────┼─────────────┘
             │
             │ 9. Store Session
             ↓
┌──────────────────────────┐
│  ElastiCache Redis       │
│  ┌────────────────────┐  │
│  │ Session Store      │  │
│  │ - session_id       │  │
│  │ - user_id          │  │
│  │ - expiry (TTL)     │  │
│  └────────────────────┘  │
└──────────────────────────┘
             │
             │ 10. Return JWT Token
             ↓
┌─────────┐
│  User   │
│ Browser │
│ (Store  │
│  JWT)   │
└─────────┘
```

### FHIR Resource Request Flow

```
┌─────────┐
│  User   │
│ Browser │
└────┬────┘
     │
     │ 1. GET /fhir/Patient/123
     │    Authorization: Bearer <JWT>
     ↓
┌────────────────┐
│  ALB           │
└────┬───────────┘
     │
     │ 2. Route to API
     ↓
┌──────────────────────────┐
│  Medplum API Server      │
│  ┌────────────────────┐  │
│  │ 3. Validate JWT    │  │
│  └─────────┬──────────┘  │
│            ↓             │
│  ┌────────────────────┐  │
│  │ 4. Check Session   │◄─┼─── ElastiCache Redis
│  └─────────┬──────────┘  │         (Session Cache)
│            ↓             │
│  ┌────────────────────┐  │
│  │ 5. Authorize       │  │
│  │    (RBAC/ABAC)     │  │
│  └─────────┬──────────┘  │
│            ↓             │
│  ┌────────────────────┐  │
│  │ 6. Check Cache     │◄─┼─── ElastiCache Redis
│  └─────────┬──────────┘  │         (Data Cache)
│            │             │
│            │ Cache Miss  │
│            ↓             │
│  ┌────────────────────┐  │
│  │ 7. Query Database  │  │
│  └─────────┬──────────┘  │
└────────────┼─────────────┘
             │
             │ 8. SELECT * FROM Patient WHERE id=123
             ↓
┌──────────────────────────┐
│  RDS PostgreSQL          │
│  ┌────────────────────┐  │
│  │ Patient Resource   │  │
│  │ (FHIR JSON)        │  │
│  └─────────┬──────────┘  │
└────────────┼─────────────┘
             │
             │ 9. Return Patient Data
             ↓
┌──────────────────────────┐
│  Medplum API Server      │
│  ┌────────────────────┐  │
│  │ 10. Store in Cache │──┼──► ElastiCache Redis
│  └─────────┬──────────┘  │         (TTL: 5 min)
│            ↓             │
│  ┌────────────────────┐  │
│  │ 11. Return FHIR    │  │
│  │     Resource       │  │
│  └─────────┬──────────┘  │
└────────────┼─────────────┘
             │
             │ 12. FHIR JSON Response
             ↓
┌─────────┐
│  User   │
│ Browser │
└─────────┘
```

### File Upload Flow (Medical Images)

```
┌─────────┐
│  User   │
│ Browser │
└────┬────┘
     │
     │ 1. POST /fhir/Binary (Image File)
     ↓
┌────────────────┐
│  ALB           │
└────┬───────────┘
     │
     │ 2. Route to API
     ↓
┌──────────────────────────┐
│  Medplum API Server      │
│  ┌────────────────────┐  │
│  │ 3. Validate Auth   │  │
│  └─────────┬──────────┘  │
│            ↓             │
│  ┌────────────────────┐  │
│  │ 4. Generate S3     │  │
│  │    Presigned URL   │  │
│  └─────────┬──────────┘  │
└────────────┼─────────────┘
             │
             │ 5. Return Presigned URL
             ↓
┌─────────┐
│  User   │
│ Browser │
└────┬────┘
     │
     │ 6. PUT to S3 (Direct Upload)
     ↓
┌──────────────────────────┐
│  S3 Bucket               │
│  medplum-files           │
│  ┌────────────────────┐  │
│  │ 7. Store File      │  │
│  │    (Encrypted)     │  │
│  └─────────┬──────────┘  │
│            │             │
│  ┌─────────▼──────────┐  │
│  │ 8. Trigger Lambda  │  │
│  │    (Optional)      │  │
│  │  - Virus scan      │  │
│  │  - Generate        │  │
│  │    thumbnails      │  │
│  │  - Extract metadata│  │
│  └─────────┬──────────┘  │
└────────────┼─────────────┘
             │
             │ 9. Update metadata
             ↓
┌──────────────────────────┐
│  Medplum API Server      │
│  ┌────────────────────┐  │
│  │ 10. Create Binary  │  │
│  │     Resource in DB │  │
│  └─────────┬──────────┘  │
└────────────┼─────────────┘
             │
             │ 11. INSERT INTO Binary
             ↓
┌──────────────────────────┐
│  RDS PostgreSQL          │
│  ┌────────────────────┐  │
│  │ Binary Resource    │  │
│  │ - id               │  │
│  │ - contentType      │  │
│  │ - s3_url           │  │
│  │ - size             │  │
│  └────────────────────┘  │
└──────────────────────────┘
```

---

## High Availability Architecture

### Multi-AZ Failover Strategy

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Normal Operation (Both AZs Active)                   │
└────────────────────────────────────────────────────────────────────────┘

                          ┌──────────────┐
                          │     ALB      │
                          │  (Active)    │
                          └───┬──────┬───┘
                              │      │
                 ┌────────────┘      └────────────┐
                 │                                │
                 ↓                                ↓
     ┌────────────────────┐            ┌────────────────────┐
     │   AZ-A (Primary)   │            │  AZ-B (Secondary)  │
     │                    │            │                    │
     │  ┌──────────────┐  │            │  ┌──────────────┐  │
     │  │  EC2 x2      │  │            │  │  EC2 x2      │  │
     │  │  (Active)    │  │            │  │  (Active)    │  │
     │  └──────┬───────┘  │            │  └──────┬───────┘  │
     │         ↓          │            │         ↓          │
     │  ┌──────────────┐  │            │  ┌──────────────┐  │
     │  │ RDS Primary  │◄─┼────────────┼─►│ RDS Standby  │  │
     │  │  (Active)    │  │  Sync      │  │  (Standby)   │  │
     │  └──────────────┘  │  Repl.     │  └──────────────┘  │
     │                    │            │                    │
     │  ┌──────────────┐  │            │  ┌──────────────┐  │
     │  │ Redis Primary│◄─┼────────────┼─►│ Redis Replica│  │
     │  │  (Active)    │  │  Async     │  │  (Active)    │  │
     │  └──────────────┘  │  Repl.     │  └──────────────┘  │
     └────────────────────┘            └────────────────────┘

┌────────────────────────────────────────────────────────────────────────┐
│                   AZ-A Failure (Automatic Failover)                    │
└────────────────────────────────────────────────────────────────────────┘

                          ┌──────────────┐
                          │     ALB      │
                          │  (Active)    │
                          └──────┬───────┘
                                 │
                                 │  (All traffic to AZ-B)
                                 ↓
     ┌────────────────────┐            ┌────────────────────┐
     │   AZ-A (FAILED)    │            │  AZ-B (Active)     │
     │                    │            │                    │
     │  ┌──────────────┐  │            │  ┌──────────────┐  │
     │  │  EC2 x2      │  │            │  │  EC2 x4      │  │
     │  │  (OFFLINE)   │  │            │  │  (Scaled Up) │  │
     │  └──────────────┘  │            │  └──────┬───────┘  │
     │         X          │            │         ↓          │
     │  ┌──────────────┐  │            │  ┌──────────────┐  │
     │  │ RDS Primary  │  │   Auto     │  │ RDS Standby  │  │
     │  │  (OFFLINE)   │  │  Promote   │  │  → PRIMARY   │  │
     │  └──────────────┘  │            │  └──────────────┘  │
     │                    │            │                    │
     │  ┌──────────────┐  │            │  ┌──────────────┐  │
     │  │ Redis Primary│  │            │  │ Redis Replica│  │
     │  │  (OFFLINE)   │  │            │  │  → PRIMARY   │  │
     │  └──────────────┘  │            │  └──────────────┘  │
     └────────────────────┘            └────────────────────┘

     Failover Process:
     1. Health check fails (30 seconds)
     2. ALB stops routing to AZ-A
     3. Auto Scaling launches new instances in AZ-B
     4. RDS automatically promotes standby
     5. Redis cluster elects new primary
     6. Total downtime: < 2 minutes
```

### Auto Scaling Configuration

```
┌────────────────────────────────────────────────────────────────────────┐
│                     Auto Scaling Group Configuration                  │
└────────────────────────────────────────────────────────────────────────┘

Scaling Policy: Target Tracking

┌─────────────────────────────────────────────────────────────────┐
│  Metrics                                                        │
│                                                                 │
│  1. CPU Utilization                                             │
│     Target: 70%                                                 │
│     Scale Out: When avg > 70% for 2 minutes                     │
│     Scale In:  When avg < 50% for 5 minutes                     │
│                                                                 │
│  2. Request Count per Target                                    │
│     Target: 1000 requests/target                                │
│     Scale Out: When > 1000 for 2 minutes                        │
│     Scale In:  When < 500 for 5 minutes                         │
│                                                                 │
│  3. Memory Utilization (Custom Metric)                          │
│     Target: 80%                                                 │
│     Scale Out: When avg > 80% for 2 minutes                     │
│     Scale In:  When avg < 60% for 5 minutes                     │
└─────────────────────────────────────────────────────────────────┘

Instance Configuration:
┌─────────────────────────────────────────────────────────────────┐
│  Minimum Instances:     2  (1 per AZ)                           │
│  Desired Instances:     4  (2 per AZ)                           │
│  Maximum Instances:    10  (5 per AZ)                           │
│  Health Check Grace:  300 seconds                               │
│  Cooldown Period:     300 seconds                               │
└─────────────────────────────────────────────────────────────────┘

Scaling Timeline Example:

Time    | CPU  | Instances | Action
--------|------|-----------|---------------------------
00:00   | 45%  |     4     | Normal operation
00:30   | 75%  |     4     | CPU exceeds threshold
00:32   | 76%  |     6     | Scale out +2 instances
00:35   | 60%  |     6     | Stabilizing
01:00   | 45%  |     6     | Below scale-in threshold
01:06   | 43%  |     4     | Scale in -2 instances
```

---

## Disaster Recovery Architecture

### Backup Strategy

```
┌────────────────────────────────────────────────────────────────────────┐
│                         Backup & Recovery Strategy                     │
└────────────────────────────────────────────────────────────────────────┘

1. RDS Automated Backups
   ┌─────────────────────────────────────────────────────────────┐
   │  • Frequency: Daily snapshots                               │
   │  • Retention: 30 days                                       │
   │  • Backup Window: 03:00-04:00 UTC (low traffic)             │
   │  • Transaction Logs: Every 5 minutes                        │
   │  • Point-in-Time Recovery: Within retention period          │
   │  • Storage: Cross-region replication to DR region           │
   └─────────────────────────────────────────────────────────────┘

2. EBS Snapshots (EC2 Volumes)
   ┌─────────────────────────────────────────────────────────────┐
   │  • Frequency: Daily via AWS Backup                          │
   │  • Retention: 14 days                                       │
   │  • Lifecycle: Move to cold storage after 7 days             │
   │  • Cross-region copy: To DR region                          │
   └─────────────────────────────────────────────────────────────┘

3. S3 Bucket Versioning & Replication
   ┌─────────────────────────────────────────────────────────────┐
   │  • Versioning: Enabled on all buckets                       │
   │  • Replication: Cross-region to DR region                   │
   │  • Lifecycle:                                               │
   │    - Standard: 0-90 days                                    │
   │    - Infrequent Access: 90-365 days                         │
   │    - Glacier: > 365 days                                    │
   │  • MFA Delete: Enabled for production                       │
   └─────────────────────────────────────────────────────────────┘

4. Configuration Backups
   ┌─────────────────────────────────────────────────────────────┐
   │  • Terraform State: S3 backend with versioning              │
   │  • Application Config: Stored in Git repository             │
   │  • Secrets: AWS Secrets Manager with replication            │
   │  • AMI Images: Weekly snapshots of configured instances     │
   └─────────────────────────────────────────────────────────────┘
```

### Recovery Time & Point Objectives

```
┌────────────────────────────────────────────────────────────────────────┐
│                           RTO & RPO Targets                            │
└────────────────────────────────────────────────────────────────────────┘

Service          | RPO          | RTO          | Strategy
-----------------|--------------|--------------|-------------------------
Database (RDS)   | < 5 minutes  | < 15 minutes | Multi-AZ, auto failover
Application      | 0 (stateless)| < 10 minutes | Multi-AZ, auto scaling
Files (S3)       | < 1 hour     | < 5 minutes  | Cross-region replication
Cache (Redis)    | Acceptable   | < 5 minutes  | Multi-AZ cluster
                 | data loss    |              | (rebuild from DB)
Configuration    | < 24 hours   | < 30 minutes | Infrastructure as Code

Overall System   | < 5 minutes  | < 15 minutes | End-to-end

Disaster Scenarios & Recovery Steps:

1. AZ Failure
   - Detection: 30 seconds (health checks)
   - Automatic failover to standby AZ
   - RDS promotes replica: ~60 seconds
   - Total downtime: < 2 minutes ✓

2. Region Failure (Complete outage)
   - Manual failover to DR region
   - Steps:
     a. Promote RDS read replica (5 min)
     b. Update Route 53 DNS (2 min)
     c. Launch EC2 instances from AMI (8 min)
   - Total downtime: < 15 minutes ✓

3. Data Corruption
   - Restore from point-in-time backup
   - RDS PITR: < 5 minutes RPO
   - Recovery time: 15-30 minutes
   - Data loss: < 5 minutes ✓

4. Accidental Deletion
   - S3: Restore from versioning (immediate)
   - RDS: Restore from snapshot (10-15 min)
   - Total recovery: < 15 minutes ✓
```

---

## Cost Optimization Architecture

### Monthly Cost Breakdown (Production)

```
┌────────────────────────────────────────────────────────────────────────┐
│                    Estimated Monthly Costs (USD)                       │
└────────────────────────────────────────────────────────────────────────┘

Service                     | Configuration        | Monthly Cost
----------------------------|----------------------|---------------
EC2 Instances               | 4x t3.xlarge        | $496
  (Application Servers)     | (on-demand)         |
                            |                     |
RDS PostgreSQL              | db.r6g.2xlarge      | $520
  (Multi-AZ)                | Multi-AZ            |
                            |                     |
ElastiCache Redis           | cache.r6g.large     | $280
  (Cluster)                 | 2 nodes, Multi-AZ   |
                            |                     |
Application Load Balancer   | 1 ALB               | $25
  (ALB)                     | Standard            |
                            |                     |
EBS Storage                 | 400 GB gp3          | $40
  (EC2 volumes)             | 100 GB x 4          |
                            |                     |
S3 Storage                  | 500 GB Standard     | $12
  (Files & Backups)         | + Requests          |
                            |                     |
Data Transfer               | 1 TB egress         | $90
  (Internet & Inter-AZ)     |                     |
                            |                     |
Secrets Manager             | 10 secrets          | $4
                            |                     |
CloudWatch                  | Logs + Metrics      | $15
  (Monitoring)              |                     |
                            |                     |
Route 53                    | 1 hosted zone       | $1
                            |                     |
KMS                         | 2 keys              | $2
                            |                     |
VPC                         | NAT Gateway x2      | $90
                            |                     |
AWS Backup                  | 200 GB backup       | $10
                            |                     |
                            |                     |
----------------------------|----------------------|---------------
TOTAL (On-Demand)           |                     | ~$1,585/month
                            |                     |
With 1-Year Reserved:       |                     |
  EC2 (40% savings)         | -$198               |
  RDS (35% savings)         | -$182               |
----------------------------|----------------------|---------------
TOTAL (Reserved)            |                     | ~$1,205/month
                            |                     |
With 3-Year Reserved:       |                     |
  EC2 (60% savings)         | -$298               |
  RDS (55% savings)         | -$286               |
----------------------------|----------------------|---------------
TOTAL (3-Year Reserved)     |                     | ~$1,001/month
```

### Cost Optimization Strategies

```
┌────────────────────────────────────────────────────────────────────────┐
│                      Cost Optimization Techniques                      │
└────────────────────────────────────────────────────────────────────────┘

1. Compute Optimization
   ┌──────────────────────────────────────────────────────────────────┐
   │  • Reserved Instances (1-3 year commitment)                      │
   │    Savings: 40-60% vs on-demand                                  │
   │                                                                  │
   │  • Savings Plans (flexible commitment)                           │
   │    Savings: 30-50% vs on-demand                                  │
   │                                                                  │
   │  • Spot Instances (for non-critical workloads)                   │
   │    Savings: 70-90% vs on-demand                                  │
   │    Use cases: Batch processing, dev/test environments            │
   │                                                                  │
   │  • Auto Scaling (scale down during off-hours)                    │
   │    Schedule: Scale to min capacity 8pm-6am weekdays              │
   │    Savings: ~30% for predictable workloads                       │
   │                                                                  │
   │  • Graviton Instances (ARM-based)                                │
   │    m6g.xlarge vs m5.xlarge: ~20% cheaper                        │
   │    Requires: ARM-compatible application builds                   │
   └──────────────────────────────────────────────────────────────────┘

2. Storage Optimization
   ┌──────────────────────────────────────────────────────────────────┐
   │  • S3 Intelligent Tiering (automatic cost optimization)          │
   │    Savings: 30-70% on infrequently accessed data                │
   │                                                                  │
   │  • S3 Lifecycle Policies                                         │
   │    - Move to IA after 30 days                                    │
   │    - Move to Glacier after 90 days                               │
   │    - Delete after 365 days (if allowed)                          │
   │                                                                  │
   │  • EBS Volume Optimization                                       │
   │    - Delete unattached volumes                                   │
   │    - Snapshot and delete old volumes                             │
   │    - Use gp3 instead of gp2 (20% cheaper)                       │
   │                                                                  │
   │  • RDS Storage Autoscaling                                       │
   │    - Start with minimum needed capacity                          │
   │    - Auto-scale to prevent over-provisioning                     │
   └──────────────────────────────────────────────────────────────────┘

3. Network Optimization
   ┌──────────────────────────────────────────────────────────────────┐
   │  • VPC Endpoints (avoid NAT Gateway charges)                     │
   │    - S3 Gateway Endpoint: Free                                   │
   │    - DynamoDB Gateway Endpoint: Free                             │
   │    - Interface Endpoints: $7.20/month each                       │
   │    Savings: NAT Gateway = $45/month per AZ                       │
   │                                                                  │
   │  • CloudFront (reduce data transfer costs)                       │
   │    - CDN caching reduces origin requests                         │
   │    - Edge location delivery cheaper than direct                  │
   │    Savings: 30-50% on data transfer                             │
   │                                                                  │
   │  • Single NAT Gateway (dev/test only)                            │
   │    Use one NAT instead of two for non-prod                       │
   │    Savings: $45/month (but loses HA)                            │
   └──────────────────────────────────────────────────────────────────┘

4. Monitoring & Management
   ┌──────────────────────────────────────────────────────────────────┐
   │  • AWS Cost Explorer                                             │
   │    - Daily cost monitoring                                       │
   │    - Resource utilization analysis                               │
   │    - Anomaly detection alerts                                    │
   │                                                                  │
   │  • AWS Budgets                                                   │
   │    - Set monthly budget alerts                                   │
   │    - Automated actions (stop instances)                          │
   │                                                                  │
   │  • Trusted Advisor                                               │
   │    - Cost optimization recommendations                           │
   │    - Idle resource detection                                     │
   │    - Reserved Instance recommendations                           │
   │                                                                  │
   │  • Tags for Cost Allocation                                      │
   │    - Environment: dev/staging/prod                               │
   │    - Project: medplum                                            │
   │    - Team: engineering/ops                                       │
   └──────────────────────────────────────────────────────────────────┘

5. Development vs Production Costs
   ┌──────────────────────────────────────────────────────────────────┐
   │  Development Environment (Current):                              │
   │    1x t3.xlarge:                   $124/month                   │
   │    100 GB storage:                  $10/month                   │
   │    Minimal data transfer:           $10/month                   │
   │    Total:                          ~$144/month                  │
   │                                                                  │
   │  Production Environment (Estimated):                             │
   │    Full HA setup:                ~$1,585/month                  │
   │    With Reserved Instances:      ~$1,205/month                  │
   │                                                                  │
   │  Staging Environment (Recommended):                              │
   │    2x t3.large (cheaper):          $120/month                   │
   │    RDS db.t3.large:                $140/month                   │
   │    ElastiCache t3.micro:            $15/month                   │
   │    Total:                          ~$275/month                  │
   └──────────────────────────────────────────────────────────────────┘
```

---

## Monitoring & Logging Architecture

### Observability Stack

```
┌────────────────────────────────────────────────────────────────────────┐
│                         Monitoring & Logging                           │
└────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                          Application Layer                           │
│                                                                      │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐        │
│  │  Web App       │  │  API Server    │  │  Workers       │        │
│  │                │  │                │  │                │        │
│  │  • App logs    │  │  • API logs    │  │  • Job logs    │        │
│  │  • Error logs  │  │  • Access logs │  │  • Error logs  │        │
│  │  • Audit logs  │  │  • Audit logs  │  │                │        │
│  └────────┬───────┘  └────────┬───────┘  └────────┬───────┘        │
│           │                   │                   │                 │
│           └───────────────────┼───────────────────┘                 │
│                               ↓                                      │
│                    ┌──────────────────────┐                         │
│                    │  CloudWatch Agent    │                         │
│                    │  (Unified Agent)     │                         │
│                    └──────────┬───────────┘                         │
└───────────────────────────────┼──────────────────────────────────────┘
                                ↓
┌──────────────────────────────────────────────────────────────────────┐
│                      CloudWatch (Central Hub)                        │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  CloudWatch Logs                                               │ │
│  │  ┌──────────────────┐  ┌──────────────────┐                   │ │
│  │  │ /aws/ec2/app     │  │ /aws/rds/        │                   │ │
│  │  │ /aws/ec2/api     │  │ /aws/elasticache/│                   │ │
│  │  │ /aws/lambda/     │  │ /aws/alb/        │                   │ │
│  │  └──────────────────┘  └──────────────────┘                   │ │
│  │                                                                │ │
│  │  • Log retention: 30 days (configurable)                      │ │
│  │  • Log insights: SQL-like queries                             │ │
│  │  • Log exports: S3 for long-term storage                      │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  CloudWatch Metrics                                            │ │
│  │                                                                │ │
│  │  EC2 Metrics:                                                  │ │
│  │  • CPUUtilization                                              │ │
│  │  • DiskReadBytes / DiskWriteBytes                              │ │
│  │  • NetworkIn / NetworkOut                                      │ │
│  │  • StatusCheckFailed                                           │ │
│  │                                                                │ │
│  │  RDS Metrics:                                                  │ │
│  │  • DatabaseConnections                                         │ │
│  │  • ReadLatency / WriteLatency                                  │ │
│  │  • CPUUtilization                                              │ │
│  │  • FreeableMemory                                              │ │
│  │  • ReplicaLag                                                  │ │
│  │                                                                │ │
│  │  ElastiCache Metrics:                                          │ │
│  │  • CPUUtilization                                              │ │
│  │  • DatabaseMemoryUsagePercentage                               │ │
│  │  • Evictions                                                   │ │
│  │  • CacheHitRate                                                │ │
│  │                                                                │ │
│  │  ALB Metrics:                                                  │ │
│  │  • TargetResponseTime                                          │ │
│  │  • RequestCount                                                │ │
│  │  • HTTPCode_Target_4XX_Count                                   │ │
│  │  • HTTPCode_Target_5XX_Count                                   │ │
│  │  • HealthyHostCount / UnhealthyHostCount                       │ │
│  │                                                                │ │
│  │  Custom Application Metrics:                                   │ │
│  │  • FHIR API Response Time                                      │ │
│  │  • Active Sessions                                             │ │
│  │  • Failed Logins                                               │ │
│  │  • Database Query Time                                         │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  CloudWatch Alarms                                             │ │
│  │                                                                │ │
│  │  Critical Alarms:                                              │ │
│  │  • EC2 CPU > 90% for 5 min          → SNS → PagerDuty         │ │
│  │  • RDS Connections > 90% max         → SNS → Email/Slack       │ │
│  │  • ALB 5XX errors > 10/min           → SNS → PagerDuty         │ │
│  │  • RDS Replica Lag > 30 seconds      → SNS → Email            │ │
│  │                                                                │ │
│  │  Warning Alarms:                                               │ │
│  │  • EC2 CPU > 70% for 10 min          → SNS → Slack            │ │
│  │  • Disk usage > 80%                  → SNS → Email            │ │
│  │  • Cache hit rate < 80%              → SNS → Email            │ │
│  │  • API latency > 1000ms (p95)        → SNS → Slack            │ │
│  └────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘
                                ↓
┌──────────────────────────────────────────────────────────────────────┐
│                        Alerting & Notifications                      │
│                                                                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │     SNS      │  │   Lambda     │  │  EventBridge │              │
│  │   Topics     │  │  Functions   │  │    Rules     │              │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │
│         │                 │                 │                       │
│         └─────────────────┼─────────────────┘                       │
│                           ↓                                          │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │  Notification Channels:                                        │ │
│  │  • Email (critical alerts)                                     │ │
│  │  • Slack (all alerts)                                          │ │
│  │  • PagerDuty (critical only, 24/7 on-call)                    │ │
│  │  • SMS (critical, executive team)                              │ │
│  └────────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                         Additional Monitoring                        │
│                                                                      │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │  CloudTrail      │  │  VPC Flow Logs   │  │  GuardDuty       │  │
│  │  (API Auditing)  │  │  (Network)       │  │  (Threat Detect) │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
│                                                                      │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐  │
│  │  AWS Config      │  │  Security Hub    │  │  X-Ray           │  │
│  │  (Compliance)    │  │  (Security)      │  │  (Tracing)       │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
```

### Dashboards

```
┌────────────────────────────────────────────────────────────────────────┐
│                    CloudWatch Dashboard - Overview                     │
└────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────┬─────────────────────────────────────────┐
│  System Health (Top Row)    │                                         │
├─────────────────────────────┼─────────────────────────────────────────┤
│                             │                                         │
│  ┌─────────────────────┐    │  ┌─────────────────────┐                │
│  │  Overall Status     │    │  │  Active Users       │                │
│  │  ● All Systems OK   │    │  │  ━━━━━━━━━━━━━━━━━ │                │
│  │  ✓ API: Healthy     │    │  │     1,234 users     │                │
│  │  ✓ DB:  Healthy     │    │  │  ┌───────────────┐  │                │
│  │  ✓ Cache: Healthy   │    │  │  │    █          │  │                │
│  └─────────────────────┘    │  │  │   ██  █       │  │                │
│                             │  │  │  ███ ███      │  │                │
│  ┌─────────────────────┐    │  │  └───────────────┘  │                │
│  │  Request Rate       │    │  │  Last 24 hours      │                │
│  │  5,234 req/min      │    │  └─────────────────────┘                │
│  │  ┌───────────────┐  │    │                                         │
│  │  │     ▄▄█       │  │    │  ┌─────────────────────┐                │
│  │  │   ▄███▄  ▄    │  │    │  │  Error Rate         │                │
│  │  │  ██████▄███   │  │    │  │  0.02% (2 of 10k)   │                │
│  │  └───────────────┘  │    │  │  ━━━━━━━━━━━━━━━━━ │                │
│  └─────────────────────┘    │  │  Target: < 0.1%     │                │
│                             │  └─────────────────────┘                │
└─────────────────────────────┴─────────────────────────────────────────┘

┌─────────────────────────────┬─────────────────────────────────────────┐
│  Infrastructure (Middle)    │                                         │
├─────────────────────────────┼─────────────────────────────────────────┤
│                             │                                         │
│  ┌─────────────────────┐    │  ┌─────────────────────┐                │
│  │  EC2 CPU Usage      │    │  │  RDS Connections    │                │
│  │  ━━━━━━━━━━━━━━━━━ │    │  │  ━━━━━━━━━━━━━━━━━ │                │
│  │      45%            │    │  │   45 / 100          │                │
│  │  ┌───────────────┐  │    │  │  ┌───────────────┐  │                │
│  │  │    ▄█▄  ▄█    │  │    │  │  │   ▄▄  ▄▄      │  │                │
│  │  │   ████▄███    │  │    │  │  │  ████████     │  │                │
│  │  │  █████████    │  │    │  │  │ █████████     │  │                │
│  │  └───────────────┘  │    │  │  └───────────────┘  │                │
│  │  Last hour          │    │  │  Last hour          │                │
│  └─────────────────────┘    │  └─────────────────────┘                │
│                             │                                         │
│  ┌─────────────────────┐    │  ┌─────────────────────┐                │
│  │  Memory Usage       │    │  │  Cache Hit Rate     │                │
│  │  ━━━━━━━━━━━━━━━━━ │    │  │  ━━━━━━━━━━━━━━━━━ │                │
│  │      62%            │    │  │      94.5%          │                │
│  │  12GB / 16GB        │    │  │  Target: > 90%      │                │
│  └─────────────────────┘    │  └─────────────────────┘                │
└─────────────────────────────┴─────────────────────────────────────────┘

┌─────────────────────────────┬─────────────────────────────────────────┐
│  Application (Bottom)       │                                         │
├─────────────────────────────┼─────────────────────────────────────────┤
│                             │                                         │
│  ┌─────────────────────┐    │  ┌─────────────────────┐                │
│  │  API Latency (p95)  │    │  │  Database Latency   │                │
│  │  ━━━━━━━━━━━━━━━━━ │    │  │  ━━━━━━━━━━━━━━━━━ │                │
│  │     234ms           │    │  │      12ms           │                │
│  │  ┌───────────────┐  │    │  │  ┌───────────────┐  │                │
│  │  │       ▄       │  │    │  │  │    ▄          │  │                │
│  │  │   ▄▄ ███ ▄    │  │    │  │  │   ██  ▄       │  │                │
│  │  │  ████████▄██  │  │    │  │  │  ████ ██      │  │                │
│  │  └───────────────┘  │    │  │  └───────────────┘  │                │
│  │  Last hour          │    │  │  Last hour          │                │
│  └─────────────────────┘    │  └─────────────────────┘                │
│                             │                                         │
│  ┌─────────────────────┐    │  ┌─────────────────────┐                │
│  │  HTTP Status Codes  │    │  │  Top 5 Endpoints    │                │
│  │  ━━━━━━━━━━━━━━━━━ │    │  │  ━━━━━━━━━━━━━━━━━ │                │
│  │  2xx: 9,845 (98%)   │    │  │  1. /fhir/Patient   │                │
│  │  4xx: 142 (1.4%)    │    │  │  2. /fhir/Obs...    │                │
│  │  5xx: 13 (0.1%)     │    │  │  3. /auth/login     │                │
│  └─────────────────────┘    │  │  4. /fhir/Prac...   │                │
│                             │  │  5. /healthcheck    │                │
│                             │  └─────────────────────┘                │
└─────────────────────────────┴─────────────────────────────────────────┘
```

---

## Summary

This architecture document provides a comprehensive view of:

1. **Current Development Setup**: Single instance, cost-effective for learning
2. **Production-Ready Architecture**: Multi-AZ, highly available, scalable
3. **Security**: Defense in depth, HIPAA-ready
4. **High Availability**: Multi-AZ failover, auto-scaling
5. **Disaster Recovery**: Automated backups, cross-region replication
6. **Cost Optimization**: Reserved instances, right-sizing, monitoring
7. **Observability**: Comprehensive monitoring, logging, alerting

### Next Steps

1. **Phase 1**: Current (Complete)
   - Single EC2 instance for development
   - Docker-based PostgreSQL and Redis
   - Basic security groups

2. **Phase 2**: Enhanced Development
   - Add RDS PostgreSQL (managed)
   - Add ElastiCache Redis (managed)
   - Implement CloudWatch monitoring

3. **Phase 3**: Staging Environment
   - Multi-AZ setup in separate VPC
   - Load balancer
   - Auto Scaling (min 2 instances)

4. **Phase 4**: Production
   - Full HA architecture
   - HIPAA compliance review
   - Disaster recovery testing
   - Performance optimization

---

**Document Version:** 1.0  
**Last Updated:** December 7, 2025  
**Maintained By:** Cloud Architecture Team
