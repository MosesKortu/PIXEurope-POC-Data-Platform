<div align="center">

# PIXEurope Pilot Line POC Data Platform

**Strategic Data Infrastructure for Europe’s Photonics Future**

![Project Status](https://img.shields.io/badge/Status-Production%20Ready-00C853?style=for-the-badge)
![Funding](https://img.shields.io/badge/Funding-€400M%20Chips%20JU-1565C0?style=for-the-badge)
![Partners](https://img.shields.io/badge/Partners-20%20Institutions-9C27B0?style=for-the-badge)

**The "Digital Spine"** for the PIXEurope Pilot Line — enabling seamless interoperability, secure external access, and full regulatory compliance across Europe’s premier photonics ecosystem.

</div>

---

## Architecture Overview

A **Four-Tier Relational Schema** meticulously designed for maximum security, scalability, and EU research compliance.

| Tier              | Purpose                                      | Key Capabilities |
|-------------------|---------------------------------------------|------------------|
| **Core Schema**   | Internal asset & partner management         | Equipment registries, 20 partner institutions |
| **Gateway Schema**| External SME "Open Access" portal           | Service requests, CRM workflows |
| **Compliance Schema** | Audit & regulatory lockbox               | Automated trails, GDPR Data Subject Requests |
| **BI Schema**     | Executive intelligence layer                | Real-time KPIs & high-performance views |

---

## Key Features

### Automated Audit Traceability
Every critical change (equipment, procurement, configuration) is captured through **JSON-based Triggers**, storing complete "Before" and "After" states. 100% audit-ready for Chips JU reviews.

###  High-Performance Search
Sub-second queries even at scale, powered by **Non-Clustered Covering Indexes** on high-traffic columns (`PartnerID`, `EquipmentStatus`). Optimized for thousands of assets across 11 countries.


### Backend Coordination (FastAPI)
- The FastAPI (Python) layer acts as the "Gateway" logic controller:
- Validates SME VAT numbers.
- Coordinates cross-schema lookups (checking Core availability before confirming a Gateway request).
- Ensures all API traffic is logged for compliance.

### ⚖️ GDPR & FAIR Compliance
- **Findable** — Unique `AssetTag` identifiers
- **Accessible** — Role-based access via Gateway schema
- **Interoperable** — Standardized metadata across all partners
- **Reusable** — Integrated Data Management Plan (DMP) tracking

---

## 🛠️ Tech Stack

<div align="center">

![T-SQL](https://img.shields.io/badge/SQL%20Server-T--SQL-00AEEF?style=for-the-badge&logo=microsoftsqlserver&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.11+-3776AB?style=for-the-badge&logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)

</div>

**Additional Tools**
- **Mermaid.js** — Live ER diagrams
  
---
### Use Cases

- Service operations management
- Equipment lifecycle tracking
- Partner & company coordination
- Compliance and audit reporting

----

## Database ERD

```mermaid
erDiagram
    PARTNERS ||--o{ EQUIPMENT : owns
    PARTNERS ||--o{ SERVICE-REQUESTS : fulfills
    EQUIPMENT ||--o{ MAINTENANCE-ORDERS : requires
    COMPANIES ||--o{ SERVICE-REQUESTS : applies
    SERVICE-REQUESTS ||--o{ SERVICE-CATALOG : references
    EQUIPMENT }|--|| AUDIT-LOG : generates
    
    AUDIT-LOG ||--o{ COMPLIANCE-LOCKBOX : stored_in


