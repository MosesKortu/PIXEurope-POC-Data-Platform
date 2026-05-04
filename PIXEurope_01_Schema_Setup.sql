-- ============================================================
-- PIXEurope Pilot Line Data Platform
-- MODULE 1: DATABASE SCHEMA & SETUP
-- SQL Server (T-SQL)
-- Author: Moses Bargue Kortu Jr. (Practice Build)
-- Purpose: Interview Practice & Role Preparation
-- ============================================================

-- ============================================================
-- JARGON GLOSSARY (as SQL comments — study these)
-- ============================================================
-- SCHEMA       : A logical container (namespace) grouping related tables.
--                Like folders in a filing cabinet. We use: Core, Gateway, Compliance.
-- PRIMARY KEY  : Unique identifier for every row. No two rows can share it.
-- FOREIGN KEY  : A column that links to a primary key in another table.
--                Enforces referential integrity — you cannot reference what doesn't exist.
-- SURROGATE KEY: A system-generated ID (INT IDENTITY) with no business meaning.
--                Preferred over "natural" keys (like email) that can change.
-- INDEX        : A lookup structure speeding up queries. Like a book's index.
--                CLUSTERED = physically sorts the table. Only 1 allowed per table.
--                NONCLUSTERED = separate lookup structure. Many allowed.
-- VIEW         : A saved SELECT query. Acts like a virtual table.
--                Does NOT store data — always runs the query fresh.
-- STORED PROC  : Pre-compiled T-SQL block with parameters. Faster & more secure than ad-hoc queries.
-- TRIGGER      : Code that fires automatically on INSERT/UPDATE/DELETE. Used for audit trails.
-- AUDIT TRAIL  : Immutable log of every data change — who, what, when. EU compliance requirement.
-- FAIR DATA    : Findable, Accessible, Interoperable, Reusable — EU research data standard.
-- TRACEABILITY : Ability to reconstruct the full history of any data record.
-- ============================================================

USE MyDatabase;
GO

-- Create the database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'PIXEurope')
BEGIN
    CREATE DATABASE PIXEurope
    COLLATE Latin1_General_CI_AS;  -- Case-insensitive, accent-sensitive (Spanish-safe)
END
GO

USE PIXEurope;
GO

-- ============================================================
-- SCHEMAS: Logical groupings (like departments)
-- ============================================================
-- Core     = Internal Pilot Line operations (equipment, partners, procurement)
-- Gateway  = External-facing Open Access (companies requesting services)
-- Compliance = Audit trails, GDPR logs, DMP tracking
-- BI       = Reporting views (stakeholder dashboards)
-- ============================================================

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Core')
    EXEC('CREATE SCHEMA Core');
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Gateway')
    EXEC('CREATE SCHEMA Gateway');
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'Compliance')
    EXEC('CREATE SCHEMA Compliance');
GO
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'BI')
    EXEC('CREATE SCHEMA BI');
GO

-- ============================================================
-- CORE SCHEMA: Partner Institutions
-- ============================================================
-- USE CASE: PIXEurope has 20 partners across 11 countries.
-- Every piece of equipment, every procurement order, every dataset
-- must be traceable back to a partner institution.
-- ============================================================

CREATE TABLE Core.Partners (
    PartnerID       INT IDENTITY(1,1)   NOT NULL,   -- Surrogate key, auto-increments
    PartnerCode     NVARCHAR(10)        NOT NULL,   -- Short code: 'ICFO', 'IMEC', 'CEA'
    PartnerName     NVARCHAR(200)       NOT NULL,   -- Full institutional name
    Country         NVARCHAR(100)       NOT NULL,   -- ISO country name
    CountryCode     CHAR(2)             NOT NULL,   -- ISO 3166-1 alpha-2: 'ES', 'BE', 'FR'
    City            NVARCHAR(100)       NULL,
    ContactEmail    NVARCHAR(255)       NOT NULL,
    IsLead          BIT                 NOT NULL DEFAULT 0,  -- 1 = Lead partner (ICFO)
    JoinDate        DATE                NOT NULL DEFAULT GETDATE(),
    IsActive        BIT                 NOT NULL DEFAULT 1,
    CreatedAt       DATETIME2           NOT NULL DEFAULT SYSDATETIME(),
    UpdatedAt       DATETIME2           NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_Partners PRIMARY KEY CLUSTERED (PartnerID),
    CONSTRAINT UQ_Partners_Code UNIQUE (PartnerCode),
    CONSTRAINT CHK_Partners_Email CHECK (ContactEmail LIKE '%@%.%')
);
GO

