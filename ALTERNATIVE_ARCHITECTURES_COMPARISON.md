# Alternative Architecture Patterns for Medplum

**Date:** December 7, 2025  
**Document Type:** Architecture Comparison & Analysis  
**Purpose:** Evaluate multiple architectural patterns for Medplum healthcare platform

---

## Table of Contents

1. [Architecture Patterns Overview](#architecture-patterns-overview)
2. [Pattern 1: Cell-Based Architecture](#pattern-1-cell-based-architecture)
3. [Pattern 2: Microservices Architecture](#pattern-2-microservices-architecture)
4. [Pattern 3: Serverless Architecture](#pattern-3-serverless-architecture)
5. [Pattern 4: Multi-Region Active-Active](#pattern-4-multi-region-active-active)
6. [Pattern 5: Kubernetes-Based (EKS)](#pattern-5-kubernetes-based-eks)
7. [Pattern 6: Hybrid Architecture](#pattern-6-hybrid-architecture)
8. [Pattern 7: Database Sharding (Horizontal Scaling)](#pattern-7-database-sharding-horizontal-scaling)
9. [Comparative Analysis](#comparative-analysis)
10. [Recommendations by Use Case](#recommendations-by-use-case)

---

## Architecture Patterns Overview

```
┌────────────────────────────────────────────────────────────────────────┐
│                  7 Architecture Patterns for Medplum                   │
└────────────────────────────────────────────────────────────────────────┘

1. Cell-Based Architecture
   • Isolated cells per region/tenant
   • Strong blast radius containment
   • Best for: Multi-tenant SaaS, healthcare compliance

2. Microservices Architecture
   • Services decomposed by domain (Patient, Practitioner, etc.)
   • Independent scaling per service
   • Best for: Complex business logic, team autonomy

3. Serverless Architecture
   • Lambda + API Gateway + DynamoDB
   • Auto-scaling, pay-per-use
   • Best for: Variable workloads, cost optimization

4. Multi-Region Active-Active
   • Multiple regions, all serving traffic
   • Global read/write capability
   • Best for: Global users, lowest latency

5. Kubernetes-Based (EKS)
   • Container orchestration
   • Portable across clouds
   • Best for: Complex deployments, multi-cloud strategy

6. Hybrid Architecture
   • Combination of multiple patterns
   • Best of both worlds
   • Best for: Large organizations, complex requirements

7. Database Sharding
   • Horizontal database partitioning
   • Tenant per shard
   • Best for: Massive scale, database bottlenecks
```

---

## Pattern 1: Cell-Based Architecture

*(Already covered in detail in AWS_CELL_ARCHITECTURE_ANALYSIS.md)*

### Quick Summary

```
┌────────────────────────────────────────────────────────────────────────┐
│                     Cell-Based Architecture                            │
└────────────────────────────────────────────────────────────────────────┘

Concept: Partition infrastructure into isolated cells

                    ┌──────────────┐
                    │  Route 53    │
                    └───────┬──────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   ┌────▼────┐         ┌───▼────┐         ┌───▼────┐
   │ Cell 1  │         │ Cell 2 │         │ Cell 3 │
   │ (Full   │         │ (Full  │         │ (Full  │
   │  Stack) │         │ Stack) │         │ Stack) │
   └─────────┘         └────────┘         └────────┘

Pros:
✅ Blast radius containment (failure affects only one cell)
✅ Compliance-friendly (data isolation)
✅ Predictable performance per cell
✅ Easy to reason about

Cons:
❌ Resource duplication (higher cost)
❌ Operational complexity (managing multiple cells)
❌ Data analytics across cells is complex

Best For:
• Multi-tenant SaaS
• Healthcare/regulated industries
• Enterprise customers requiring isolation

Cost: $$$ (High due to duplication)
Complexity: Medium-High
Healthcare Fit: ⭐⭐⭐⭐⭐ (Excellent)
```

---

## Pattern 2: Microservices Architecture

### Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Microservices Architecture for Medplum               │
└────────────────────────────────────────────────────────────────────────┘

                        ┌──────────────────┐
                        │   API Gateway    │
                        │   (Kong/AWS)     │
                        └────────┬─────────┘
                                 │
                ┌────────────────┼────────────────┐
                │                │                │
                │                │                │
    ┌───────────▼──────┐  ┌─────▼──────┐  ┌─────▼──────────┐
    │  Patient Service │  │ Practitioner│  │ Observation    │
    │                  │  │  Service    │  │   Service      │
    │  ┌────────────┐  │  │ ┌────────┐ │  │  ┌──────────┐  │
    │  │ Patient DB │  │  │ │ Prac DB│ │  │  │  Obs DB  │  │
    │  └────────────┘  │  │ └────────┘ │  │  └──────────┘  │
    └──────────────────┘  └────────────┘  └────────────────┘
           │                     │                 │
           └─────────────────────┼─────────────────┘
                                 │
                        ┌────────▼─────────┐
                        │  Event Bus       │
                        │  (EventBridge)   │
                        └──────────────────┘

Additional Services:
┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│ Auth Service│  │ Medication  │  │ Appointment │  │ Billing     │
│             │  │ Service     │  │ Service     │  │ Service     │
└─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘
```

### FHIR Resource-Based Microservices

```
┌────────────────────────────────────────────────────────────────────────┐
│            Medplum Microservices Decomposition by FHIR                 │
└────────────────────────────────────────────────────────────────────────┘

Service Boundaries:

1. Patient Service
   ┌──────────────────────────────────────────────────────────┐
   │ Resources: Patient, RelatedPerson, Person               │
   │ Database: patient_db                                     │
   │ API: /fhir/Patient/*                                     │
   │ Team: Patient Management Team                            │
   └──────────────────────────────────────────────────────────┘

2. Clinical Service
   ┌──────────────────────────────────────────────────────────┐
   │ Resources: Observation, Condition, Procedure            │
   │ Database: clinical_db                                    │
   │ API: /fhir/Observation/*, /fhir/Condition/*             │
   │ Team: Clinical Team                                      │
   └──────────────────────────────────────────────────────────┘

3. Practitioner Service
   ┌──────────────────────────────────────────────────────────┐
   │ Resources: Practitioner, PractitionerRole, Organization │
   │ Database: practitioner_db                                │
   │ API: /fhir/Practitioner/*                                │
   │ Team: Provider Management Team                           │
   └──────────────────────────────────────────────────────────┘

4. Medication Service
   ┌──────────────────────────────────────────────────────────┐
   │ Resources: Medication, MedicationRequest, Immunization  │
   │ Database: medication_db                                  │
   │ API: /fhir/Medication/*                                  │
   │ Team: Pharmacy Team                                      │
   └──────────────────────────────────────────────────────────┘

5. Scheduling Service
   ┌──────────────────────────────────────────────────────────┐
   │ Resources: Appointment, Schedule, Slot                   │
   │ Database: scheduling_db                                  │
   │ API: /fhir/Appointment/*                                 │
   │ Team: Operations Team                                    │
   └──────────────────────────────────────────────────────────┘

6. Billing Service
   ┌──────────────────────────────────────────────────────────┐
   │ Resources: Claim, Invoice, Account                       │
   │ Database: billing_db                                     │
   │ API: /fhir/Claim/*                                       │
   │ Team: Billing Team                                       │
   └──────────────────────────────────────────────────────────┘

Cross-Cutting Services:
┌──────────────────────────────────────────────────────────────┐
│ • Authentication Service (OAuth 2.0, SMART on FHIR)         │
│ • Authorization Service (ABAC/RBAC)                         │
│ • Audit Service (CloudWatch, compliance logging)            │
│ • Search Service (ElasticSearch for FHIR search)            │
│ • Notification Service (SMS, Email, Push)                   │
└──────────────────────────────────────────────────────────────┘
```

### Pros & Cons

```
┌────────────────────────────────────────────────────────────────────────┐
│              Microservices Architecture Assessment                     │
└────────────────────────────────────────────────────────────────────────┘

Pros:
✅ Independent scaling per service
   - Scale Patient service separately from Billing
   - Cost optimization (only scale what's needed)

✅ Team autonomy
   - Each team owns their service
   - Independent deployment cycles
   - Technology flexibility per service

✅ Fault isolation
   - Billing service down ≠ Patient service down
   - Graceful degradation possible

✅ Technology diversity
   - Use best tool for each job
   - Different databases per service (Postgres, Mongo, etc.)

✅ Easier to understand
   - Each service is smaller, simpler
   - Clear bounded contexts

Cons:
❌ Distributed system complexity
   - Network calls between services (latency)
   - Distributed transactions are hard
   - Eventual consistency challenges

❌ FHIR resource relationships are complex
   - Patient references Practitioner across services
   - Query complexity (e.g., "get all observations for patient")
   - Join operations require service orchestration

❌ Operational overhead
   - More services to monitor, deploy, debug
   - Service mesh complexity (Istio, Linkerd)
   - Distributed tracing required

❌ Data consistency challenges
   - Saga pattern for multi-service transactions
   - Event sourcing complexity
   - FHIR bundle operations span multiple services

❌ Higher infrastructure cost
   - Each service needs compute, database, cache
   - More AWS resources to manage

Healthcare-Specific Challenges:
⚠️  FHIR Bundle operations (create Patient + Observation atomically)
⚠️  Transaction support across resources
⚠️  Audit trail across services
⚠️  Search queries spanning multiple services
```

### Cost Estimate

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Microservices Cost Breakdown                         │
└────────────────────────────────────────────────────────────────────────┘

Per Service (10 services):
   • ECS Fargate (2 tasks): $50/month
   • RDS (db.t3.small): $30/month
   • ElastiCache (cache.t3.micro): $15/month
   • ALB target group: $5/month
   ────────────────────────────────────
   Subtotal per service: $100/month

10 Services: $1,000/month

Shared Infrastructure:
   • API Gateway: $50/month
   • Service Mesh (App Mesh): $100/month
   • ElasticSearch (search): $200/month
   • EventBridge: $25/month
   • CloudWatch (monitoring): $150/month
   ────────────────────────────────────
   Shared total: $525/month

TOTAL: ~$1,525/month

Scaling (100,000 users):
   • 4x tasks per service: $2,000/month
   • Larger databases: $1,500/month
   • More cache: $500/month
   ────────────────────────────────────
   TOTAL at scale: ~$4,525/month
```

### Recommendation

```
Best For:
✅ Large development teams (50+ engineers)
✅ Complex business logic per FHIR resource
✅ Need for independent scaling
✅ Long-term maintainability

Not Ideal For:
❌ Small teams (< 10 engineers)
❌ Early-stage startups
❌ Simple CRUD operations
❌ Tight latency requirements

Healthcare Fit: ⭐⭐⭐ (Good for large orgs)
Complexity: Very High
Cost: $$$
```

---

## Pattern 3: Serverless Architecture

### Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Serverless Architecture for Medplum                  │
└────────────────────────────────────────────────────────────────────────┘

                        ┌──────────────────┐
                        │   CloudFront     │
                        │   (CDN)          │
                        └────────┬─────────┘
                                 │
                        ┌────────▼─────────┐
                        │  API Gateway     │
                        │  (REST/GraphQL)  │
                        └────────┬─────────┘
                                 │
                ┌────────────────┼────────────────┐
                │                │                │
       ┌────────▼──────┐  ┌─────▼──────┐  ┌─────▼──────────┐
       │  Lambda        │  │  Lambda    │  │  Lambda        │
       │  (Patient)     │  │  (FHIR)    │  │  (Search)      │
       └────────┬───────┘  └─────┬──────┘  └─────┬──────────┘
                │                │                │
                └────────────────┼────────────────┘
                                 │
                        ┌────────▼─────────┐
                        │   DynamoDB       │
                        │   (Single Table) │
                        └──────────────────┘
                                 │
                        ┌────────▼─────────┐
                        │  DynamoDB        │
                        │  Streams         │
                        └────────┬─────────┘
                                 │
                        ┌────────▼─────────┐
                        │  Lambda          │
                        │  (Stream Proc)   │
                        └────────┬─────────┘
                                 │
                    ┌────────────┼────────────┐
                    │            │            │
           ┌────────▼──────┐  ┌──▼──────┐  ┌─▼────────┐
           │ ElasticSearch │  │   S3    │  │  SNS     │
           │   (Search)    │  │ (Files) │  │ (Events) │
           └───────────────┘  └─────────┘  └──────────┘

Static Content:
┌──────────────────┐
│  S3 + CloudFront │  ──► React App (Medplum Web UI)
└──────────────────┘

Authentication:
┌──────────────────┐
│   Cognito        │  ──► User management, OAuth 2.0
└──────────────────┘
```

### Single Table DynamoDB Design

```
┌────────────────────────────────────────────────────────────────────────┐
│              DynamoDB Single Table Design for FHIR                     │
└────────────────────────────────────────────────────────────────────────┘

Table: medplum-fhir

Primary Key Design:
   PK: TENANT#{tenantId}#RESOURCE#{resourceType}#{id}
   SK: VERSION#{version}

Example Records:

1. Patient Resource:
   {
     "PK": "TENANT#hospital-a#RESOURCE#Patient#123",
     "SK": "VERSION#2",
     "resourceType": "Patient",
     "id": "123",
     "name": [{"family": "Smith", "given": ["John"]}],
     "birthDate": "1980-01-01",
     "tenantId": "hospital-a",
     "version": 2,
     "lastUpdated": "2025-12-07T10:00:00Z",
     "ttl": null,
     "GSI1PK": "TENANT#hospital-a#PATIENT_BY_NAME",
     "GSI1SK": "Smith#John"
   }

2. Observation Resource:
   {
     "PK": "TENANT#hospital-a#RESOURCE#Observation#456",
     "SK": "VERSION#1",
     "resourceType": "Observation",
     "id": "456",
     "status": "final",
     "subject": {"reference": "Patient/123"},
     "code": {...},
     "valueQuantity": {...},
     "tenantId": "hospital-a",
     "GSI2PK": "TENANT#hospital-a#PATIENT#123#OBSERVATIONS",
     "GSI2SK": "2025-12-07T09:00:00Z"
   }

Global Secondary Indexes:

GSI1: Search by attributes
   PK: GSI1PK (e.g., TENANT#hospital-a#PATIENT_BY_NAME)
   SK: GSI1SK (e.g., Smith#John)

GSI2: Patient-centric queries
   PK: GSI2PK (e.g., TENANT#hospital-a#PATIENT#123#OBSERVATIONS)
   SK: GSI2SK (e.g., timestamp)

GSI3: Resource type queries
   PK: GSI3PK (e.g., TENANT#hospital-a#RESOURCE_TYPE#Patient)
   SK: GSI3SK (e.g., lastUpdated timestamp)

Benefits:
✅ Single table = simpler to manage
✅ Transactions within same partition
✅ Cost-effective (pay per request)
✅ Auto-scaling

Challenges:
❌ Complex query patterns
❌ Limited to DynamoDB query capabilities
❌ FHIR search parameters don't map well
❌ Relational queries are hard
```

### Lambda Function Structure

```
┌────────────────────────────────────────────────────────────────────────┐
│                     Lambda Functions for Medplum                       │
└────────────────────────────────────────────────────────────────────────┘

1. FHIR CRUD Operations:
   ┌──────────────────────────────────────────────────────────┐
   │ lambda-fhir-create                                       │
   │   • POST /fhir/{resourceType}                           │
   │   • Validate FHIR resource                              │
   │   • Write to DynamoDB                                    │
   │   • Trigger events (DynamoDB Streams)                   │
   │   • Memory: 1024 MB, Timeout: 30s                       │
   └──────────────────────────────────────────────────────────┘

   ┌──────────────────────────────────────────────────────────┐
   │ lambda-fhir-read                                         │
   │   • GET /fhir/{resourceType}/{id}                       │
   │   • Query DynamoDB                                       │
   │   • Return FHIR JSON                                     │
   │   • Memory: 512 MB, Timeout: 10s                        │
   └──────────────────────────────────────────────────────────┘

   ┌──────────────────────────────────────────────────────────┐
   │ lambda-fhir-search                                       │
   │   • GET /fhir/{resourceType}?param=value                │
   │   • Query ElasticSearch or DynamoDB GSI                 │
   │   • Pagination support                                   │
   │   • Memory: 2048 MB, Timeout: 30s                       │
   └──────────────────────────────────────────────────────────┘

2. Background Processing:
   ┌──────────────────────────────────────────────────────────┐
   │ lambda-stream-processor                                  │
   │   • Triggered by DynamoDB Streams                       │
   │   • Index to ElasticSearch                              │
   │   • Send notifications                                   │
   │   • Audit logging                                        │
   │   • Memory: 512 MB, Timeout: 60s                        │
   └──────────────────────────────────────────────────────────┘

3. Analytics:
   ┌──────────────────────────────────────────────────────────┐
   │ lambda-analytics-aggregator                              │
   │   • Scheduled (CloudWatch Events)                       │
   │   • Aggregate patient data                              │
   │   • Generate reports                                     │
   │   • Memory: 3008 MB, Timeout: 900s                      │
   └──────────────────────────────────────────────────────────┘
```

### Pros & Cons

```
┌────────────────────────────────────────────────────────────────────────┐
│                Serverless Architecture Assessment                      │
└────────────────────────────────────────────────────────────────────────┘

Pros:
✅ Auto-scaling (infinite scale)
   - No capacity planning needed
   - Handles traffic spikes automatically

✅ Pay-per-use (cost-effective for variable workloads)
   - No idle resources
   - Scale to zero when not in use

✅ No server management
   - AWS manages infrastructure
   - Automatic patching, updates

✅ Fast time-to-market
   - Focus on code, not infrastructure
   - Rapid prototyping

✅ Built-in high availability
   - Lambda runs in multiple AZs
   - DynamoDB Multi-AZ by default

Cons:
❌ Cold start latency (100-1000ms)
   - First request after idle is slow
   - Provisioned concurrency costs extra

❌ Execution time limits
   - Lambda max: 15 minutes
   - Long-running operations require Step Functions

❌ Vendor lock-in
   - Heavily AWS-specific
   - Hard to migrate to other clouds

❌ FHIR complexity
   - FHIR Bundle transactions are complex
   - Graph queries difficult in DynamoDB
   - Limited SQL-like capabilities

❌ Debugging challenges
   - Distributed tracing essential
   - Local development harder

Healthcare-Specific Issues:
⚠️  HIPAA: DynamoDB encryption at rest (supported ✓)
⚠️  Audit logging: CloudTrail + custom logging
⚠️  Transaction support: Limited to DynamoDB transactions
⚠️  Complex FHIR searches: Requires ElasticSearch
```

### Cost Estimate

```
┌────────────────────────────────────────────────────────────────────────┐
│                     Serverless Cost Breakdown                          │
└────────────────────────────────────────────────────────────────────────┘

Assumptions:
   • 100,000 users
   • 10 million API requests/month
   • 1 GB average data per user

Lambda:
   • 10M invocations x 500ms avg x 1024MB: $85/month
   • Provisioned concurrency (5 instances): $200/month

API Gateway:
   • 10M requests: $35/month
   • Data transfer: $90/month

DynamoDB:
   • On-Demand: $250/month (10M reads, 2M writes)
   • OR Reserved: $150/month

ElasticSearch (t3.medium):
   • Search cluster: $150/month

S3:
   • 100 GB storage: $2.30/month
   • Requests: $5/month

CloudFront:
   • 1 TB transfer: $85/month

Cognito:
   • 100,000 MAU: $0 (first 50k free, then $0.0055/MAU)
   • 100k users = $275/month

CloudWatch:
   • Logs + Metrics: $100/month
   ────────────────────────────────────
TOTAL: ~$1,277/month

At Low Usage (1,000 users, 100k requests):
   • Lambda: $5/month
   • DynamoDB: $10/month
   • API Gateway: $0.35/month
   • ElasticSearch: $150/month (fixed cost)
   ────────────────────────────────────
TOTAL: ~$300/month

Scaling Advantage:
   • 10x traffic = 2x cost (not 10x)
   • Pay only for what you use
```

### Recommendation

```
Best For:
✅ Startups with unpredictable traffic
✅ Cost-sensitive deployments
✅ Variable workloads (spiky traffic)
✅ Rapid prototyping

Not Ideal For:
❌ Consistent high traffic (always-on cheaper)
❌ Complex transactions
❌ Sub-100ms latency requirements
❌ Multi-cloud strategy

Healthcare Fit: ⭐⭐⭐ (Good with caveats)
Complexity: Medium
Cost: $$ (Low to Medium)

Special Considerations:
• Cold starts impact user experience
• FHIR search requires ElasticSearch (not pure serverless)
• Complex queries need careful design
```

---

## Pattern 4: Multi-Region Active-Active

### Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│              Multi-Region Active-Active Architecture                   │
└────────────────────────────────────────────────────────────────────────┘

                        ┌──────────────────┐
                        │   Route 53       │
                        │ Geo-proximity    │
                        │   Routing        │
                        └────────┬─────────┘
                                 │
                ┌────────────────┼────────────────┐
                │                │                │
                │                │                │
    ┌───────────▼──────────┐    │    ┌───────────▼──────────┐
    │   Region: US-EAST    │    │    │  Region: EU-WEST     │
    │   (Primary)          │    │    │  (Active)            │
    │                      │    │    │                      │
    │  ┌────────────────┐  │    │    │  ┌────────────────┐  │
    │  │      ALB       │  │    │    │  │      ALB       │  │
    │  └────────┬───────┘  │    │    │  └────────┬───────┘  │
    │           │          │    │    │           │          │
    │  ┌────────▼───────┐  │    │    │  ┌────────▼───────┐  │
    │  │ EC2 Auto Scale │  │    │    │  │ EC2 Auto Scale │  │
    │  │  (Medplum API) │  │    │    │  │  (Medplum API) │  │
    │  └────────┬───────┘  │    │    │  └────────┬───────┘  │
    │           │          │    │    │           │          │
    │  ┌────────▼───────┐  │    │    │  ┌────────▼───────┐  │
    │  │  Aurora Global │◄─┼────┼────┼─►│  Aurora Global │  │
    │  │   (Primary)    │  │    │    │  │  (Read Replica)│  │
    │  └────────────────┘  │    │    │  └────────────────┘  │
    │           │          │    │    │           │          │
    │  ┌────────▼───────┐  │    │    │  ┌────────▼───────┐  │
    │  │ ElastiCache    │◄─┼────┼────┼─►│ ElastiCache    │  │
    │  │ Global Datastore│ │    │    │  │ (Replica)      │  │
    │  └────────────────┘  │    │    │  └────────────────┘  │
    │                      │    │    │                      │
    │  ┌────────────────┐  │    │    │  ┌────────────────┐  │
    │  │ S3 (us-east-1) │◄─┼────┼────┼─►│ S3 (eu-west-1) │  │
    │  │ Cross-Region   │  │    │    │  │  Replication   │  │
    │  │  Replication   │  │    │    │  │                │  │
    │  └────────────────┘  │    │    │  └────────────────┘  │
    └──────────────────────┘    │    └──────────────────────┘
                                │
                     ┌──────────▼──────────┐
                     │  Region: AP-SOUTH   │
                     │    (Active)         │
                     │  (Similar setup)    │
                     └─────────────────────┘

Replication:
   • Aurora Global: < 1 second replication lag
   • ElastiCache Global: Cross-region replication
   • S3 CRR: Asynchronous replication
```

### Read/Write Strategy

```
┌────────────────────────────────────────────────────────────────────────┐
│               Multi-Region Read/Write Patterns                         │
└────────────────────────────────────────────────────────────────────────┘

Pattern 1: Active-Active (Both Read & Write)
┌──────────────────────────────────────────────────────────────────┐
│ US Region:                        EU Region:                     │
│   • Reads: ✅ Local                 • Reads: ✅ Local             │
│   • Writes: ✅ Local                • Writes: ✅ Local            │
│                                                                  │
│ Conflict Resolution:                                             │
│   • Last-write-wins (timestamp-based)                           │
│   • Application-level conflict detection                        │
│   • FHIR version tracking                                       │
│                                                                  │
│ Challenges:                                                      │
│   ⚠️  Write conflicts (same patient updated in both regions)    │
│   ⚠️  Eventual consistency                                      │
│   ⚠️  Complex conflict resolution                               │
└──────────────────────────────────────────────────────────────────┘

Pattern 2: Active-Passive (Recommended)
┌──────────────────────────────────────────────────────────────────┐
│ Primary Region (US):              Replica Region (EU):           │
│   • Reads: ✅ Local                 • Reads: ✅ Local             │
│   • Writes: ✅ Accept               • Writes: ❌ Redirect to US   │
│                                                                  │
│ Replication:                                                     │
│   • US → EU: Async (< 1s lag)                                   │
│   • EU serves read-only traffic                                 │
│   • Failover: EU promoted to primary if US down                 │
│                                                                  │
│ Benefits:                                                        │
│   ✅ No write conflicts                                         │
│   ✅ Simpler to implement                                       │
│   ✅ FHIR consistency maintained                                │
└──────────────────────────────────────────────────────────────────┘

Pattern 3: Geographic Partitioning
┌──────────────────────────────────────────────────────────────────┐
│ US Region:                        EU Region:                     │
│   • US patients ONLY               • EU patients ONLY            │
│   • All operations local           • All operations local       │
│                                                                  │
│ Data Residency:                                                  │
│   • US data stays in US                                         │
│   • EU data stays in EU (GDPR)                                  │
│   • No cross-region replication                                 │
│                                                                  │
│ Benefits:                                                        │
│   ✅ Compliance-friendly                                        │
│   ✅ No conflicts                                                │
│   ✅ Simple to understand                                        │
│                                                                  │
│ Challenges:                                                      │
│   ⚠️  Patient travels (US to EU) = data migration              │
│   ⚠️  Cross-region queries difficult                            │
└──────────────────────────────────────────────────────────────────┘
```

### Pros & Cons

```
┌────────────────────────────────────────────────────────────────────────┐
│            Multi-Region Active-Active Assessment                       │
└────────────────────────────────────────────────────────────────────────┘

Pros:
✅ Lowest latency globally
   - Users connect to nearest region
   - < 50ms response time worldwide

✅ Disaster recovery built-in
   - Region failure = automatic failover
   - RTO: < 1 minute
   - RPO: < 1 second

✅ No single point of failure
   - Multiple regions operational
   - Even AWS regional outage doesn't affect all users

✅ Compliance-friendly
   - Data residency per region
   - GDPR, country-specific regulations

✅ Performance during outages
   - Traffic automatically routed to healthy region
   - Users barely notice issues

Cons:
❌ Extremely high cost
   - 2-3x infrastructure (duplicated per region)
   - Cross-region data transfer costs

❌ Complex data consistency
   - Write conflicts in active-active
   - FHIR version conflicts
   - Eventual consistency vs strong consistency

❌ Operational complexity
   - Managing multiple regions
   - Deployment coordination
   - Monitoring across regions

❌ FHIR-specific challenges
   - Bundle operations across regions
   - Reference consistency (Patient/123 in US vs EU)
   - Search results may differ between regions

Healthcare Challenges:
⚠️  Medical records must be consistent
⚠️  Conflicts could lead to patient safety issues
⚠️  Audit trail across regions is complex
```

### Cost Estimate

```
┌────────────────────────────────────────────────────────────────────────┐
│              Multi-Region Active-Active Cost Breakdown                 │
└────────────────────────────────────────────────────────────────────────┘

Per Region (3 regions: US-East, EU-West, AP-South):

Region Infrastructure:
   • EC2 (4x t3.xlarge): $496/month
   • Aurora Global Primary: $800/month
   • Aurora Replicas (per region): $400/month
   • ElastiCache Global: $350/month
   • ALB: $25/month
   • S3 + Replication: $50/month
   ────────────────────────────────────
   Per region: $2,121/month

3 Regions: $6,363/month

Additional Costs:
   • Cross-region data transfer: $500/month
     (100 GB/day x 3 regions x $0.02/GB)
   • Route 53 (geo-routing): $50/month
   • Global Accelerator (optional): $300/month
   • Monitoring (multi-region): $200/month
   ────────────────────────────────────
TOTAL: ~$7,413/month

With Reserved Instances (3-year):
   • 40% savings on EC2/RDS: -$1,800/month
   ────────────────────────────────────
TOTAL: ~$5,613/month

Comparison:
   • Single region: $1,200/month
   • Multi-region: $7,413/month
   • Cost multiplier: 6.2x
```

### Recommendation

```
Best For:
✅ Global user base (US, EU, Asia)
✅ Mission-critical applications (hospitals worldwide)
✅ Strict latency requirements (< 100ms)
✅ Enterprise customers with global presence
✅ Disaster recovery as top priority

Not Ideal For:
❌ Small/medium deployments
❌ Single-region user base
❌ Cost-sensitive organizations
❌ Early-stage startups

Healthcare Fit: ⭐⭐⭐⭐ (Excellent for global healthcare)
Complexity: Very High
Cost: $$$$$  (Very Expensive)

Recommendation:
   • Use Active-Passive (not Active-Active)
   • Geographic partitioning for data residency
   • Start with 2 regions (US + EU)
   • Add Asia-Pacific when customer base justifies
```

---

## Pattern 5: Kubernetes-Based (EKS)

### Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│              Kubernetes (EKS) Architecture for Medplum                 │
└────────────────────────────────────────────────────────────────────────┘

                        ┌──────────────────┐
                        │   Route 53       │
                        └────────┬─────────┘
                                 │
                        ┌────────▼─────────┐
                        │  Network Load    │
                        │   Balancer       │
                        └────────┬─────────┘
                                 │
    ┌────────────────────────────▼────────────────────────────┐
    │              EKS Cluster (Kubernetes)                   │
    │                                                          │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │          Ingress Controller (NGINX/ALB)           │  │
    │  └────────────────────┬──────────────────────────────┘  │
    │                       │                                  │
    │  ┌────────────────────┼──────────────────────────────┐  │
    │  │                    │                              │  │
    │  │     ┌──────────────▼─────────┐                    │  │
    │  │     │  Medplum API Pods      │                    │  │
    │  │     │  ┌──────────────────┐  │                    │  │
    │  │     │  │  Pod 1           │  │                    │  │
    │  │     │  │  - API Container │  │                    │  │
    │  │     │  │  - Sidecar (Auth)│  │                    │  │
    │  │     │  └──────────────────┘  │                    │  │
    │  │     │  ┌──────────────────┐  │                    │  │
    │  │     │  │  Pod 2           │  │                    │  │
    │  │     │  └──────────────────┘  │                    │  │
    │  │     │  HPA: Min 2, Max 10    │                    │  │
    │  │     └────────────┬───────────┘                    │  │
    │  │                  │                                 │  │
    │  │     ┌────────────▼───────────┐                    │  │
    │  │     │  Web App Pods          │                    │  │
    │  │     │  (React Frontend)      │                    │  │
    │  │     │  HPA: Min 2, Max 8     │                    │  │
    │  │     └────────────┬───────────┘                    │  │
    │  │                  │                                 │  │
    │  │     ┌────────────▼───────────┐                    │  │
    │  │     │  Worker Pods           │                    │  │
    │  │     │  (Background Jobs)     │                    │  │
    │  │     │  HPA: Min 1, Max 5     │                    │  │
    │  │     └────────────────────────┘                    │  │
    │  │                                                    │  │
    │  └────────────────────────────────────────────────────┘  │
    │                                                          │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │          Service Mesh (Istio/Linkerd)             │  │
    │  │  - mTLS between pods                              │  │
    │  │  - Traffic management                             │  │
    │  │  - Observability                                  │  │
    │  └───────────────────────────────────────────────────┘  │
    │                                                          │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │              ConfigMaps & Secrets                 │  │
    │  │  - Database credentials                           │  │
    │  │  - API keys                                       │  │
    │  │  - Environment configs                            │  │
    │  └───────────────────────────────────────────────────┘  │
    │                                                          │
    │  ┌───────────────────────────────────────────────────┐  │
    │  │         Persistent Volumes (EBS CSI Driver)       │  │
    │  │  - StatefulSets for databases (if needed)         │  │
    │  └───────────────────────────────────────────────────┘  │
    │                                                          │
    └────────────────────┬─────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐     ┌───▼────┐     ┌───▼────┐
    │   RDS   │     │ ElastiCache   │   S3   │
    │(External)     │ (External)    │(External)
    └─────────┘     └────────┘      └────────┘

Monitoring Stack:
┌─────────────────────────────────────────────────────────────┐
│  Prometheus (metrics)                                       │
│  Grafana (dashboards)                                       │
│  Jaeger/Zipkin (distributed tracing)                       │
│  Fluentd (log aggregation)                                 │
└─────────────────────────────────────────────────────────────┘
```

### Kubernetes Manifests

```
┌────────────────────────────────────────────────────────────────────────┐
│                  Example Kubernetes Manifests                          │
└────────────────────────────────────────────────────────────────────────┘

1. Deployment (Medplum API):
───────────────────────────────────────────────────────────────
apiVersion: apps/v1
kind: Deployment
metadata:
  name: medplum-api
  namespace: medplum
spec:
  replicas: 4
  selector:
    matchLabels:
      app: medplum-api
  template:
    metadata:
      labels:
        app: medplum-api
        version: v1.0.0
    spec:
      containers:
      - name: api
        image: medplum/api:latest
        ports:
        - containerPort: 8103
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: medplum-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            configMapKeyRef:
              name: medplum-config
              key: redis-url
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /healthcheck
            port: 8103
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /healthcheck
            port: 8103
          initialDelaySeconds: 5
          periodSeconds: 5

2. Horizontal Pod Autoscaler:
───────────────────────────────────────────────────────────────
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: medplum-api-hpa
  namespace: medplum
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: medplum-api
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80

3. Service:
───────────────────────────────────────────────────────────────
apiVersion: v1
kind: Service
metadata:
  name: medplum-api-service
  namespace: medplum
spec:
  selector:
    app: medplum-api
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8103
  type: ClusterIP

4. Ingress:
───────────────────────────────────────────────────────────────
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: medplum-ingress
  namespace: medplum
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
spec:
  rules:
  - host: api.medplum.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: medplum-api-service
            port:
              number: 80
```

### Pros & Cons

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Kubernetes (EKS) Assessment                          │
└────────────────────────────────────────────────────────────────────────┘

Pros:
✅ Portability (multi-cloud)
   - Same manifests work on AWS, GCP, Azure
   - Avoid vendor lock-in
   - Easier migration between clouds

✅ Advanced deployment strategies
   - Canary deployments
   - Blue-green deployments
   - Rolling updates with zero downtime

✅ Auto-scaling
   - Pod-level (HPA)
   - Node-level (Cluster Autoscaler)
   - Event-driven (KEDA)

✅ Rich ecosystem
   - Helm charts for common apps
   - Operators for complex apps
   - Service mesh (Istio, Linkerd)

✅ Developer experience
   - Local development (Minikube, Kind)
   - GitOps workflows (ArgoCD, Flux)
   - Self-service deployments

✅ Resource efficiency
   - Better bin-packing than VMs
   - Efficient resource utilization
   - Cost savings vs EC2

Cons:
❌ Steep learning curve
   - Complex concepts (pods, services, ingress)
   - YAML configuration hell
   - Debugging is harder

❌ Operational overhead
   - EKS cluster management
   - Upgrades (Kubernetes versions)
   - Networking complexity (CNI, service mesh)

❌ Security complexity
   - RBAC configuration
   - Network policies
   - Pod security standards

❌ Cost
   - EKS control plane: $0.10/hour ($73/month per cluster)
   - Worker nodes: EC2 costs
   - Add-ons (Istio, monitoring) = more resources

❌ Overkill for simple apps
   - If Medplum is monolithic, K8s adds complexity
   - EC2 Auto Scaling might be simpler

Healthcare Considerations:
⚠️  HIPAA: Ensure pod-to-pod encryption (service mesh)
⚠️  Secrets management: Use AWS Secrets Manager integration
⚠️  Compliance: Audit logging more complex
```

### Cost Estimate

```
┌────────────────────────────────────────────────────────────────────────┐
│                      EKS Cost Breakdown                                │
└────────────────────────────────────────────────────────────────────────┘

EKS Control Plane:
   • $0.10/hour x 24 x 30 = $73/month

Worker Nodes (3 AZs):
   • 3x t3.xlarge (on-demand): $373/month
   • OR 3x t3.xlarge (reserved 1-year): $224/month
   • OR 3x t3.xlarge (reserved 3-year): $150/month

EBS Volumes (gp3):
   • 100 GB x 3 nodes: $30/month

Network Load Balancer:
   • NLB: $25/month
   • Data processing: $10/month

Add-ons:
   • EBS CSI Driver: Free
   • AWS Load Balancer Controller: Free
   • Cluster Autoscaler: Free
   • Service Mesh (Istio):
     - Control plane pods: ~$20/month (resources)
     - Sidecar overhead: ~15% more resources
   • Monitoring (Prometheus + Grafana):
     - Pods: ~$30/month

External Services:
   • RDS PostgreSQL: $260/month
   • ElastiCache: $140/month
   • S3: $10/month

────────────────────────────────────────────
TOTAL (on-demand): ~$971/month
TOTAL (reserved 1-yr): ~$822/month
TOTAL (reserved 3-yr): ~$748/month

At Scale (10 nodes):
   • EKS: $73/month
   • 10x t3.xlarge (reserved): $746/month
   • EBS: $100/month
   • NLB: $35/month
   • Add-ons: $100/month
   • RDS: $520/month
   • ElastiCache: $280/month
────────────────────────────────────────────
TOTAL at scale: ~$1,854/month
```

### Recommendation

```
Best For:
✅ Multi-cloud strategy
✅ Microservices architecture
✅ Large engineering teams (platform team exists)
✅ Complex deployment requirements
✅ Already familiar with Kubernetes

Not Ideal For:
❌ Small teams (< 10 engineers)
❌ Monolithic applications
❌ No Kubernetes expertise
❌ Simple deployment needs

Healthcare Fit: ⭐⭐⭐ (Good if you have K8s expertise)
Complexity: Very High
Cost: $$$

Recommendation:
   • Only use if you have dedicated platform/DevOps team
   • Or if multi-cloud is a hard requirement
   • Otherwise, simpler alternatives (ECS, plain EC2) are better
```

---

## Pattern 6: Hybrid Architecture

### Concept

```
┌────────────────────────────────────────────────────────────────────────┐
│                     Hybrid Architecture Pattern                        │
└────────────────────────────────────────────────────────────────────────┘

Idea: Combine multiple patterns for best results

Recommended Hybrid: Cell Architecture + Microservices
┌──────────────────────────────────────────────────────────────────┐
│                                                                  │
│  ┌──────────────────┐         ┌──────────────────┐              │
│  │   Cell 1         │         │   Cell 2         │              │
│  │   (US-East)      │         │   (EU-West)      │              │
│  │                  │         │                  │              │
│  │  ┌────────────┐  │         │  ┌────────────┐  │              │
│  │  │ Patient    │  │         │  │ Patient    │  │              │
│  │  │ Service    │  │         │  │ Service    │  │              │
│  │  └────────────┘  │         │  └────────────┘  │              │
│  │  ┌────────────┐  │         │  ┌────────────┐  │              │
│  │  │ Clinical   │  │         │  │ Clinical   │  │              │
│  │  │ Service    │  │         │  │ Service    │  │              │
│  │  └────────────┘  │         │  └────────────┘  │              │
│  │  ┌────────────┐  │         │  ┌────────────┐  │              │
│  │  │ Billing    │  │         │  │ Billing    │  │              │
│  │  │ Service    │  │         │  │ Service    │  │              │
│  │  └────────────┘  │         │  └────────────┘  │              │
│  │                  │         │                  │              │
│  │  (Own DB/Cache)  │         │  (Own DB/Cache)  │              │
│  └──────────────────┘         └──────────────────┘              │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘

Benefits:
✅ Blast radius containment (cells)
✅ Service independence (microservices)
✅ Team autonomy per service
✅ Scale services independently within each cell

Trade-offs:
⚠️  Most complex architecture
⚠️  Highest operational overhead
⚠️  Most expensive
```

### Other Hybrid Combinations

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Hybrid Architecture Combinations                     │
└────────────────────────────────────────────────────────────────────────┘

1. Monolith + Serverless
   ┌──────────────────────────────────────────────────────────┐
   │  Core FHIR API: EC2 monolith (proven, stable)           │
   │  Analytics: Lambda (sporadic workload)                   │
   │  File Processing: Lambda (event-driven)                  │
   │  Notifications: Lambda + SNS                             │
   └──────────────────────────────────────────────────────────┘
   ✅ Best of both: Stability + cost-efficiency
   ⭐ Healthcare Fit: ⭐⭐⭐⭐ (Recommended)

2. EKS + RDS Aurora Serverless
   ┌──────────────────────────────────────────────────────────┐
   │  Application: K8s (flexibility)                          │
   │  Database: Aurora Serverless (auto-scaling DB)           │
   └──────────────────────────────────────────────────────────┘
   ✅ Scale DB independently from app
   ⭐ Healthcare Fit: ⭐⭐⭐

3. Multi-Region + Cell
   ┌──────────────────────────────────────────────────────────┐
   │  US Region: 3 cells                                      │
   │  EU Region: 2 cells                                      │
   │  Asia Region: 1 cell                                     │
   └──────────────────────────────────────────────────────────┘
   ✅ Geographic + blast radius containment
   ⭐ Healthcare Fit: ⭐⭐⭐⭐⭐ (Best for global enterprise)
```

### Recommendation

```
Recommended Hybrid for Medplum:

Phase 1 (Now - 1 year):
   • Monolith on EC2 (current)
   • Serverless for batch jobs (Lambda)
   • Single region (us-east-1)

Phase 2 (1-2 years):
   • 2 Cells (US + EU)
   • Monolith in each cell
   • Serverless for analytics

Phase 3 (2+ years):
   • 3+ Cells (US, EU, Asia)
   • Microservices within cells (if team grows)
   • Multi-region active-passive

Healthcare Fit: ⭐⭐⭐⭐⭐ (Excellent)
Complexity: Medium → High (gradual increase)
Cost: $$ → $$$ (scales with growth)
```

---

## Pattern 7: Database Sharding (Horizontal Scaling)

### Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│                Database Sharding Architecture                          │
└────────────────────────────────────────────────────────────────────────┘

                        ┌──────────────────┐
                        │   Application    │
                        │     Tier         │
                        │  (Medplum API)   │
                        └────────┬─────────┘
                                 │
                        ┌────────▼─────────┐
                        │  Sharding Layer  │
                        │  (Vitess/Citus)  │
                        │  OR Custom       │
                        └────────┬─────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
   ┌────▼────┐             ┌────▼────┐             ┌────▼────┐
   │ Shard 1 │             │ Shard 2 │             │ Shard 3 │
   │         │             │         │             │         │
   │Tenants: │             │Tenants: │             │Tenants: │
   │ A, B, C │             │ D, E, F │             │ G, H, I │
   │         │             │         │             │         │
   │ RDS DB  │             │ RDS DB  │             │ RDS DB  │
   │(Primary)│             │(Primary)│             │(Primary)│
   │    +    │             │    +    │             │    +    │
   │(Replica)│             │(Replica)│             │(Replica)│
   └─────────┘             └─────────┘             └─────────┘

Shard Key: tenant_id
   • tenant_id % 3 = shard number
   • OR consistent hashing
   • OR range-based (tenant_id 1-1000 → Shard 1)

Shard Mapping Table (DynamoDB or Redis):
   tenant_id | shard_id
   ──────────┼─────────
   hospital-a│ shard-1
   clinic-b  │ shard-1
   practice-c│ shard-2
   ...       │ ...
```

### Sharding Strategies

```
┌────────────────────────────────────────────────────────────────────────┐
│                      Sharding Strategies                               │
└────────────────────────────────────────────────────────────────────────┘

1. Tenant-Based Sharding (Recommended for Medplum)
   ┌──────────────────────────────────────────────────────────┐
   │ Shard Key: tenant_id                                     │
   │                                                          │
   │ All data for a tenant goes to same shard                │
   │   • Patient records for hospital-a → Shard 1            │
   │   • Observations for hospital-a → Shard 1               │
   │   • Practitioners for hospital-a → Shard 1              │
   │                                                          │
   │ Benefits:                                                │
   │   ✅ No cross-shard queries (tenant-scoped)             │
   │   ✅ Easy to reason about                                │
   │   ✅ Tenant migrations are simple (move whole shard)    │
   │                                                          │
   │ Challenges:                                              │
   │   ⚠️  Uneven distribution (large tenants)               │
   │   ⚠️  Rebalancing when shard grows                      │
   └──────────────────────────────────────────────────────────┘

2. Range-Based Sharding
   ┌──────────────────────────────────────────────────────────┐
   │ Shard 1: Patients with id 0-999,999                      │
   │ Shard 2: Patients with id 1,000,000-1,999,999           │
   │ Shard 3: Patients with id 2,000,000+                    │
   │                                                          │
   │ Benefits:                                                │
   │   ✅ Easy to implement                                   │
   │   ✅ Ordered queries work well                           │
   │                                                          │
   │ Challenges:                                              │
   │   ❌ Hotspots (newest data = most active shard)         │
   │   ❌ Rebalancing requires range splits                   │
   └──────────────────────────────────────────────────────────┘

3. Hash-Based Sharding
   ┌──────────────────────────────────────────────────────────┐
   │ Shard = hash(patient_id) % num_shards                    │
   │                                                          │
   │ Benefits:                                                │
   │   ✅ Even distribution                                   │
   │   ✅ No hotspots                                         │
   │                                                          │
   │ Challenges:                                              │
   │   ❌ Difficult to rebalance (rehash all keys)           │
   │   ❌ Range queries don't work                            │
   │   ❌ Patient + related resources may be on different shards │
   └──────────────────────────────────────────────────────────┘
```

### Pros & Cons

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Database Sharding Assessment                         │
└────────────────────────────────────────────────────────────────────────┘

Pros:
✅ Horizontal scalability
   - Add more shards as data grows
   - No single database limit

✅ Performance improvement
   - Queries hit smaller datasets
   - Parallel query execution across shards

✅ Cost optimization
   - Smaller databases = cheaper instances
   - db.t3.medium x 5 < db.r6g.4xlarge x 1

✅ Blast radius containment
   - Shard failure affects only subset of tenants
   - Similar to cell architecture

Cons:
❌ Application complexity
   - Shard-aware queries
   - Cross-shard joins are impossible (or very slow)
   - Transactions limited to single shard

❌ FHIR-specific challenges
   - Patient in Shard 1, Observation in Shard 2 = complex
   - FHIR search across all shards = slow
   - Bundle operations may span shards

❌ Rebalancing complexity
   - Moving tenants between shards
   - Downtime during migration
   - Data consistency during move

❌ Schema changes
   - Must apply to all shards
   - Migration complexity

Healthcare Challenges:
⚠️  FHIR resource references across shards
⚠️  Analytics queries (all patients) = query all shards
⚠️  Transaction guarantees across shards
```

### When to Use

```
┌────────────────────────────────────────────────────────────────────────┐
│                 When to Use Database Sharding                          │
└────────────────────────────────────────────────────────────────────────┘

Use Sharding When:
✅ Database size > 1 TB
✅ Single database can't handle load
✅ Tenant-scoped queries (no cross-tenant joins)
✅ Horizontal scaling needed

Don't Use Sharding When:
❌ Database < 100 GB (vertical scaling sufficient)
❌ Frequent cross-tenant queries
❌ Small team (operational overhead)
❌ Alternatives exist (Aurora read replicas, caching)

For Medplum:
┌──────────────────────────────────────────────────────────────┐
│ Current Database Size: ~10 GB (100 tenants)                 │
│                                                              │
│ Recommendation: DON'T shard yet                             │
│                                                              │
│ Alternatives:                                                │
│   1. Aurora read replicas (scale reads)                     │
│   2. ElastiCache (cache hot data)                           │
│   3. Cell architecture (shard tenants, not data)            │
│                                                              │
│ Shard When:                                                  │
│   • Database > 500 GB                                        │
│   • OR > 1,000 tenants                                       │
│   • OR single RDS instance maxed out                         │
│                                                              │
│ Estimated Timeline: 2-3 years                                │
└──────────────────────────────────────────────────────────────┘

Healthcare Fit: ⭐⭐ (Niche use case)
Complexity: Very High
Cost: $$
```

---

## Comparative Analysis

### Summary Table

```
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                          Architecture Pattern Comparison                                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘

Pattern                  │ Healthcare │ Complexity │  Cost  │ Scalability │ Ops Burden │ Time to Market
                         │    Fit     │            │        │             │            │
─────────────────────────┼────────────┼────────────┼────────┼─────────────┼────────────┼───────────────
1. Cell-Based            │  ⭐⭐⭐⭐⭐  │   Medium   │  $$$   │    High     │   Medium   │   3-6 months
2. Microservices         │   ⭐⭐⭐    │ Very High  │  $$$   │  Very High  │    High    │   6-12 months
3. Serverless            │   ⭐⭐⭐    │   Medium   │   $$   │  Very High  │    Low     │   1-2 months
4. Multi-Region AA       │  ⭐⭐⭐⭐   │ Very High  │ $$$$$  │  Very High  │ Very High  │   6-12 months
5. Kubernetes (EKS)      │   ⭐⭐⭐    │ Very High  │  $$$   │    High     │    High    │   3-6 months
6. Hybrid (Cell+Micro)   │  ⭐⭐⭐⭐⭐  │ Very High  │ $$$$   │  Very High  │ Very High  │   12+ months
7. Database Sharding     │   ⭐⭐     │ Very High  │   $$   │    High     │    High    │   6-9 months
─────────────────────────┴────────────┴────────────┴────────┴─────────────┴────────────┴───────────────

Current (Monolith)       │   ⭐⭐⭐    │    Low     │   $    │     Low     │    Low     │   Done ✓

Legend:
  Healthcare Fit: How well it addresses healthcare compliance, patient safety, etc.
  Complexity: Implementation and ongoing complexity
  Cost: Infrastructure + operational cost ($ = low, $$$$$ = very high)
  Scalability: Ability to scale to millions of users
  Ops Burden: Operational overhead to maintain
  Time to Market: How long to implement from scratch
```

### Detailed Scoring

```
┌────────────────────────────────────────────────────────────────────────┐
│                    Detailed Feature Comparison                         │
└────────────────────────────────────────────────────────────────────────┘

Feature                     │Cell│Micro│Svls│Multi│ EKS │Hybrd│Shard│Mono
────────────────────────────┼────┼─────┼────┼─────┼─────┼─────┼─────┼────
Blast Radius Containment    │ ⭐⭐⭐│ ⭐  │ ⭐⭐│ ⭐⭐⭐│ ⭐⭐ │ ⭐⭐⭐│ ⭐⭐ │ ❌
HIPAA Compliance Ready      │ ⭐⭐⭐│ ⭐⭐ │ ⭐⭐│ ⭐⭐⭐│ ⭐⭐ │ ⭐⭐⭐│ ⭐⭐ │ ⭐⭐
Data Isolation (Tenant)     │ ⭐⭐⭐│ ⭐  │ ⭐⭐│ ⭐⭐⭐│ ⭐  │ ⭐⭐⭐│ ⭐⭐⭐│ ❌
Performance Isolation       │ ⭐⭐⭐│ ⭐⭐ │ ⭐  │ ⭐⭐ │ ⭐⭐ │ ⭐⭐⭐│ ⭐⭐ │ ❌
Geographic Distribution     │ ⭐⭐ │ ⭐  │ ⭐⭐│ ⭐⭐⭐│ ⭐⭐ │ ⭐⭐⭐│ ⭐  │ ⭐
Disaster Recovery           │ ⭐⭐ │ ⭐  │ ⭐⭐│ ⭐⭐⭐│ ⭐⭐ │ ⭐⭐⭐│ ⭐  │ ⭐
Cost Efficiency (Small)     │ ⭐  │ ❌  │ ⭐⭐⭐│ ❌  │ ⭐  │ ❌  │ ⭐⭐ │ ⭐⭐⭐
Cost Efficiency (Large)     │ ⭐⭐ │ ⭐⭐ │ ⭐⭐ │ ❌  │ ⭐⭐ │ ⭐  │ ⭐⭐ │ ⭐
Developer Experience        │ ⭐⭐ │ ⭐  │ ⭐⭐ │ ⭐  │ ⭐  │ ❌  │ ⭐  │ ⭐⭐⭐
Operational Simplicity      │ ⭐⭐ │ ❌  │ ⭐⭐ │ ❌  │ ❌  │ ❌  │ ❌  │ ⭐⭐⭐
Multi-Cloud Portability     │ ⭐⭐ │ ⭐⭐ │ ❌  │ ⭐⭐ │ ⭐⭐⭐│ ⭐⭐ │ ⭐⭐ │ ⭐⭐
Vendor Lock-in (Lower=Good) │ ⭐⭐ │ ⭐⭐ │ ❌  │ ⭐⭐ │ ⭐⭐⭐│ ⭐⭐ │ ⭐⭐ │ ⭐⭐⭐
Team Size Required          │ 5-10│20-50│ 2-5 │10-20│10-30│30-50│ 5-10│ 2-5
────────────────────────────┴────┴─────┴────┴─────┴─────┴─────┴─────┴────

Legend: ⭐⭐⭐ = Excellent, ⭐⭐ = Good, ⭐ = Fair, ❌ = Poor
```

---

## Recommendations by Use Case

```
┌────────────────────────────────────────────────────────────────────────┐
│                  Recommended Architecture by Scenario                  │
└────────────────────────────────────────────────────────────────────────┘

Scenario 1: Startup / Early Stage (Current State)
┌──────────────────────────────────────────────────────────────────┐
│ Users: < 1,000                                                   │
│ Tenants: < 10                                                    │
│ Team: 2-5 engineers                                              │
│                                                                  │
│ RECOMMENDED: Monolith + Serverless (Hybrid)                      │
│                                                                  │
│ Architecture:                                                    │
│   • Core API: EC2 monolith (current)                            │
│   • Analytics: Lambda functions                                 │
│   • File processing: Lambda + S3                                │
│   • Single region (us-east-1)                                   │
│                                                                  │
│ Why:                                                             │
│   ✅ Simple to understand and maintain                          │
│   ✅ Low cost ($150-300/month)                                  │
│   ✅ Fast time to market                                        │
│   ✅ Easy to debug                                              │
│                                                                  │
│ Evolution Path:                                                  │
│   → Cell architecture when you have 50+ tenants                 │
└──────────────────────────────────────────────────────────────────┘

Scenario 2: Growth Stage (1-2 years)
┌──────────────────────────────────────────────────────────────────┐
│ Users: 1,000-50,000                                              │
│ Tenants: 10-100                                                  │
│ Team: 5-15 engineers                                             │
│                                                                  │
│ RECOMMENDED: Cell Architecture                                   │
│                                                                  │
│ Architecture:                                                    │
│   • 2-3 cells (US-East, US-West, EU-West)                       │
│   • Monolith within each cell                                   │
│   • RDS Multi-AZ per cell                                       │
│   • ElastiCache per cell                                        │
│   • Route 53 geographic routing                                 │
│                                                                  │
│ Why:                                                             │
│   ✅ Blast radius containment                                   │
│   ✅ Compliance-ready (HIPAA, GDPR)                             │
│   ✅ Enterprise sales enabler                                   │
│   ✅ Manageable complexity                                       │
│                                                                  │
│ Cost: $1,500-3,000/month                                         │
└──────────────────────────────────────────────────────────────────┘

Scenario 3: Scale-up / Enterprise (2-5 years)
┌──────────────────────────────────────────────────────────────────┐
│ Users: 50,000-500,000                                            │
│ Tenants: 100-1,000                                               │
│ Team: 15-50 engineers                                            │
│                                                                  │
│ RECOMMENDED: Hybrid (Cell + Microservices)                       │
│                                                                  │
│ Architecture:                                                    │
│   • 5-10 cells (multiple regions)                               │
│   • Microservices within cells                                  │
│     - Patient service                                            │
│     - Clinical service                                           │
│     - Billing service                                            │
│   • Kubernetes (EKS) optional                                    │
│   • Multi-region active-passive                                 │
│                                                                  │
│ Why:                                                             │
│   ✅ Team autonomy (service ownership)                          │
│   ✅ Independent scaling                                         │
│   ✅ Best blast radius containment                              │
│   ✅ Enterprise-grade reliability                               │
│                                                                  │
│ Cost: $5,000-15,000/month                                        │
└──────────────────────────────────────────────────────────────────┘

Scenario 4: Global Healthcare Platform (5+ years)
┌──────────────────────────────────────────────────────────────────┐
│ Users: 500,000+                                                  │
│ Tenants: 1,000+                                                  │
│ Team: 50+ engineers                                              │
│                                                                  │
│ RECOMMENDED: Multi-Region + Cell + Microservices                 │
│                                                                  │
│ Architecture:                                                    │
│   • 3 regions: US, EU, Asia-Pacific                             │
│   • 3-5 cells per region                                        │
│   • Microservices in each cell                                  │
│   • Active-passive multi-region                                 │
│   • Kubernetes (multi-cluster)                                  │
│   • Global CDN (CloudFront)                                     │
│                                                                  │
│ Why:                                                             │
│   ✅ Global lowest latency                                      │
│   ✅ Regional data residency                                    │
│   ✅ Maximum blast radius control                               │
│   ✅ Can handle any scale                                       │
│                                                                  │
│ Cost: $20,000-50,000+/month                                      │
└──────────────────────────────────────────────────────────────────┘
```

---

## Final Recommendation for Medplum (Current Stage)

```
┌────────────────────────────────────────────────────────────────────────┐
│                     Recommended Evolution Path                         │
└────────────────────────────────────────────────────────────────────────┘

Phase 0: Current (COMPLETE)
   Architecture: Monolith on single EC2
   Cost: $144/month
   Timeline: Now

Phase 1: Foundation (0-6 months) ⬅ START HERE
   Architecture: Monolith + Serverless hybrid
   Changes:
     ✅ Move to RDS PostgreSQL (Multi-AZ)
     ✅ Add ElastiCache Redis
     ✅ Lambda for batch jobs
     ✅ Multi-tenant database (logical separation)
     ✅ Implement tenant identification
   Cost: $600-800/month
   Timeline: Next 6 months

Phase 2: Cell Deployment (6-18 months)
   Architecture: 2 Cell Architecture
   Changes:
     ✅ Deploy Cell 2 (us-west-2 or eu-west-1)
     ✅ Implement cell routing (Route 53)
     ✅ Cell failover automation
     ✅ Tenant migration tools
   Cost: $1,500-2,000/month
   Timeline: 6-18 months from now

Phase 3: Geographic Expansion (18-36 months)
   Architecture: 3 Cell Architecture (US-East, US-West, EU)
   Changes:
     ✅ Add EU cell for GDPR
     ✅ Geographic routing
     ✅ Cross-region backup
   Cost: $2,500-3,500/month
   Timeline: 18-36 months from now

Phase 4: Enterprise Scale (36+ months)
   Architecture: Cell + Microservices (if needed)
   Changes:
     ✅ Decompose to microservices (if team > 20)
     ✅ Dedicated cells for enterprise
     ✅ Multi-region active-passive
   Cost: $5,000-10,000/month
   Timeline: 36+ months from now

┌────────────────────────────────────────────────────────────────────┐
│                          SUMMARY                                   │
│                                                                    │
│  Current: Monolith ($144/month)                                   │
│  ↓                                                                 │
│  6 months: Managed services ($600/month)                          │
│  ↓                                                                 │
│  18 months: 2 Cells ($1,500/month)                                │
│  ↓                                                                 │
│  36 months: 3 Cells ($2,500/month)                                │
│  ↓                                                                 │
│  5 years: Cell + Microservices ($5,000+/month)                    │
│                                                                    │
│  This gradual evolution minimizes risk and matches your growth!   │
└────────────────────────────────────────────────────────────────────┘
```

---

## Conclusion

```
┌────────────────────────────────────────────────────────────────────────┐
│                              Summary                                   │
└────────────────────────────────────────────────────────────────────────┘

7 Architecture Patterns Evaluated:
   1. ⭐⭐⭐⭐⭐ Cell-Based - HIGHLY RECOMMENDED
   2. ⭐⭐⭐    Microservices - Good for large teams
   3. ⭐⭐⭐    Serverless - Good for variable workloads
   4. ⭐⭐⭐⭐   Multi-Region - Best for global scale
   5. ⭐⭐⭐    Kubernetes - Good if multi-cloud needed
   6. ⭐⭐⭐⭐⭐ Hybrid - Best long-term strategy
   7. ⭐⭐     Sharding - Niche use case

Top Recommendation for Medplum:
┌──────────────────────────────────────────────────────────────────┐
│ SHORT TERM (Now):                                                │
│   → Monolith + Serverless (stay simple)                         │
│                                                                  │
│ MEDIUM TERM (6-18 months):                                       │
│   → Cell Architecture (2-3 cells)                               │
│                                                                  │
│ LONG TERM (2-5 years):                                           │
│   → Hybrid (Cell + Microservices)                               │
│   → Multi-Region for global customers                           │
└──────────────────────────────────────────────────────────────────┘

Key Takeaway:
   • Don't over-engineer early
   • Cell architecture is the sweet spot for healthcare SaaS
   • Evolve gradually as you grow
   • Hybrid approaches give best results long-term
```

---

**Document Version:** 1.0  
**Date:** December 7, 2025  
**Author:** Cloud Architecture Team
