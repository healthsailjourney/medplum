# AWS Cell Architecture Analysis for Medplum

**Date:** December 7, 2025  
**Document Type:** Architecture Assessment  
**Status:** Recommendation & Analysis

---

## Table of Contents

1. [What is AWS Cell Architecture?](#what-is-aws-cell-architecture)
2. [Is Cell Architecture Relevant for Medplum?](#is-cell-architecture-relevant-for-medplum)
3. [Cell Architecture Benefits for Healthcare](#cell-architecture-benefits-for-healthcare)
4. [Medplum Cell Architecture Design](#medplum-cell-architecture-design)
5. [Implementation Roadmap](#implementation-roadmap)
6. [Cost-Benefit Analysis](#cost-benefit-analysis)
7. [Recommendations](#recommendations)

---

## What is AWS Cell Architecture?

### Definition

AWS Cell Architecture (also known as **Cell-Based Architecture** or **Bulkhead Pattern**) is a resilience pattern that:

- **Partitions infrastructure** into isolated cells
- **Limits blast radius** of failures to single cells
- **Prevents cascading failures** across the entire system
- **Enables independent scaling** per cell
- **Isolates tenant/customer data** for compliance

### Core Principles

```
┌────────────────────────────────────────────────────────────────────────┐
│                    Cell Architecture Principles                        │
└────────────────────────────────────────────────────────────────────────┘

1. Isolation
   • Each cell is completely independent
   • No shared state between cells
   • Failures in Cell A don't affect Cell B

2. Containment
   • Blast radius limited to single cell
   • Security breaches contained
   • Performance issues isolated

3. Redundancy
   • Multiple cells provide N+1 redundancy
   • Cell failure = automatic routing to healthy cells
   • No single point of failure

4. Predictability
   • Fixed capacity per cell
   • Known performance characteristics
   • Easier capacity planning

5. Repeatability
   • Cells are identical (Infrastructure as Code)
   • Easy to deploy new cells
   • Consistent behavior across cells
```

### Cell vs Traditional Architecture

```
┌────────────────────────────────────────────────────────────────────────┐
│                    Traditional Multi-AZ Architecture                   │
└────────────────────────────────────────────────────────────────────────┘

                        ┌─────────────┐
                        │     ALB     │
                        └──────┬──────┘
                               │
                ┌──────────────┴──────────────┐
                │                             │
         ┌──────▼──────┐               ┌──────▼──────┐
         │   AZ-A      │               │   AZ-B      │
         │             │               │             │
         │ App Tier    │◄─────────────►│ App Tier    │
         │ (Shared)    │  Sync Repl   │ (Shared)    │
         │             │               │             │
         └──────┬──────┘               └──────┬──────┘
                │                             │
                └──────────────┬──────────────┘
                               │
                        ┌──────▼──────┐
                        │  Single RDS │
                        │  (Multi-AZ) │
                        └─────────────┘

Problem: If RDS fails, ENTIRE system goes down
         All tenants share same infrastructure
         Limited blast radius control


┌────────────────────────────────────────────────────────────────────────┐
│                       Cell-Based Architecture                          │
└────────────────────────────────────────────────────────────────────────┘

                        ┌─────────────┐
                        │  Route 53   │
                        │ (Routing)   │
                        └──────┬──────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
   ┌────▼────┐           ┌────▼────┐           ┌────▼────┐
   │ Cell 1  │           │ Cell 2  │           │ Cell 3  │
   │         │           │         │           │         │
   │ ┌─────┐ │           │ ┌─────┐ │           │ ┌─────┐ │
   │ │ ALB │ │           │ │ ALB │ │           │ │ ALB │ │
   │ └──┬──┘ │           │ └──┬──┘ │           │ └──┬──┘ │
   │    │    │           │    │    │           │    │    │
   │ ┌──▼──┐ │           │ ┌──▼──┐ │           │ ┌──▼──┐ │
   │ │ App │ │           │ │ App │ │           │ │ App │ │
   │ └──┬──┘ │           │ └──┬──┘ │           │ └──┬──┘ │
   │    │    │           │    │    │           │    │    │
   │ ┌──▼──┐ │           │ ┌──▼──┐ │           │ ┌──▼──┐ │
   │ │ RDS │ │           │ │ RDS │ │           │ │ RDS │ │
   │ └─────┘ │           │ └─────┘ │           │ └─────┘ │
   │         │           │         │           │         │
   │Tenants: │           │Tenants: │           │Tenants: │
   │A, B, C  │           │D, E, F  │           │G, H, I  │
   └─────────┘           └─────────┘           └─────────┘

Benefit: If Cell 2 fails, only tenants D, E, F affected
         Tenants A, B, C, G, H, I continue working
         33% failure impact vs 100%
```

---

## Is Cell Architecture Relevant for Medplum?

### YES - Highly Relevant! Here's Why:

### 1. **Healthcare Compliance & Data Isolation**

```
┌────────────────────────────────────────────────────────────────────────┐
│             Healthcare Organizations Need Data Isolation               │
└────────────────────────────────────────────────────────────────────────┘

Scenario: Medplum serving multiple healthcare organizations

Traditional (Shared):
┌─────────────────────────────────────────────────────────────────────┐
│                      Single Database                                │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐          │
│  │ Hospital A    │  │ Clinic B      │  │ Practice C    │          │
│  │ Patient data  │  │ Patient data  │  │ Patient data  │          │
│  └───────────────┘  └───────────────┘  └───────────────┘          │
└─────────────────────────────────────────────────────────────────────┘

Problems:
❌ Shared database = higher risk of data leakage
❌ One tenant's traffic spike affects all others
❌ Compliance audits more complex
❌ Data residency requirements difficult


Cell-Based (Isolated):
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│    Cell 1        │  │    Cell 2        │  │    Cell 3        │
│  ┌────────────┐  │  │  ┌────────────┐  │  │  ┌────────────┐  │
│  │Hospital A  │  │  │  │ Clinic B   │  │  │  │Practice C  │  │
│  │Patient DB  │  │  │  │Patient DB  │  │  │  │Patient DB  │  │
│  └────────────┘  │  │  └────────────┘  │  │  └────────────┘  │
└──────────────────┘  └──────────────────┘  └──────────────────┘

Benefits:
✅ Complete data isolation (HIPAA requirement)
✅ Per-tenant performance guarantees
✅ Easier compliance audits
✅ Geographic data residency (EU cell, US cell)
✅ Tenant-specific encryption keys
```

### 2. **Multi-Tenancy Requirements**

Medplum is designed as a **multi-tenant healthcare platform**:

| Tenant Type | Cell Architecture Benefit |
|-------------|---------------------------|
| **Hospital Systems** | Dedicated cells for large organizations with predictable capacity |
| **Small Clinics** | Shared cells with resource pooling |
| **Research Institutions** | Isolated cells for PHI/PII compliance |
| **Telehealth Providers** | Geographic cells for latency optimization |

### 3. **Blast Radius Containment**

```
Healthcare Impact Analysis:

Traditional Architecture Failure:
┌─────────────────────────────────────────────────────────────────┐
│  Database Outage                                                │
│  ├── ALL hospitals affected                                     │
│  ├── ALL patient records inaccessible                          │
│  ├── ALL clinical workflows stopped                            │
│  └── Potential patient safety risk                             │
│                                                                 │
│  Impact: 100% of users                                          │
│  Recovery: All tenants wait for single fix                     │
└─────────────────────────────────────────────────────────────────┘

Cell Architecture Failure:
┌─────────────────────────────────────────────────────────────────┐
│  Cell 2 Database Outage                                         │
│  ├── Only Cell 2 hospitals affected (e.g., 10% of tenants)     │
│  ├── Other 90% of patients unaffected                          │
│  ├── Critical tenants can be moved to Cell 3                   │
│  └── Limited patient safety impact                             │
│                                                                 │
│  Impact: 10% of users (confined to one cell)                   │
│  Recovery: Parallel - fix Cell 2 while others operate          │
└─────────────────────────────────────────────────────────────────┘

Healthcare Scenario: Emergency Room

❌ Without Cells:
   Database failure → ER cannot access patient history
   → Delayed treatment for ALL ERs using Medplum

✅ With Cells:
   Cell 2 failure → Only ER in Cell 2 affected
   → Other hospitals continue normal operations
   → Failed hospital's traffic rerouted to Cell 3 in 30 seconds
```

### 4. **Regulatory & Compliance**

```
┌────────────────────────────────────────────────────────────────────────┐
│                 Compliance Benefits of Cell Architecture              │
└────────────────────────────────────────────────────────────────────────┘

1. HIPAA Compliance
   ┌─────────────────────────────────────────────────────────────┐
   │ • Per-cell encryption keys (AWS KMS)                        │
   │ • Isolated audit logs per tenant                            │
   │ • Access controls at cell boundary                          │
   │ • PHI never crosses cell boundaries                         │
   └─────────────────────────────────────────────────────────────┘

2. Data Residency (GDPR, Country-specific)
   ┌─────────────────────────────────────────────────────────────┐
   │  US Cell (us-east-1)        │  EU Cell (eu-west-1)         │
   │  - US patients only         │  - EU patients only          │
   │  - US compliance rules      │  - GDPR compliance           │
   │  - Data stays in US         │  - Data stays in EU          │
   └─────────────────────────────────────────────────────────────┘

3. Business Associate Agreements (BAA)
   ┌─────────────────────────────────────────────────────────────┐
   │ • Each cell can have separate BAA                           │
   │ • Tenant-specific compliance requirements                   │
   │ • Easier to demonstrate isolation in audits                 │
   └─────────────────────────────────────────────────────────────┘

4. Security Incident Containment
   ┌─────────────────────────────────────────────────────────────┐
   │ Security Breach Scenario:                                   │
   │                                                             │
   │ Without Cells:                                              │
   │   Compromised tenant → Potential access to ALL tenant data  │
   │                                                             │
   │ With Cells:                                                 │
   │   Compromised tenant → Isolated to single cell              │
   │   Other cells completely protected                          │
   └─────────────────────────────────────────────────────────────┘
```

### 5. **Performance Isolation**

```
┌────────────────────────────────────────────────────────────────────────┐
│                    Performance Isolation Benefits                      │
└────────────────────────────────────────────────────────────────────────┘

Problem: "Noisy Neighbor" in Healthcare

Scenario: Hospital A runs batch analytics job
          (Processing 1M patient records)

Without Cells:
┌─────────────────────────────────────────────────────────────────┐
│                      Shared Database                            │
│  ┌──────────────┐         ┌──────────────┐                     │
│  │ Hospital A   │         │ Clinic B     │                     │
│  │ Batch Job    │  ───►   │ Real-time    │  ◄── SLOW!         │
│  │ (Heavy Load) │         │ Patient Care │      (Impacted)     │
│  └──────────────┘         └──────────────┘                     │
│         ▲                        │                              │
│         └────────────────────────┘                              │
│              Same resources                                     │
└─────────────────────────────────────────────────────────────────┘

Result: ❌ Clinic B's patients experience slow EHR access
        ❌ Clinical workflows delayed
        ❌ Patient safety risk


With Cells:
┌─────────────────────┐       ┌─────────────────────┐
│      Cell 1         │       │      Cell 2         │
│  ┌──────────────┐   │       │  ┌──────────────┐   │
│  │ Hospital A   │   │       │  │ Clinic B     │   │
│  │ Batch Job    │   │       │  │ Real-time    │   │  ◄── FAST!
│  │ (Heavy Load) │   │       │  │ Patient Care │   │
│  └──────────────┘   │       │  └──────────────┘   │
│         ▲           │       │         ▲           │
│         │           │       │         │           │
│    Own DB & Cache   │       │    Own DB & Cache   │
└─────────────────────┘       └─────────────────────┘

Result: ✅ Clinic B unaffected
        ✅ Consistent performance
        ✅ SLA guaranteed per cell
```

---

## Medplum Cell Architecture Design

### Cell Architecture for Medplum

```
┌────────────────────────────────────────────────────────────────────────────────────┐
│                       Medplum Cell-Based Architecture                              │
│                                                                                    │
│                              ┌──────────────────┐                                 │
│                              │   Route 53       │                                 │
│                              │  Cell Routing    │                                 │
│                              │  (Geo/Tenant)    │                                 │
│                              └────────┬─────────┘                                 │
│                                       │                                            │
│              ┌────────────────────────┼────────────────────────┐                  │
│              │                        │                        │                  │
│     ┌────────▼────────┐      ┌───────▼────────┐      ┌───────▼────────┐         │
│     │  Control Plane  │      │  Control Plane │      │  Control Plane │         │
│     │   (Global)      │      │   (Regional)   │      │   (Regional)   │         │
│     │                 │      │                │      │                │         │
│     │ • Tenant Mgmt   │      │ • Health Check │      │ • Load Balance │         │
│     │ • Cell Registry │      │ • Metrics      │      │ • Failover     │         │
│     │ • Routing Rules │      │ • Alerting     │      │                │         │
│     └─────────────────┘      └────────────────┘      └────────────────┘         │
│                                       │                                            │
│              ┌────────────────────────┼────────────────────────┐                  │
│              │                        │                        │                  │
│     ┌────────▼────────┐      ┌───────▼────────┐      ┌───────▼────────┐         │
│     │                 │      │                │      │                │         │
│     │  CELL 1         │      │  CELL 2        │      │  CELL 3        │         │
│     │  (US-EAST)      │      │  (US-WEST)     │      │  (EU-WEST)     │         │
│     │                 │      │                │      │                │         │
│     │ ┌─────────────┐ │      │ ┌─────────────┐│      │ ┌─────────────┐│         │
│     │ │    VPC      │ │      │ │    VPC      ││      │ │    VPC      ││         │
│     │ │  10.1.0.0/16│ │      │ │  10.2.0.0/16││      │ │  10.3.0.0/16││         │
│     │ └─────────────┘ │      │ └─────────────┘│      │ └─────────────┘│         │
│     │                 │      │                │      │                │         │
│     │ ┌─────────────┐ │      │ ┌─────────────┐│      │ ┌─────────────┐│         │
│     │ │     ALB     │ │      │ │     ALB     ││      │ │     ALB     ││         │
│     │ └──────┬──────┘ │      │ └──────┬──────┘│      │ └──────┬──────┘│         │
│     │        │        │      │        │       │      │        │       │         │
│     │ ┌──────▼──────┐ │      │ ┌──────▼──────┐│      │ ┌──────▼──────┐│         │
│     │ │  Auto Scale │ │      │ │  Auto Scale ││      │ │  Auto Scale ││         │
│     │ │             │ │      │ │             ││      │ │             ││         │
│     │ │ ┌────────┐  │ │      │ │ ┌────────┐  ││      │ │ ┌────────┐  ││         │
│     │ │ │Medplum │  │ │      │ │ │Medplum │  ││      │ │ │Medplum │  ││         │
│     │ │ │API x4  │  │ │      │ │ │API x4  │  ││      │ │ │API x4  ││         │
│     │ │ └────────┘  │ │      │ │ └────────┘  ││      │ │ └────────┘  ││         │
│     │ │ ┌────────┐  │ │      │ │ ┌────────┐  ││      │ │ ┌────────┐  ││         │
│     │ │ │Web App │  │ │      │ │ │Web App │  ││      │ │ │Web App │  ││         │
│     │ │ │   x4   │  │ │      │ │ │   x4   │  ││      │ │ │   x4   │  ││         │
│     │ │ └────────┘  │ │      │ │ └────────┘  ││      │ │ └────────┘  ││         │
│     │ └─────────────┘ │      │ └─────────────┘│      │ └─────────────┘│         │
│     │        │        │      │        │       │      │        │       │         │
│     │ ┌──────▼──────┐ │      │ ┌──────▼──────┐│      │ ┌──────▼──────┐│         │
│     │ │     RDS     │ │      │ │     RDS     ││      │ │     RDS     ││         │
│     │ │ PostgreSQL  │ │      │ │ PostgreSQL  ││      │ │ PostgreSQL  ││         │
│     │ │  Multi-AZ   │ │      │ │  Multi-AZ   ││      │ │  Multi-AZ   ││         │
│     │ └─────────────┘ │      │ └─────────────┘│      │ └─────────────┘│         │
│     │                 │      │                │      │                │         │
│     │ ┌─────────────┐ │      │ ┌─────────────┐│      │ ┌─────────────┐│         │
│     │ │ElastiCache  │ │      │ │ElastiCache  ││      │ │ElastiCache  ││         │
│     │ │   Redis     │ │      │ │   Redis     ││      │ │   Redis     ││         │
│     │ └─────────────┘ │      │ └─────────────┘│      │ └─────────────┘│         │
│     │                 │      │                │      │                │         │
│     │ ┌─────────────┐ │      │ ┌─────────────┐│      │ ┌─────────────┐│         │
│     │ │     S3      │ │      │ │     S3      ││      │ │     S3      ││         │
│     │ │  (Cell-1)   │ │      │ │  (Cell-2)   ││      │ │  (Cell-3)   ││         │
│     │ └─────────────┘ │      │ └─────────────┘│      │ └─────────────┘│         │
│     │                 │      │                │      │                │         │
│     │ Tenants:        │      │ Tenants:       │      │ Tenants:       │         │
│     │ • Hospital A    │      │ • Clinic C     │      │ • EU Hospital F│         │
│     │ • Practice B    │      │ • Provider D   │      │ • EU Clinic G  │         │
│     │ • Lab E         │      │ • Telehealth H │      │ • EU Lab I     │         │
│     │                 │      │                │      │                │         │
│     │ Capacity:       │      │ Capacity:      │      │ Capacity:      │         │
│     │ 10,000 users    │      │ 10,000 users   │      │ 10,000 users   │         │
│     │ 100K patients   │      │ 100K patients  │      │ 100K patients  │         │
│     │                 │      │                │      │                │         │
│     └─────────────────┘      └────────────────┘      └────────────────┘         │
│                                                                                    │
└────────────────────────────────────────────────────────────────────────────────────┘

                            ┌──────────────────────────┐
                            │   Shared Services        │
                            │   (Global)               │
                            │                          │
                            │ • CloudWatch (Metrics)   │
                            │ • CloudTrail (Audit)     │
                            │ • Secrets Manager        │
                            │ • Certificate Manager    │
                            └──────────────────────────┘
```

### Cell Routing Strategy

```
┌────────────────────────────────────────────────────────────────────────┐
│                         Cell Routing Logic                             │
└────────────────────────────────────────────────────────────────────────┘

Route 53 Routing Policies:

1. Tenant-Based Routing (Primary)
   ┌─────────────────────────────────────────────────────────────┐
   │  User Request: https://medplum.com/api/fhir/Patient/123     │
   │  Header: X-Tenant-ID: hospital-a                            │
   │                                                             │
   │  Control Plane Lookup:                                      │
   │    hospital-a → Cell Registry → Cell 1 (us-east-1)         │
   │                                                             │
   │  Route 53 Response:                                         │
   │    cell1-alb.medplum.com → 10.1.x.x                        │
   └─────────────────────────────────────────────────────────────┘

2. Geographic Routing (Secondary)
   ┌─────────────────────────────────────────────────────────────┐
   │  User Location: San Francisco, CA                           │
   │  Nearest Cell: Cell 2 (us-west-2)                          │
   │                                                             │
   │  Route 53 Geolocation Policy:                               │
   │    US-West → cell2-alb.medplum.com                         │
   │    US-East → cell1-alb.medplum.com                         │
   │    EU      → cell3-alb.medplum.com                         │
   └─────────────────────────────────────────────────────────────┘

3. Health-Based Failover (Tertiary)
   ┌─────────────────────────────────────────────────────────────┐
   │  Primary: Cell 1                                            │
   │  Status: UNHEALTHY (Failed health check)                    │
   │                                                             │
   │  Route 53 Failover:                                         │
   │    Cell 1 (DOWN) → Route to Cell 2 (HEALTHY)              │
   │    TTL: 60 seconds                                          │
   │    Notification: SNS → Ops Team                            │
   └─────────────────────────────────────────────────────────────┘

4. Load-Based Routing (Optional)
   ┌─────────────────────────────────────────────────────────────┐
   │  Cell 1: 80% capacity (8,000 / 10,000 users)               │
   │  Cell 2: 40% capacity (4,000 / 10,000 users)               │
   │                                                             │
   │  New Tenant Assignment:                                     │
   │    Assign to Cell 2 (lower utilization)                    │
   │    Update Cell Registry                                     │
   └─────────────────────────────────────────────────────────────┘

Cell Assignment Logic:

┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  function assignTenantToCell(tenant) {                          │
│    // 1. Check data residency requirements                     │
│    if (tenant.dataResidency === 'EU') {                        │
│      return 'cell-3-eu-west';                                  │
│    }                                                            │
│                                                                 │
│    // 2. Check enterprise tier (dedicated cells)               │
│    if (tenant.tier === 'ENTERPRISE') {                         │
│      return createDedicatedCell(tenant);                       │
│    }                                                            │
│                                                                 │
│    // 3. Find cell with lowest utilization                     │
│    const cells = getCellsByRegion(tenant.region);              │
│    const leastUtilized = cells.sort((a, b) =>                  │
│      a.utilization - b.utilization                             │
│    )[0];                                                        │
│                                                                 │
│    // 4. Check if cell has capacity                            │
│    if (leastUtilized.utilization < 0.8) {                      │
│      return leastUtilized.id;                                  │
│    }                                                            │
│                                                                 │
│    // 5. Create new cell if all are at capacity                │
│    return createNewCell(tenant.region);                        │
│  }                                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Cell Types for Medplum

```
┌────────────────────────────────────────────────────────────────────────┐
│                      Medplum Cell Type Strategy                        │
└────────────────────────────────────────────────────────────────────────┘

1. Shared Multi-Tenant Cells (Standard Tier)
   ┌──────────────────────────────────────────────────────────────┐
   │ Use Case: Small clinics, private practices (< 1,000 users)   │
   │                                                              │
   │ Configuration:                                               │
   │  • 10-20 tenants per cell                                   │
   │  • Shared RDS (logical database per tenant)                 │
   │  • Shared ElastiCache                                       │
   │  • Cost-effective                                            │
   │                                                              │
   │ Examples:                                                    │
   │  • Small dental practice                                     │
   │  • Solo physician office                                     │
   │  • Urgent care clinic                                        │
   └──────────────────────────────────────────────────────────────┘

2. Dedicated Cells (Enterprise Tier)
   ┌──────────────────────────────────────────────────────────────┐
   │ Use Case: Large hospitals, health systems (> 10,000 users)   │
   │                                                              │
   │ Configuration:                                               │
   │  • 1 tenant per cell                                        │
   │  • Dedicated RDS instance                                    │
   │  • Dedicated ElastiCache cluster                             │
   │  • Custom capacity limits                                    │
   │  • SLA guarantees                                            │
   │                                                              │
   │ Examples:                                                    │
   │  • Mayo Clinic                                               │
   │  • Kaiser Permanente                                         │
   │  • Large hospital network                                    │
   └──────────────────────────────────────────────────────────────┘

3. Regional Cells (Geographic)
   ┌──────────────────────────────────────────────────────────────┐
   │ Use Case: Data residency, latency optimization               │
   │                                                              │
   │ Configuration:                                               │
   │  • US-East Cell (Virginia)                                  │
   │  • US-West Cell (Oregon)                                    │
   │  • EU Cell (Ireland) - GDPR compliance                      │
   │  • Asia-Pacific Cell (Singapore) - Optional                 │
   │                                                              │
   │ Routing:                                                     │
   │  • Route 53 geolocation routing                             │
   │  • Lowest latency to users                                   │
   │  • Compliance with local regulations                         │
   └──────────────────────────────────────────────────────────────┘

4. Development/Staging Cells
   ┌──────────────────────────────────────────────────────────────┐
   │ Use Case: Testing, development, pre-production               │
   │                                                              │
   │ Configuration:                                               │
   │  • Lower-spec instances (t3.medium)                         │
   │  • Shared across all dev teams                              │
   │  • Separate from production cells                            │
   │  • Refreshed from prod snapshots                             │
   └──────────────────────────────────────────────────────────────┘

5. Disaster Recovery Cells
   ┌──────────────────────────────────────────────────────────────┐
   │ Use Case: Business continuity, failover                      │
   │                                                              │
   │ Configuration:                                               │
   │  • Warm standby (minimal compute)                           │
   │  • Cross-region RDS replicas                                │
   │  • Can be promoted to active in emergency                    │
   │  • Cost-optimized (only storage + minimal compute)           │
   └──────────────────────────────────────────────────────────────┘
```

---

## Cell Architecture Benefits for Healthcare

### Specific Benefits for Medplum

```
┌────────────────────────────────────────────────────────────────────────┐
│                Healthcare-Specific Cell Benefits                       │
└────────────────────────────────────────────────────────────────────────┘

1. Patient Safety
   ┌──────────────────────────────────────────────────────────────┐
   │ Scenario: Database failure during surgery                    │
   │                                                              │
   │ Without Cells:                                               │
   │   ALL hospitals lose access to patient records              │
   │   ⚠️  Critical patient safety risk                          │
   │                                                              │
   │ With Cells:                                                  │
   │   Only one cell affected (e.g., 10% of hospitals)           │
   │   ✅ 90% of patients unaffected                             │
   │   ✅ Critical hospital can failover to backup cell in 30s   │
   └──────────────────────────────────────────────────────────────┘

2. Regulatory Compliance
   ┌──────────────────────────────────────────────────────────────┐
   │ HIPAA Requirement: Minimum Necessary Standard                │
   │                                                              │
   │ Cell Architecture Compliance:                                │
   │   ✅ Each tenant only accesses their own cell                │
   │   ✅ No cross-tenant data access possible                    │
   │   ✅ Easier to audit and demonstrate compliance              │
   │   ✅ Breach affects only one cell, not entire system         │
   └──────────────────────────────────────────────────────────────┘

3. Performance SLAs
   ┌──────────────────────────────────────────────────────────────┐
   │ Enterprise Hospital Contract:                                │
   │   "99.99% uptime, < 500ms API response time"                │
   │                                                              │
   │ Cell Architecture Enablement:                                │
   │   ✅ Dedicated cell = predictable performance                │
   │   ✅ No noisy neighbors                                      │
   │   ✅ Can overprovision resources for critical tenants        │
   │   ✅ Independent monitoring per cell                         │
   └──────────────────────────────────────────────────────────────┘

4. Data Sovereignty
   ┌──────────────────────────────────────────────────────────────┐
   │ Example: European hospital using Medplum                     │
   │                                                              │
   │ GDPR Requirement:                                            │
   │   Patient data must stay in EU                              │
   │                                                              │
   │ Cell Solution:                                               │
   │   EU Cell (eu-west-1)                                       │
   │   ✅ All data stored in Ireland AWS region                   │
   │   ✅ No cross-region data transfer                           │
   │   ✅ GDPR-compliant by design                                │
   └──────────────────────────────────────────────────────────────┘

5. Disaster Recovery Testing
   ┌──────────────────────────────────────────────────────────────┐
   │ Healthcare Requirement: Must test DR annually                │
   │                                                              │
   │ Cell Architecture Advantage:                                 │
   │   ✅ Can test DR on Cell 3 without affecting Cell 1, 2      │
   │   ✅ Simulate failures safely                                │
   │   ✅ No production impact during DR tests                    │
   │   ✅ Prove recovery procedures work                          │
   └──────────────────────────────────────────────────────────────┘

6. Gradual Rollouts
   ┌──────────────────────────────────────────────────────────────┐
   │ Scenario: Deploy new Medplum version                         │
   │                                                              │
   │ Canary Deployment by Cell:                                   │
   │   Week 1: Deploy to Cell 3 (dev/test tenants)              │
   │   Week 2: Deploy to Cell 2 (mid-size tenants)              │
   │   Week 3: Deploy to Cell 1 (enterprise tenants)            │
   │                                                              │
   │ Benefit:                                                     │
   │   ✅ Catch bugs before affecting all customers               │
   │   ✅ Easy rollback per cell                                  │
   │   ✅ Minimize blast radius of bad deployments                │
   └──────────────────────────────────────────────────────────────┘
```

---

## Implementation Roadmap

### Phase-by-Phase Implementation

```
┌────────────────────────────────────────────────────────────────────────┐
│                   Cell Architecture Implementation Phases              │
└────────────────────────────────────────────────────────────────────────┘

Phase 0: Current State (COMPLETE)
┌──────────────────────────────────────────────────────────────────────┐
│ • Single EC2 instance                                                │
│ • Docker PostgreSQL + Redis                                          │
│ • Single tenant (development)                                        │
│                                                                      │
│ Duration: N/A (Current)                                              │
│ Cost: $144/month                                                     │
└──────────────────────────────────────────────────────────────────────┘

Phase 1: Foundation (3-6 months)
┌──────────────────────────────────────────────────────────────────────┐
│ Goals:                                                               │
│   • Multi-tenant capability                                          │
│   • Managed services (RDS, ElastiCache)                             │
│   • Basic cell infrastructure                                        │
│                                                                      │
│ Tasks:                                                               │
│   ✓ Implement tenant identification (X-Tenant-ID header)            │
│   ✓ Database schema per tenant (logical isolation)                  │
│   ✓ Migrate to RDS PostgreSQL (Multi-AZ)                            │
│   ✓ Migrate to ElastiCache Redis                                    │
│   ✓ Implement tenant registry service                               │
│   ✓ Add CloudWatch monitoring per tenant                            │
│                                                                      │
│ Infrastructure:                                                      │
│   • 1 Cell (us-east-1)                                              │
│   • Shared multi-tenant RDS                                          │
│   • ALB with tenant routing                                          │
│                                                                      │
│ Cost: ~$600/month                                                    │
└──────────────────────────────────────────────────────────────────────┘

Phase 2: Cell Deployment (6-9 months)
┌──────────────────────────────────────────────────────────────────────┐
│ Goals:                                                               │
│   • Deploy second cell                                               │
│   • Implement cell routing                                           │
│   • Test cell failover                                               │
│                                                                      │
│ Tasks:                                                               │
│   ✓ Deploy Cell 2 (us-west-2) - identical to Cell 1                │
│   ✓ Implement Route 53 cell routing logic                           │
│   ✓ Build cell control plane                                        │
│   ✓ Tenant migration tooling (move tenant between cells)            │
│   ✓ Cross-cell monitoring dashboard                                 │
│   ✓ Cell failover automation                                        │
│                                                                      │
│ Infrastructure:                                                      │
│   • 2 Cells (us-east-1, us-west-2)                                  │
│   • Independent RDS per cell                                         │
│   • Cell registry (DynamoDB)                                         │
│                                                                      │
│ Cost: ~$1,200/month (2 cells)                                        │
└──────────────────────────────────────────────────────────────────────┘

Phase 3: Geographic Expansion (9-12 months)
┌──────────────────────────────────────────────────────────────────────┐
│ Goals:                                                               │
│   • EU data residency                                                │
│   • Global performance optimization                                  │
│   • GDPR compliance                                                  │
│                                                                      │
│ Tasks:                                                               │
│   ✓ Deploy Cell 3 (eu-west-1)                                       │
│   ✓ Implement geographic routing                                    │
│   ✓ GDPR compliance verification                                    │
│   ✓ Cross-region replication for DR (optional)                      │
│   ✓ Latency-based routing                                           │
│                                                                      │
│ Infrastructure:                                                      │
│   • 3 Cells (us-east, us-west, eu-west)                            │
│   • Regional data residency                                          │
│   • CloudFront for global CDN                                        │
│                                                                      │
│ Cost: ~$1,800/month (3 cells)                                        │
└──────────────────────────────────────────────────────────────────────┘

Phase 4: Enterprise Cells (12+ months)
┌──────────────────────────────────────────────────────────────────────┐
│ Goals:                                                               │
│   • Dedicated cells for enterprise customers                        │
│   • SLA guarantees                                                   │
│   • Custom capacity management                                       │
│                                                                      │
│ Tasks:                                                               │
│   ✓ Automated cell provisioning (Terraform)                         │
│   ✓ Cell-specific SLA monitoring                                    │
│   ✓ Custom capacity per cell                                        │
│   ✓ Multi-cell DR strategy                                          │
│   ✓ Cost allocation per cell                                        │
│                                                                      │
│ Infrastructure:                                                      │
│   • N cells (on-demand creation)                                     │
│   • Cell templates (small, medium, large, enterprise)               │
│   • Automated scaling per cell                                      │
│                                                                      │
│ Cost: Variable (per customer)                                        │
└──────────────────────────────────────────────────────────────────────┘
```

### Technical Implementation Steps

```
┌────────────────────────────────────────────────────────────────────────┐
│                 Step-by-Step Technical Implementation                  │
└────────────────────────────────────────────────────────────────────────┘

Step 1: Tenant Identification
┌──────────────────────────────────────────────────────────────────┐
│ Code Changes:                                                    │
│                                                                  │
│ // Add tenant middleware                                        │
│ app.use((req, res, next) => {                                   │
│   const tenantId = req.headers['x-tenant-id'] ||                │
│                   extractFromDomain(req.hostname);              │
│                                                                  │
│   if (!tenantId) {                                              │
│     return res.status(400).json({                               │
│       error: 'Missing tenant identification'                    │
│     });                                                          │
│   }                                                              │
│                                                                  │
│   req.tenantId = tenantId;                                      │
│   next();                                                        │
│ });                                                              │
│                                                                  │
│ // Database connection with tenant schema                       │
│ const db = getConnectionForTenant(req.tenantId);                │
└──────────────────────────────────────────────────────────────────┘

Step 2: Cell Registry
┌──────────────────────────────────────────────────────────────────┐
│ DynamoDB Table: cell-registry                                   │
│                                                                  │
│ Schema:                                                          │
│ {                                                                │
│   "tenantId": "hospital-a",        // Partition Key            │
│   "cellId": "cell-1-us-east",      // Cell assignment          │
│   "region": "us-east-1",                                        │
│   "tier": "ENTERPRISE",            // STANDARD, ENTERPRISE      │
│   "capacity": {                                                  │
│     "maxUsers": 10000,                                          │
│     "maxPatients": 100000,                                      │
│     "currentUsers": 4523                                        │
│   },                                                             │
│   "createdAt": "2025-01-01T00:00:00Z",                         │
│   "updatedAt": "2025-12-07T00:00:00Z",                         │
│   "status": "ACTIVE"               // ACTIVE, MIGRATING, DOWN   │
│ }                                                                │
└──────────────────────────────────────────────────────────────────┘

Step 3: Cell Routing Service
┌──────────────────────────────────────────────────────────────────┐
│ Lambda Function: cell-router                                    │
│                                                                  │
│ exports.handler = async (event) => {                            │
│   const tenantId = event.headers['x-tenant-id'];               │
│                                                                  │
│   // Lookup cell assignment                                     │
│   const tenant = await dynamodb.getItem({                       │
│     TableName: 'cell-registry',                                 │
│     Key: { tenantId }                                           │
│   });                                                            │
│                                                                  │
│   if (!tenant || tenant.status !== 'ACTIVE') {                 │
│     // Check for failover cell                                  │
│     const failoverCell = await getFailoverCell(tenantId);      │
│     return routeToCell(failoverCell);                           │
│   }                                                              │
│                                                                  │
│   // Route to assigned cell                                     │
│   const cellEndpoint = getCellEndpoint(tenant.cellId);         │
│   return {                                                       │
│     statusCode: 307,                                            │
│     headers: {                                                   │
│       'Location': cellEndpoint + event.path                    │
│     }                                                            │
│   };                                                             │
│ };                                                               │
└──────────────────────────────────────────────────────────────────┘

Step 4: Cell Health Monitoring
┌──────────────────────────────────────────────────────────────────┐
│ CloudWatch Metrics Per Cell:                                    │
│                                                                  │
│ • cell_health_status (1=healthy, 0=unhealthy)                  │
│ • cell_request_count                                            │
│ • cell_error_rate                                               │
│ • cell_cpu_utilization                                          │
│ • cell_db_connections                                           │
│ • cell_active_users                                             │
│                                                                  │
│ Alarms:                                                          │
│   - Cell health status = 0 → SNS → Failover Lambda             │
│   - Cell error rate > 5% → SNS → Ops Team                      │
│   - Cell capacity > 90% → SNS → Scale Up                       │
└──────────────────────────────────────────────────────────────────┘

Step 5: Cell Failover Automation
┌──────────────────────────────────────────────────────────────────┐
│ Lambda Function: cell-failover                                  │
│                                                                  │
│ exports.handler = async (event) => {                            │
│   const failedCell = event.detail.cellId;                       │
│                                                                  │
│   // Get all tenants in failed cell                             │
│   const tenants = await getTenantsInCell(failedCell);          │
│                                                                  │
│   // Find healthy backup cell                                   │
│   const backupCell = await findHealthyCell(                     │
│     failedCell.region                                           │
│   );                                                             │
│                                                                  │
│   // Update Route 53 records                                    │
│   for (const tenant of tenants) {                               │
│     await route53.changeResourceRecordSets({                    │
│       HostedZoneId: ZONE_ID,                                    │
│       ChangeBatch: {                                            │
│         Changes: [{                                             │
│           Action: 'UPSERT',                                     │
│           ResourceRecordSet: {                                  │
│             Name: `${tenant.subdomain}.medplum.com`,           │
│             Type: 'CNAME',                                      │
│             TTL: 60,                                            │
│             ResourceRecords: [{                                 │
│               Value: backupCell.endpoint                        │
│             }]                                                   │
│           }                                                      │
│         }]                                                       │
│       }                                                          │
│     });                                                          │
│                                                                  │
│     // Update cell registry                                     │
│     await updateTenantCell(tenant.id, backupCell.id);          │
│   }                                                              │
│                                                                  │
│   // Send notifications                                         │
│   await sns.publish({                                           │
│     TopicArn: OPS_TOPIC,                                        │
│     Message: `Failover complete: ${failedCell} → ${backupCell}`│
│   });                                                            │
│ };                                                               │
└──────────────────────────────────────────────────────────────────┘
```

---

## Cost-Benefit Analysis

### Cell Architecture Costs

```
┌────────────────────────────────────────────────────────────────────────┐
│                  Cost Comparison: Traditional vs Cells                 │
└────────────────────────────────────────────────────────────────────────┘

Scenario: 100,000 total users across 100 healthcare organizations

Traditional Multi-AZ (Non-Cell):
┌──────────────────────────────────────────────────────────────────┐
│ • 1 Large RDS (db.r6g.4xlarge): $1,040/month                    │
│ • 1 Large ElastiCache (cache.r6g.2xlarge): $560/month           │
│ • 8x EC2 (t3.xlarge): $992/month                                │
│ • ALB: $25/month                                                 │
│ • Data transfer: $200/month                                      │
│ • Monitoring: $50/month                                          │
│                                                                  │
│ TOTAL: $2,867/month                                              │
│                                                                  │
│ Risk Profile:                                                    │
│   ⚠️  Single point of failure (RDS)                             │
│   ⚠️  100% of users affected by outage                          │
│   ⚠️  Noisy neighbor issues                                     │
│   ⚠️  Difficult to isolate tenant performance                   │
└──────────────────────────────────────────────────────────────────┘

Cell-Based Architecture (5 Cells):
┌──────────────────────────────────────────────────────────────────┐
│ Per Cell (20,000 users each):                                   │
│   • RDS (db.r6g.xlarge): $260/month                             │
│   • ElastiCache (cache.r6g.large): $140/month                   │
│   • 2x EC2 (t3.xlarge): $248/month                              │
│   • ALB: $25/month                                               │
│                                                                  │
│ Cost per cell: $673/month                                        │
│                                                                  │
│ Total for 5 cells: $3,365/month                                  │
│                                                                  │
│ Additional:                                                      │
│   • Control Plane (Lambda + DynamoDB): $50/month                │
│   • Cross-region transfer: $100/month                            │
│   • Monitoring (CloudWatch): $100/month                          │
│                                                                  │
│ TOTAL: $3,615/month                                              │
│                                                                  │
│ Additional Cost: $748/month (26% more)                           │
│                                                                  │
│ Risk Profile:                                                    │
│   ✅ Isolated failures (20% impact max)                         │
│   ✅ Noisy neighbor isolation                                   │
│   ✅ Predictable performance per cell                           │
│   ✅ Geographic distribution                                     │
└──────────────────────────────────────────────────────────────────┘

ROI Analysis:
┌──────────────────────────────────────────────────────────────────┐
│ Cost of Downtime (Healthcare):                                  │
│   • Average hospital: $10,000/hour of EHR downtime              │
│   • With 100 hospitals: $1M/hour system-wide                    │
│                                                                  │
│ Traditional Architecture:                                        │
│   • 1 critical failure = 100% downtime = $1M/hour               │
│   • Annual failure budget (99.9%): 8.76 hours                   │
│   • Downtime cost: $8.76M/year                                   │
│                                                                  │
│ Cell Architecture:                                               │
│   • 1 cell failure = 20% downtime = $200K/hour                  │
│   • Automatic failover: 30 seconds = $1.7K                      │
│   • Annual downtime cost: ~$100K/year                            │
│                                                                  │
│ Savings: $8.66M/year                                             │
│                                                                  │
│ ROI: ($8.66M - $9K extra cost) / $9K = 96,111%                  │
│                                                                  │
│ Payback Period: < 1 hour                                        │
└──────────────────────────────────────────────────────────────────┘
```

### Value Propositions

```
┌────────────────────────────────────────────────────────────────────────┐
│                    Cell Architecture Value Analysis                    │
└────────────────────────────────────────────────────────────────────────┘

For Small/Medium Organizations (Shared Cells):
┌──────────────────────────────────────────────────────────────────┐
│ Benefits:                                                        │
│   ✅ Same high availability as enterprise                       │
│   ✅ Cost-effective ($200-500/month per tenant)                 │
│   ✅ Isolated from other tenants' performance issues            │
│   ✅ Automatic failover to backup cell                          │
│   ✅ Compliance ready (HIPAA, GDPR)                             │
│                                                                  │
│ Trade-offs:                                                      │
│   ⚠️  Shared resources with other tenants                       │
│   ⚠️  Standard SLA (99.9%)                                      │
└──────────────────────────────────────────────────────────────────┘

For Enterprise Organizations (Dedicated Cells):
┌──────────────────────────────────────────────────────────────────┐
│ Benefits:                                                        │
│   ✅ Dedicated infrastructure                                   │
│   ✅ Custom SLA (99.99%+)                                        │
│   ✅ Predictable performance                                     │
│   ✅ Capacity customization                                      │
│   ✅ Priority support                                            │
│   ✅ Can run in customer's AWS account (optional)               │
│                                                                  │
│ Pricing:                                                         │
│   💰 $2,000-10,000/month (based on capacity)                    │
│   💰 Volume discounts available                                 │
└──────────────────────────────────────────────────────────────────┘

Competitive Advantages:
┌──────────────────────────────────────────────────────────────────┐
│ vs Epic/Cerner (Traditional EHR):                               │
│   ✅ Modern cloud-native architecture                           │
│   ✅ Better uptime (cell isolation)                             │
│   ✅ Faster innovation (canary deployments)                     │
│   ✅ Lower total cost of ownership                              │
│                                                                  │
│ vs Other FHIR Platforms:                                         │
│   ✅ Enterprise-grade availability                              │
│   ✅ Compliance-first design                                     │
│   ✅ Performance guarantees                                      │
│   ✅ Geographic data residency                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## Recommendations

### For Medplum Development Team

```
┌────────────────────────────────────────────────────────────────────────┐
│                         Strategic Recommendations                      │
└────────────────────────────────────────────────────────────────────────┘

SHORT TERM (0-6 months):
┌──────────────────────────────────────────────────────────────────┐
│ ✅ RECOMMENDED: Implement cell architecture foundation           │
│                                                                  │
│ Actions:                                                         │
│   1. Add tenant identification to Medplum API                   │
│   2. Design database schema for multi-tenancy                   │
│   3. Create cell registry (DynamoDB)                            │
│   4. Implement basic cell routing (Route 53)                    │
│   5. Deploy second cell for testing                             │
│                                                                  │
│ Why Now:                                                         │
│   • Easier to implement early (before too many customers)       │
│   • Enables enterprise sales conversations                      │
│   • Differentiates from competitors                             │
│   • Sets foundation for compliance certifications               │
│                                                                  │
│ Effort: 2-3 engineers, 3 months                                 │
│ Cost: +$600/month infrastructure                                 │
└──────────────────────────────────────────────────────────────────┘

MEDIUM TERM (6-12 months):
┌──────────────────────────────────────────────────────────────────┐
│ ✅ RECOMMENDED: Multi-region cell deployment                     │
│                                                                  │
│ Actions:                                                         │
│   1. Deploy EU cell (GDPR compliance)                           │
│   2. Implement geographic routing                               │
│   3. Add cell failover automation                               │
│   4. Create enterprise tier offering                            │
│                                                                  │
│ Why:                                                             │
│   • Opens European market                                        │
│   • Enables enterprise contracts                                │
│   • Reduces global latency                                       │
│                                                                  │
│ Effort: 1-2 engineers, 4 months                                 │
│ Cost: +$1,200/month infrastructure                               │
└──────────────────────────────────────────────────────────────────┘

LONG TERM (12+ months):
┌──────────────────────────────────────────────────────────────────┐
│ ✅ RECOMMENDED: Automated cell management                        │
│                                                                  │
│ Actions:                                                         │
│   1. Self-service cell provisioning for enterprise              │
│   2. Cell scaling automation                                     │
│   3. Advanced routing (latency, cost-based)                     │
│   4. Multi-cell disaster recovery                               │
│                                                                  │
│ Why:                                                             │
│   • Scales to hundreds of cells                                 │
│   • Reduces operational overhead                                │
│   • Enables rapid customer onboarding                           │
│                                                                  │
│ Effort: 2-3 engineers, ongoing                                  │
│ Cost: Variable (per customer)                                    │
└──────────────────────────────────────────────────────────────────┘
```

### Decision Framework

```
┌────────────────────────────────────────────────────────────────────────┐
│              Should Medplum Adopt Cell Architecture?                   │
└────────────────────────────────────────────────────────────────────────┘

ANSWER: YES - Highly Recommended

Scoring:

┌─────────────────────────────────┬─────────┬──────────────────────┐
│ Factor                          │ Score   │ Rationale            │
├─────────────────────────────────┼─────────┼──────────────────────┤
│ Healthcare Compliance           │ 10/10   │ HIPAA, GDPR critical │
│ Multi-Tenancy Requirements      │ 10/10   │ Core business model  │
│ Blast Radius Containment        │ 10/10   │ Patient safety risk  │
│ Performance Isolation           │  9/10   │ Enterprise SLAs      │
│ Geographic Distribution         │  8/10   │ EU market expansion  │
│ Implementation Complexity       │  5/10   │ Moderate effort      │
│ Cost                            │  7/10   │ +26% but justified   │
│ Competitive Advantage           │  9/10   │ Market differentiator│
├─────────────────────────────────┼─────────┼──────────────────────┤
│ TOTAL                           │ 68/80   │ STRONG YES           │
└─────────────────────────────────┴─────────┴──────────────────────┘

Recommendation: IMPLEMENT

Priority: HIGH

Timeline: Start immediately (Phase 1 in Q1 2026)
```

---

## Conclusion

### Executive Summary

```
┌────────────────────────────────────────────────────────────────────────┐
│                         Executive Summary                              │
└────────────────────────────────────────────────────────────────────────┘

AWS Cell Architecture is HIGHLY RELEVANT and RECOMMENDED for Medplum:

✅ Key Benefits:
   1. Patient Safety: Limits outage impact to single cells
   2. Compliance: HIPAA/GDPR ready with data isolation
   3. Performance: Eliminates noisy neighbor problems
   4. Scalability: Support enterprise & small customers
   5. Competitive Edge: Differentiation in market

💰 Investment:
   • Initial: 3-6 months development time
   • Cost: +26% infrastructure ($748/month for 5 cells)
   • ROI: 96,111% (downtime cost savings)

⚠️  Considerations:
   • Increased operational complexity
   • Requires multi-tenant architecture changes
   • Control plane development needed

📊 Verdict:
   Implement cell architecture in phases, starting with foundation
   (tenant identification, cell registry, basic routing) in Q1 2026.

   The benefits for healthcare far outweigh the costs, particularly
   for patient safety, compliance, and enterprise sales.
```

---

**Document Version:** 1.0  
**Date:** December 7, 2025  
**Author:** Cloud Architecture Team  
**Recommendation:** IMPLEMENT - HIGH PRIORITY