-- ============================================================
-- CORE SCHEMA: Equipment Registry
-- ============================================================
-- USE CASE: The Pilot Line has research-grade photonics equipment
-- worth millions. Each item must be tracked from procurement → 
-- installation → maintenance → decommission.
-- This is what a CMMS (Computerized Maintenance Management System)
-- manages industrially. We're building a simplified version.
-- ============================================================

CREATE TABLE Core.EquipmentCategories (
    CategoryID      INT IDENTITY(1,1)   NOT NULL,
    CategoryName    NVARCHAR(100)       NOT NULL,   -- 'Lithography', 'Deposition', 'Metrology'
    Description     NVARCHAR(500)       NULL,
    CONSTRAINT PK_EquipmentCategories PRIMARY KEY CLUSTERED (CategoryID)
);
GO

CREATE TABLE Core.Equipment (
    EquipmentID         INT IDENTITY(1,1)   NOT NULL,
    AssetTag            NVARCHAR(50)        NOT NULL,   -- e.g., 'ICFO-LIT-001'
    EquipmentName       NVARCHAR(200)       NOT NULL,
    CategoryID          INT                 NOT NULL,
    PartnerID           INT                 NOT NULL,   -- Which partner owns/hosts it
    Manufacturer        NVARCHAR(200)       NULL,
    ModelNumber         NVARCHAR(100)       NULL,
    SerialNumber        NVARCHAR(100)       NULL,
    PurchaseDate        DATE                NULL,
    PurchasePriceEUR    DECIMAL(15,2)       NULL,
    InstallationDate    DATE                NULL,
    WarrantyExpiryDate  DATE                NULL,
    Status              NVARCHAR(50)        NOT NULL DEFAULT 'Active',
    -- Status values: 'Active', 'Under Maintenance', 'Out of Service', 'Decommissioned'
    Location            NVARCHAR(200)       NULL,   -- Lab room/building at partner site
    Notes               NVARCHAR(MAX)       NULL,
    CreatedAt           DATETIME2           NOT NULL DEFAULT SYSDATETIME(),
    UpdatedAt           DATETIME2           NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_Equipment PRIMARY KEY CLUSTERED (EquipmentID),
    CONSTRAINT UQ_Equipment_AssetTag UNIQUE (AssetTag),
    CONSTRAINT FK_Equipment_Category FOREIGN KEY (CategoryID) REFERENCES Core.EquipmentCategories(CategoryID),
    CONSTRAINT FK_Equipment_Partner FOREIGN KEY (PartnerID) REFERENCES Core.Partners(PartnerID),
    CONSTRAINT CHK_Equipment_Status CHECK (Status IN ('Active','Under Maintenance','Out of Service','Decommissioned'))
);
GO

-- ============================================================
-- CORE SCHEMA: Maintenance Work Orders
-- ============================================================
-- USE CASE: Every maintenance event (planned or emergency) 
-- generates a Work Order. This enables:
--   1. Preventive maintenance scheduling (do it before it breaks)
--   2. Corrective maintenance tracking (fix what broke)
--   3. Downtime reporting for Chips JU audits
--   4. Cost tracking per equipment item
-- ============================================================

