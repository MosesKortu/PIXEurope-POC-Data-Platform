erDiagram
PARTNERS ||--o{ EQUIPMENT : "hosts"
PARTNERS ||--o{ PROCUREMENT_ORDERS : "leads"
PARTNERS ||--o{ SERVICE_REQUESTS : "fulfills"
PARTNERS ||--o{ DMP_MILESTONES : "responsible_for"

    EQUIPMENT_CATEGORIES ||--o{ EQUIPMENT : "defines"

    EXTERNAL_COMPANIES ||--o{ SERVICE_REQUESTS : "submits"
    EXTERNAL_COMPANIES ||--o{ GDPR_REQUESTS : "initiates"

    SERVICE_CATALOG ||--o{ SERVICE_REQUESTS : "offered_as"

    CORE_TABLES {
        int PartnerID PK
        int EquipmentID PK
        int CategoryID PK
    }

    GATEWAY_TABLES {
        int CompanyID PK
        int RequestID PK
    }