CREATE TABLE Core.MaintenanceWorkOrders (
    WorkOrderID         INT IDENTITY(1,1)   NOT NULL,
    WorkOrderNumber     NVARCHAR(20)        NOT NULL,   -- e.g., 'WO-2026-00143'
    EquipmentID         INT                 NOT NULL,
    MaintenanceType     NVARCHAR(50)        NOT NULL,
    -- Values: 'Preventive', 'Corrective', 'Inspection', 'Calibration', 'Emergency'
    Priority            NVARCHAR(20)        NOT NULL DEFAULT 'Normal',
    -- Values: 'Low', 'Normal', 'High', 'Critical'
    RequestedByPartnerID INT               NOT NULL,
    AssignedTechnician  NVARCHAR(200)       NULL,
    ScheduledDate       DATE                NULL,
    StartDate           DATETIME2           NULL,
    CompletionDate      DATETIME2           NULL,
    DowntimeHours       DECIMAL(8,2)        NULL,   -- Hours equipment was unavailable
    LaborCostEUR        DECIMAL(12,2)       NULL,
    PartsCostEUR        DECIMAL(12,2)       NULL,
    TotalCostEUR        AS (ISNULL(LaborCostEUR,0) + ISNULL(PartsCostEUR,0)),  -- Computed column
    Status              NVARCHAR(50)        NOT NULL DEFAULT 'Open',
    -- Values: 'Open', 'In Progress', 'Completed', 'Cancelled'
    ResolutionNotes     NVARCHAR(MAX)       NULL,
    CreatedAt           DATETIME2           NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_WorkOrders PRIMARY KEY CLUSTERED (WorkOrderID),
    CONSTRAINT UQ_WorkOrders_Number UNIQUE (WorkOrderNumber),
    CONSTRAINT FK_WO_Equipment FOREIGN KEY (EquipmentID) REFERENCES Core.Equipment(EquipmentID),
    CONSTRAINT FK_WO_Partner FOREIGN KEY (RequestedByPartnerID) REFERENCES Core.Partners(PartnerID),
    CONSTRAINT CHK_WO_Type CHECK (MaintenanceType IN ('Preventive','Corrective','Inspection','Calibration','Emergency')),
    CONSTRAINT CHK_WO_Priority CHECK (Priority IN ('Low','Normal','High','Critical')),
    CONSTRAINT CHK_WO_Status CHECK (Status IN ('Open','In Progress','Completed','Cancelled'))
);
GO

-- ============================================================
-- CORE SCHEMA: Joint Procurement
-- ============================================================
-- USE CASE: Chips JU requires that procurement of equipment 
-- funded by public money follows strict procedures:
--   - Competitive tendering (min. 3 quotes for purchases > €25K)
--   - Approval workflows before purchase order issued
--   - Full financial traceability to Chips JU reporting
-- Joint Procurement = multiple partners buy together to get 
-- better pricing and reduce duplicated effort.
-- ============================================================

CREATE TABLE Core.ProcurementOrders (
    ProcurementID       INT IDENTITY(1,1)   NOT NULL,
    PONumber            NVARCHAR(30)        NOT NULL,   -- e.g., 'JP-2026-0021'
    ProcurementType     NVARCHAR(30)        NOT NULL,
    -- Values: 'Joint' (multi-partner), 'Individual' (single partner)
    LeadPartnerID       INT                 NOT NULL,   -- Who manages the procurement
    ItemDescription     NVARCHAR(500)       NOT NULL,
    EstimatedValueEUR   DECIMAL(15,2)       NOT NULL,
    ActualValueEUR      DECIMAL(15,2)       NULL,
    Currency            CHAR(3)             NOT NULL DEFAULT 'EUR',
    SupplierName        NVARCHAR(200)       NULL,
    TenderRequired      BIT                 NOT NULL DEFAULT 1,  -- >€25K = mandatory tender
    TenderDeadline      DATE                NULL,
    ApprovalStatus      NVARCHAR(50)        NOT NULL DEFAULT 'Pending',
    -- Values: 'Pending', 'Approved', 'Rejected', 'Ordered', 'Delivered', 'Cancelled'
    ApprovedBy          NVARCHAR(200)       NULL,
    ApprovalDate        DATETIME2           NULL,
    OrderDate           DATE                NULL,
    ExpectedDelivery    DATE                NULL,
    ActualDelivery      DATE                NULL,
    ChipsJULineItem     NVARCHAR(100)       NULL,   -- Maps to Chips JU budget line
    Notes               NVARCHAR(MAX)       NULL,
    CreatedAt           DATETIME2           NOT NULL DEFAULT SYSDATETIME(),
    UpdatedAt           DATETIME2           NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_Procurement PRIMARY KEY CLUSTERED (ProcurementID),
    CONSTRAINT UQ_Procurement_PO UNIQUE (PONumber),
    CONSTRAINT FK_Procurement_LeadPartner FOREIGN KEY (LeadPartnerID) REFERENCES Core.Partners(PartnerID),
    CONSTRAINT CHK_Procurement_Type CHECK (ProcurementType IN ('Joint','Individual')),
    CONSTRAINT CHK_Procurement_Status CHECK (ApprovalStatus IN ('Pending','Approved','Rejected','Ordered','Delivered','Cancelled'))
);
GO

-- Linking table: Which partners participate in a joint procurement
CREATE TABLE Core.ProcurementParticipants (
    ParticipantID       INT IDENTITY(1,1)   NOT NULL,
    ProcurementID       INT                 NOT NULL,
    PartnerID           INT                 NOT NULL,
    ShareEUR            DECIMAL(15,2)       NULL,   -- Partner's financial share
    SharePct            DECIMAL(5,2)        NULL,   -- Percentage of total cost

    CONSTRAINT PK_ProcParticipants PRIMARY KEY CLUSTERED (ParticipantID),
    CONSTRAINT FK_ProcPart_Procurement FOREIGN KEY (ProcurementID) REFERENCES Core.ProcurementOrders(ProcurementID),
    CONSTRAINT FK_ProcPart_Partner FOREIGN KEY (PartnerID) REFERENCES Core.Partners(PartnerID),
    CONSTRAINT UQ_ProcPart UNIQUE (ProcurementID, PartnerID)  -- One partner once per order
);
GO

-- ============================================================
-- GATEWAY SCHEMA: External Company Registry (CRM)
-- ============================================================
-- USE CASE: The EU Chips Act mandates Open Access — external 
-- companies (especially SMEs and startups) must be able to 
-- apply for and use the Pilot Line. 
-- This table is the CRM layer: who applied, who was accepted,
-- what they're using, how much it costs.
-- CRM = Customer Relationship Management (here: user management)
-- ============================================================

CREATE TABLE Gateway.Companies (
    CompanyID           INT IDENTITY(1,1)   NOT NULL,
    CompanyName         NVARCHAR(300)       NOT NULL,
    Country             NVARCHAR(100)       NOT NULL,
    CountryCode         CHAR(2)             NOT NULL,
    CompanyType         NVARCHAR(50)        NOT NULL,
    -- Values: 'SME', 'Large Enterprise', 'University', 'Research Institute', 'Startup'
    VATNumber           NVARCHAR(50)        NULL,   -- EU VAT registration number
    PrimaryContactName  NVARCHAR(200)       NOT NULL,
    PrimaryContactEmail NVARCHAR(255)       NOT NULL,
    PrimaryContactPhone NVARCHAR(50)        NULL,
    RegistrationDate    DATE                NOT NULL DEFAULT GETDATE(),
    AccountStatus       NVARCHAR(50)        NOT NULL DEFAULT 'Pending',
    -- Values: 'Pending', 'Verified', 'Active', 'Suspended', 'Closed'
    GDPRConsentDate     DATETIME2           NULL,   -- GDPR: explicit consent timestamp
    GDPRConsentVersion  NVARCHAR(20)        NULL,   -- Which privacy policy version they accepted
    CreatedAt           DATETIME2           NOT NULL DEFAULT SYSDATETIME(),
    UpdatedAt           DATETIME2           NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_Companies PRIMARY KEY CLUSTERED (CompanyID),
    CONSTRAINT UQ_Companies_Email UNIQUE (PrimaryContactEmail),
    CONSTRAINT CHK_Companies_Type CHECK (CompanyType IN ('SME','Large Enterprise','University','Research Institute','Startup')),
    CONSTRAINT CHK_Companies_Status CHECK (AccountStatus IN ('Pending','Verified','Active','Suspended','Closed'))
);
GO

-- ============================================================
-- GATEWAY SCHEMA: Service Catalog
-- ============================================================
-- USE CASE: External users can request different services from 
-- the Pilot Line. Each service has a defined cost model.
-- Service cost modeling = how much to charge for using the 
-- facility (hourly rates, project fees, wafer runs, etc.)
-- ============================================================

CREATE TABLE Gateway.ServiceCatalog (
    ServiceID           INT IDENTITY(1,1)   NOT NULL,
    ServiceCode         NVARCHAR(20)        NOT NULL,   -- 'PROTO-WAFER', 'TRAIN-PIC', 'CONSULT'
    ServiceName         NVARCHAR(200)       NOT NULL,
    ServiceCategory     NVARCHAR(100)       NOT NULL,
    -- Values: 'Prototyping', 'Training', 'Consulting', 'Testing', 'Design Kit Access'
    Description         NVARCHAR(MAX)       NULL,
    BaseRateEUR         DECIMAL(12,2)       NOT NULL,
    RateUnit            NVARCHAR(50)        NOT NULL,   -- 'per hour', 'per wafer run', 'per project', 'flat fee'
    SMEDiscountPct      DECIMAL(5,2)        NOT NULL DEFAULT 0,  -- % discount for SMEs (EU policy)
    MaxCapacityPerMonth INT                 NULL,       -- Limits availability
    LeadTimeWeeks       INT                 NULL,       -- How long to fulfill after approval
    IsActive            BIT                 NOT NULL DEFAULT 1,
    CreatedAt           DATETIME2           NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_ServiceCatalog PRIMARY KEY CLUSTERED (ServiceID),
    CONSTRAINT UQ_ServiceCatalog_Code UNIQUE (ServiceCode)
);
GO

-- ============================================================
-- GATEWAY SCHEMA: Service Requests (Access Applications)
-- ============================================================
-- USE CASE: When an external company wants to use the Pilot Line,
-- they submit a Service Request through the Gateway portal.
-- This triggers a review workflow: technical feasibility check →
-- capacity check → pricing quote → contract → execution.
-- This table tracks the full lifecycle.
-- ============================================================

CREATE TABLE Gateway.ServiceRequests (
    RequestID           INT IDENTITY(1,1)   NOT NULL,
    RequestNumber       NVARCHAR(30)        NOT NULL,   -- e.g., 'SR-2026-00451'
    CompanyID           INT                 NOT NULL,
    ServiceID           INT                 NOT NULL,
    AssignedPartnerID   INT                 NOT NULL,   -- Which Pilot Line partner will deliver
    RequestTitle        NVARCHAR(300)       NOT NULL,
    ProjectDescription  NVARCHAR(MAX)       NULL,
    RequestedStartDate  DATE                NULL,
    RequestedEndDate    DATE                NULL,
    EstimatedDuration   NVARCHAR(100)       NULL,       -- Free text: '3 wafer runs over 6 months'
    QuotedPriceEUR      DECIMAL(15,2)       NULL,
    FinalPriceEUR       DECIMAL(15,2)       NULL,
    SMEDiscountApplied  BIT                 NOT NULL DEFAULT 0,
    ApplicationStatus   NVARCHAR(50)        NOT NULL DEFAULT 'Submitted',
    -- Values: 'Submitted','Under Review','Quote Sent','Accepted','Contract Signed',
    --          'In Progress','Completed','Rejected','Withdrawn'
    TechReviewDate      DATETIME2           NULL,
    TechReviewOutcome   NVARCHAR(50)        NULL,       -- 'Feasible', 'Not Feasible', 'Conditional'
    ContractDate        DATE                NULL,
    ActualStartDate     DATE                NULL,
    ActualEndDate       DATE                NULL,
    SatisfactionScore   TINYINT             NULL,       -- 1-5 rating from external company
    InternalNotes       NVARCHAR(MAX)       NULL,
    CreatedAt           DATETIME2           NOT NULL DEFAULT SYSDATETIME(),
    UpdatedAt           DATETIME2           NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_ServiceRequests PRIMARY KEY CLUSTERED (RequestID),
    CONSTRAINT UQ_SR_Number UNIQUE (RequestNumber),
    CONSTRAINT FK_SR_Company FOREIGN KEY (CompanyID) REFERENCES Gateway.Companies(CompanyID),
    CONSTRAINT FK_SR_Service FOREIGN KEY (ServiceID) REFERENCES Gateway.ServiceCatalog(ServiceID),
    CONSTRAINT FK_SR_Partner FOREIGN KEY (AssignedPartnerID) REFERENCES Core.Partners(PartnerID),
    CONSTRAINT CHK_SR_Status CHECK (ApplicationStatus IN (
        'Submitted','Under Review','Quote Sent','Accepted','Contract Signed',
        'In Progress','Completed','Rejected','Withdrawn'))
);
GO

-- ============================================================
-- COMPLIANCE SCHEMA: Full Audit Trail
-- ============================================================
-- USE CASE: Chips JU and GDPR both require that any change to 
-- critical data is logged with: Who changed it, What changed,
-- When it changed, and what it was before.
-- This is a universal audit table — one table logs changes 
-- from ALL other tables via triggers.
-- ============================================================

CREATE TABLE Compliance.AuditLog (
    AuditID             BIGINT IDENTITY(1,1)    NOT NULL,   -- BIGINT: will be millions of rows
    EventTimestamp      DATETIME2               NOT NULL DEFAULT SYSDATETIME(),
    DatabaseSchema      NVARCHAR(50)            NOT NULL,   -- 'Core', 'Gateway', 'Compliance'
    TableName           NVARCHAR(200)           NOT NULL,
    RecordID            NVARCHAR(100)           NOT NULL,   -- The PK value of the affected row
    ActionType          CHAR(6)                 NOT NULL,   -- 'INSERT', 'UPDATE', 'DELETE'
    ChangedBy           NVARCHAR(200)           NOT NULL DEFAULT SYSTEM_USER,
    ApplicationUser     NVARCHAR(200)           NULL,       -- App-level user (different from DB user)
    OldValues           NVARCHAR(MAX)           NULL,       -- JSON of previous values
    NewValues           NVARCHAR(MAX)           NULL,       -- JSON of new values
    IPAddress           NVARCHAR(50)            NULL,
    SessionID           NVARCHAR(100)           NULL,

    CONSTRAINT PK_AuditLog PRIMARY KEY CLUSTERED (AuditID),
    CONSTRAINT CHK_Audit_Action CHECK (ActionType IN ('INSERT','UPDATE','DELETE'))
);
GO

-- ============================================================
-- COMPLIANCE SCHEMA: GDPR Data Subject Log
-- ============================================================
-- USE CASE: GDPR Article 17 = Right to Erasure ("right to be forgotten")
-- GDPR Article 15 = Right to Access (what data do we hold on you?)
-- We must log every time a data subject (the company contact 
-- person) exercises their rights. This demonstrates compliance 
-- if the EU Data Protection Authority audits us.
-- ============================================================

CREATE TABLE Compliance.GDPRDataSubjectRequests (
    RequestID           INT IDENTITY(1,1)   NOT NULL,
    CompanyID           INT                 NOT NULL,
    RequestType         NVARCHAR(50)        NOT NULL,
    -- Values: 'Access', 'Erasure', 'Rectification', 'Portability', 'Objection'
    RequestDate         DATE                NOT NULL DEFAULT GETDATE(),
    DeadlineDate        AS DATEADD(DAY, 30, RequestDate),  -- GDPR: must respond in 30 days
    Status              NVARCHAR(50)        NOT NULL DEFAULT 'Received',
    HandledBy           NVARCHAR(200)       NULL,
    CompletionDate      DATE                NULL,
    Notes               NVARCHAR(MAX)       NULL,

    CONSTRAINT PK_GDPRRequests PRIMARY KEY CLUSTERED (RequestID),
    CONSTRAINT FK_GDPR_Company FOREIGN KEY (CompanyID) REFERENCES Gateway.Companies(CompanyID),
    CONSTRAINT CHK_GDPR_Type CHECK (RequestType IN ('Access','Erasure','Rectification','Portability','Objection'))
);
GO

-- ============================================================
-- COMPLIANCE SCHEMA: Data Management Plan Milestones
-- ============================================================
-- USE CASE: Chips JU requires a Data Management Plan (DMP).
-- The DMP has milestones — deliverables where we prove our 
-- data is being handled per FAIR principles.
-- This table tracks DMP milestone status for Chips JU reporting.
-- ============================================================

CREATE TABLE Compliance.DMPMilestones (
    MilestoneID         INT IDENTITY(1,1)   NOT NULL,
    MilestoneCode       NVARCHAR(30)        NOT NULL,   -- e.g., 'DMP-M6', 'DMP-M18'
    MilestoneName       NVARCHAR(200)       NOT NULL,
    FAIRPrinciple       CHAR(1)             NOT NULL,   -- 'F', 'A', 'I', or 'R'
    DueDate             DATE                NOT NULL,
    ResponsiblePartnerID INT               NOT NULL,
    Status              NVARCHAR(50)        NOT NULL DEFAULT 'Pending',
    -- Values: 'Pending', 'In Progress', 'Submitted', 'Approved', 'Overdue'
    SubmissionDate      DATE                NULL,
    ChipsJUApprovalDate DATE                NULL,
    Notes               NVARCHAR(MAX)       NULL,

    CONSTRAINT PK_DMPMilestones PRIMARY KEY CLUSTERED (MilestoneID),
    CONSTRAINT UQ_DMP_Code UNIQUE (MilestoneCode),
    CONSTRAINT FK_DMP_Partner FOREIGN KEY (ResponsiblePartnerID) REFERENCES Core.Partners(PartnerID),
    CONSTRAINT CHK_DMP_FAIR CHECK (FAIRPrinciple IN ('F','A','I','R')),
    CONSTRAINT CHK_DMP_Status CHECK (Status IN ('Pending','In Progress','Submitted','Approved','Overdue'))
);
GO

PRINT 'MODULE 1 COMPLETE: All schemas and tables created successfully.';
GO
