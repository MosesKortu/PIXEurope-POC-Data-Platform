-- ============================================================
-- PIXEurope Pilot Line Data Platform
-- MODULE 3: BI VIEWS & STORED PROCEDURES (Stakeholder Reports)
-- ============================================================
-- These are the dashboards the Pilot Line Director, Financial
-- Manager, and Chips JU auditors will use. This is where your
-- data work creates VISIBLE VALUE to stakeholders.
-- ============================================================

USE PIXEurope;
GO

-- ============================================================
-- VIEW 1: Equipment Status Dashboard
-- ============================================================
-- STAKEHOLDER: Pilot Line Director + Installation & Acceptance Manager
-- FREQUENCY: Real-time (live view)
-- VALUE: Instant visibility of entire equipment fleet —
--        what's operational, what's under maintenance, 
--        what's overdue for warranty action.
-- ============================================================

CREATE OR ALTER VIEW BI.vw_EquipmentStatusDashboard AS
SELECT
    e.EquipmentID,
    e.AssetTag,
    e.EquipmentName,
    ec.CategoryName,
    p.PartnerCode,
    p.Country,
    e.Location,
    e.Manufacturer,
    e.ModelNumber,
    e.Status,
    e.PurchasePriceEUR,
    e.InstallationDate,
    e.WarrantyExpiryDate,
    CASE 
        WHEN e.WarrantyExpiryDate < CAST(GETDATE() AS DATE) THEN 'Expired'
        WHEN e.WarrantyExpiryDate < DATEADD(MONTH, 3, CAST(GETDATE() AS DATE)) 
            AND e.WarrantyExpiryDate >= CAST(GETDATE() AS DATE) THEN 'Expiring Soon'
        ELSE 'In Warranty'
    END AS WarrantyStatus,
    DATEDIFF(DAY, e.InstallationDate, CAST(GETDATE() AS DATE)) AS DaysInService,
    -- Subquery: count open work orders per equipment item
    (SELECT COUNT(*) FROM Core.MaintenanceWorkOrders wo 
     WHERE wo.EquipmentID = e.EquipmentID AND wo.Status NOT IN ('Completed','Cancelled')) AS OpenWorkOrders,
    -- Subquery: total maintenance cost to date
    (SELECT ISNULL(SUM(wo.TotalCostEUR),0) FROM Core.MaintenanceWorkOrders wo 
     WHERE wo.EquipmentID = e.EquipmentID AND wo.Status = 'Completed') AS TotalMaintenanceCostEUR
FROM Core.Equipment e
JOIN Core.EquipmentCategories ec ON e.CategoryID = ec.CategoryID
JOIN Core.Partners p ON e.PartnerID = p.PartnerID;
GO

-- ============================================================
-- VIEW 2: Open Access Pipeline Dashboard
-- ============================================================
-- STAKEHOLDER: Pilot Line Director + Open Access Manager + Chips JU
-- FREQUENCY: Weekly management review
-- VALUE: Full funnel view of external company requests —
--        how many in pipeline, at what stage, total revenue
--        generated from EU mandate on open access.
-- ============================================================

CREATE OR ALTER VIEW BI.vw_OpenAccessPipeline AS
SELECT
    sr.RequestID,
    sr.RequestNumber,
    c.CompanyName,
    c.CompanyType,
    c.Country AS CompanyCountry,
    sc.ServiceName,
    sc.ServiceCategory,
    p.PartnerCode AS DeliveringPartner,
    sr.RequestTitle,
    sr.ApplicationStatus,
    sr.QuotedPriceEUR,
    sr.FinalPriceEUR,
    sr.SMEDiscountApplied,
    CASE sr.SMEDiscountApplied 
        WHEN 1 THEN sr.QuotedPriceEUR * 0.70  -- approximate after discount
        ELSE sr.QuotedPriceEUR
    END AS EstimatedRevenueEUR,
    sr.TechReviewOutcome,
    sr.RequestedStartDate,
    sr.RequestedEndDate,
    sr.ActualStartDate,
    sr.ActualEndDate,
    sr.SatisfactionScore,
    DATEDIFF(DAY, sr.CreatedAt, GETDATE()) AS DaysInSystem,
    CASE 
        WHEN sr.ApplicationStatus IN ('Submitted','Under Review') 
             AND DATEDIFF(DAY, sr.CreatedAt, GETDATE()) > 21 THEN 'Overdue — Action Required'
        WHEN sr.ApplicationStatus = 'Quote Sent' 
             AND DATEDIFF(DAY, sr.UpdatedAt, GETDATE()) > 14 THEN 'Follow-up Needed'
        ELSE 'On Track'
    END AS ActionFlag,
    sr.CreatedAt AS SubmissionDate
FROM Gateway.ServiceRequests sr
JOIN Gateway.Companies c ON sr.CompanyID = c.CompanyID
JOIN Gateway.ServiceCatalog sc ON sr.ServiceID = sc.ServiceID
JOIN Core.Partners p ON sr.AssignedPartnerID = p.PartnerID;
GO

-- ============================================================
-- VIEW 3: Procurement Financial Tracker
-- ============================================================
-- STAKEHOLDER: Financial & Procurement Manager + Chips JU Auditors
-- FREQUENCY: Monthly financial reporting
-- VALUE: Full financial execution view — how much has been 
--        committed, how much delivered, variance vs. budget.
--        This feeds directly into Chips JU financial reports.
-- ============================================================

CREATE OR ALTER VIEW BI.vw_ProcurementFinancials AS
SELECT
    po.PONumber,
    po.ProcurementType,
    p.PartnerName AS LeadPartner,
    po.ItemDescription,
    po.EstimatedValueEUR,
    po.ActualValueEUR,
    ISNULL(po.ActualValueEUR, po.EstimatedValueEUR) AS CommittedValueEUR,
    CASE 
        WHEN po.ActualValueEUR IS NOT NULL 
        THEN po.ActualValueEUR - po.EstimatedValueEUR 
        ELSE NULL 
    END AS VarianceEUR,
    CASE
        WHEN po.ActualValueEUR IS NOT NULL AND po.EstimatedValueEUR > 0
        THEN ROUND(((po.ActualValueEUR - po.EstimatedValueEUR) / po.EstimatedValueEUR) * 100, 2)
        ELSE NULL
    END AS VariancePct,
    po.SupplierName,
    po.TenderRequired,
    po.ApprovalStatus,
    po.ApprovedBy,
    po.ApprovalDate,
    po.OrderDate,
    po.ExpectedDelivery,
    po.ActualDelivery,
    CASE
        WHEN po.ApprovalStatus = 'Delivered' THEN 'Closed'
        WHEN po.ApprovalStatus IN ('Ordered') AND po.ExpectedDelivery < CAST(GETDATE() AS DATE) THEN 'Overdue Delivery'
        WHEN po.ApprovalStatus = 'Pending' AND DATEDIFF(DAY, po.CreatedAt, GETDATE()) > 30 THEN 'Approval Stalled'
        ELSE 'On Track'
    END AS DeliveryFlag,
    po.ChipsJULineItem,
    -- Sum of partner shares (for Joint Procurement)
    (SELECT ISNULL(SUM(pp.ShareEUR),0) 
     FROM Core.ProcurementParticipants pp 
     WHERE pp.ProcurementID = po.ProcurementID) AS TotalPartnerSharesEUR
FROM Core.ProcurementOrders po
JOIN Core.Partners p ON po.LeadPartnerID = p.PartnerID;
GO

-- ============================================================
-- VIEW 4: GDPR & Compliance Dashboard
-- ============================================================
-- STAKEHOLDER: ICFO Data Protection Officer + Compliance team
-- FREQUENCY: Weekly (GDPR deadlines are 30 days — must monitor)
-- VALUE: Ensures ICFO never misses a GDPR response deadline
--        (fines up to 4% of global turnover for non-compliance)
-- ============================================================

CREATE OR ALTER VIEW BI.vw_ComplianceDashboard AS
-- Section A: GDPR Requests with countdown
SELECT
    'GDPR' AS ComplianceArea,
    gr.RequestID AS ID,
    c.CompanyName AS Subject,
    gr.RequestType AS RequestDetail,
    gr.RequestDate AS StartDate,
    gr.DeadlineDate AS Deadline,
    gr.Status,
    DATEDIFF(DAY, CAST(GETDATE() AS DATE), gr.DeadlineDate) AS DaysUntilDeadline,
    CASE
        WHEN gr.Status = 'Completed' THEN 'Closed'
        WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), gr.DeadlineDate) < 0 THEN 'OVERDUE - BREACH RISK'
        WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), gr.DeadlineDate) <= 7 THEN 'URGENT - Act Now'
        ELSE 'On Track'
    END AS RiskFlag
FROM Compliance.GDPRDataSubjectRequests gr
JOIN Gateway.Companies c ON gr.CompanyID = c.CompanyID
WHERE gr.Status != 'Completed'

UNION ALL

-- Section B: DMP Milestones
SELECT
    'DMP-' + dm.FAIRPrinciple AS ComplianceArea,
    dm.MilestoneID AS ID,
    dm.MilestoneCode AS Subject,
    dm.MilestoneName AS RequestDetail,
    CAST(DATEADD(MONTH, -3, dm.DueDate) AS DATE) AS StartDate,  -- 3 months warning
    dm.DueDate AS Deadline,
    dm.Status,
    DATEDIFF(DAY, CAST(GETDATE() AS DATE), dm.DueDate) AS DaysUntilDeadline,
    CASE
        WHEN dm.Status = 'Approved' THEN 'Closed'
        WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), dm.DueDate) < 0 THEN 'OVERDUE - Chips JU Risk'
        WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), dm.DueDate) <= 60 THEN 'Action Required'
        ELSE 'On Track'
    END AS RiskFlag
FROM Compliance.DMPMilestones dm
WHERE dm.Status NOT IN ('Approved');
GO

-- ============================================================
-- VIEW 5: Executive KPI Summary
-- ============================================================
-- STAKEHOLDER: Pilot Line Director + Consortium Board
-- FREQUENCY: Monthly board pack
-- VALUE: Single-number health metrics the Director can 
--        present in steering committee meetings
-- ============================================================

CREATE OR ALTER VIEW BI.vw_ExecutiveKPIs AS
SELECT
    -- Equipment Fleet KPIs
    (SELECT COUNT(*) FROM Core.Equipment) AS TotalEquipmentItems,
    (SELECT COUNT(*) FROM Core.Equipment WHERE Status = 'Active') AS ActiveEquipment,
    (SELECT COUNT(*) FROM Core.Equipment WHERE Status = 'Under Maintenance') AS UnderMaintenance,
    (SELECT ROUND(CAST(COUNT(*) AS FLOAT) / NULLIF((SELECT COUNT(*) FROM Core.Equipment),0) * 100,1)
     FROM Core.Equipment WHERE Status = 'Active') AS FleetAvailabilityPct,

    -- Partner Network KPIs
    (SELECT COUNT(*) FROM Core.Partners WHERE IsActive = 1) AS ActivePartners,
    (SELECT COUNT(DISTINCT CountryCode) FROM Core.Partners WHERE IsActive = 1) AS CountriesRepresented,

    -- Open Access (Gateway) KPIs
    (SELECT COUNT(*) FROM Gateway.Companies WHERE AccountStatus = 'Active') AS ActiveExternalUsers,
    (SELECT COUNT(*) FROM Gateway.ServiceRequests) AS TotalServiceRequests,
    (SELECT COUNT(*) FROM Gateway.ServiceRequests WHERE ApplicationStatus = 'Completed') AS CompletedRequests,
    (SELECT ISNULL(SUM(ISNULL(FinalPriceEUR, QuotedPriceEUR)),0) 
     FROM Gateway.ServiceRequests 
     WHERE ApplicationStatus IN ('Completed','In Progress','Contract Signed')) AS TotalRevenueGenerated,

    -- Procurement KPIs
    (SELECT ISNULL(SUM(EstimatedValueEUR),0) FROM Core.ProcurementOrders) AS TotalProcurementBudgetEUR,
    (SELECT ISNULL(SUM(ActualValueEUR),0) FROM Core.ProcurementOrders WHERE ApprovalStatus = 'Delivered') AS TotalSpentEUR,

    -- Compliance KPIs
    (SELECT COUNT(*) FROM Compliance.DMPMilestones WHERE Status = 'Approved') AS DMPMilestonesApproved,
    (SELECT COUNT(*) FROM Compliance.DMPMilestones) AS DMPMilestonesTotal,
    (SELECT COUNT(*) FROM Compliance.GDPRDataSubjectRequests 
     WHERE Status != 'Completed' AND DeadlineDate < CAST(GETDATE() AS DATE)) AS OverdueGDPRRequests;
GO

-- ============================================================
-- STORED PROCEDURE 1: Register New External Company
-- ============================================================
-- USE CASE: When an external SME submits a Gateway application,
-- this procedure validates and registers them in one atomic 
-- operation. "Atomic" = either everything succeeds or nothing 
-- changes. No half-created records.
-- ============================================================

CREATE OR ALTER PROCEDURE Gateway.usp_RegisterExternalCompany
    @CompanyName        NVARCHAR(300),
    @Country            NVARCHAR(100),
    @CountryCode        CHAR(2),
    @CompanyType        NVARCHAR(50),
    @VATNumber          NVARCHAR(50) = NULL,
    @ContactName        NVARCHAR(200),
    @ContactEmail       NVARCHAR(255),
    @ContactPhone       NVARCHAR(50) = NULL,
    @GDPRVersion        NVARCHAR(20),
    @NewCompanyID       INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Validate: Company type must be in allowed list
        IF @CompanyType NOT IN ('SME','Large Enterprise','University','Research Institute','Startup')
        BEGIN
            RAISERROR('Invalid company type. Must be: SME, Large Enterprise, University, Research Institute, Startup', 16, 1);
            RETURN;
        END

        -- Validate: Email must not already exist
        IF EXISTS (SELECT 1 FROM Gateway.Companies WHERE PrimaryContactEmail = @ContactEmail)
        BEGIN
            RAISERROR('A company with this email address already exists.', 16, 1);
            RETURN;
        END

        -- Insert the company record
        INSERT INTO Gateway.Companies (
            CompanyName, Country, CountryCode, CompanyType, VATNumber,
            PrimaryContactName, PrimaryContactEmail, PrimaryContactPhone,
            GDPRConsentDate, GDPRConsentVersion, AccountStatus
        )
        VALUES (
            @CompanyName, @Country, @CountryCode, @CompanyType, @VATNumber,
            @ContactName, @ContactEmail, @ContactPhone,
            SYSDATETIME(), @GDPRVersion, 'Pending'
        );

        SET @NewCompanyID = SCOPE_IDENTITY();

        -- Log GDPR consent in audit
        INSERT INTO Compliance.AuditLog (DatabaseSchema, TableName, RecordID, ActionType, ChangedBy, NewValues)
        VALUES ('Gateway', 'Companies', CAST(@NewCompanyID AS NVARCHAR), 'INSERT', SYSTEM_USER,
                JSON_OBJECT('company': @CompanyName, 'gdprVersion': @GDPRVersion, 'email': @ContactEmail));

        COMMIT TRANSACTION;
        PRINT 'Company registered successfully. CompanyID: ' + CAST(@NewCompanyID AS NVARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
END;
GO

-- ============================================================
-- STORED PROCEDURE 2: Submit Service Request
-- ============================================================
-- USE CASE: After a company is registered, they can request 
-- services. This procedure auto-generates the request number,
-- validates capacity, and applies SME discounts automatically.
-- ============================================================

CREATE OR ALTER PROCEDURE Gateway.usp_SubmitServiceRequest
    @CompanyID          INT,
    @ServiceID          INT,
    @AssignedPartnerID  INT,
    @RequestTitle       NVARCHAR(300),
    @ProjectDesc        NVARCHAR(MAX) = NULL,
    @RequestedStart     DATE = NULL,
    @RequestedEnd       DATE = NULL,
    @NewRequestID       INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRANSACTION;

    BEGIN TRY
        -- Validate: Company must be Active or Verified
        IF NOT EXISTS (SELECT 1 FROM Gateway.Companies WHERE CompanyID = @CompanyID AND AccountStatus IN ('Active','Verified'))
        BEGIN
            RAISERROR('Company is not active. Status must be Active or Verified before submitting requests.', 16, 1);
            RETURN;
        END

        -- Validate: Service must exist and be active
        IF NOT EXISTS (SELECT 1 FROM Gateway.ServiceCatalog WHERE ServiceID = @ServiceID AND IsActive = 1)
        BEGIN
            RAISERROR('Service not found or is not currently available.', 16, 1);
            RETURN;
        END

        -- Get company type for discount calculation
        DECLARE @CompanyType NVARCHAR(50);
        DECLARE @BaseRate DECIMAL(12,2);
        DECLARE @SMEDiscount DECIMAL(5,2);
        DECLARE @IsSME BIT = 0;
        DECLARE @QuotedPrice DECIMAL(15,2);

        SELECT @CompanyType = CompanyType FROM Gateway.Companies WHERE CompanyID = @CompanyID;
        SELECT @BaseRate = BaseRateEUR, @SMEDiscount = SMEDiscountPct 
        FROM Gateway.ServiceCatalog WHERE ServiceID = @ServiceID;

        IF @CompanyType IN ('SME','Startup')
        BEGIN
            SET @IsSME = 1;
            SET @QuotedPrice = @BaseRate * (1 - @SMEDiscount / 100);
        END
        ELSE
            SET @QuotedPrice = @BaseRate;

        -- Generate request number: SR-YYYY-NNNNN
        DECLARE @Year NVARCHAR(4) = CAST(YEAR(GETDATE()) AS NVARCHAR(4));
        DECLARE @SeqNum INT = (SELECT ISNULL(MAX(RequestID), 0) + 1 FROM Gateway.ServiceRequests);
        DECLARE @RequestNumber NVARCHAR(30) = 'SR-' + @Year + '-' + RIGHT('00000' + CAST(@SeqNum AS NVARCHAR), 5);

        INSERT INTO Gateway.ServiceRequests (
            RequestNumber, CompanyID, ServiceID, AssignedPartnerID,
            RequestTitle, ProjectDescription, RequestedStartDate, RequestedEndDate,
            QuotedPriceEUR, SMEDiscountApplied, ApplicationStatus
        )
        VALUES (
            @RequestNumber, @CompanyID, @ServiceID, @AssignedPartnerID,
            @RequestTitle, @ProjectDesc, @RequestedStart, @RequestedEnd,
            @QuotedPrice, @IsSME, 'Submitted'
        );

        SET @NewRequestID = SCOPE_IDENTITY();

        COMMIT TRANSACTION;
        PRINT 'Service request submitted: ' + @RequestNumber + ' | Quoted: EUR ' + CAST(@QuotedPrice AS NVARCHAR);

    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
END;
GO

-- ============================================================
-- STORED PROCEDURE 3: Monthly Chips JU Financial Report
-- ============================================================
-- USE CASE: Every month, PIXEurope must submit a financial 
-- execution report to Chips JU showing how EU funds were spent.
-- This procedure generates that report in a structured format.
-- ============================================================

CREATE OR ALTER PROCEDURE Compliance.usp_GenerateChipsJUFinancialReport
    @ReportYear     INT,
    @ReportMonth    INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PeriodStart DATE = DATEFROMPARTS(@ReportYear, @ReportMonth, 1);
    DECLARE @PeriodEnd DATE = EOMONTH(@PeriodStart);

    SELECT
        'CHIPS JU FINANCIAL EXECUTION REPORT' AS ReportTitle,
        FORMAT(@PeriodStart, 'MMMM yyyy') AS ReportingPeriod,
        GETDATE() AS GeneratedAt,
        SYSTEM_USER AS GeneratedBy;

    -- Section 1: Procurement commitments this period
    SELECT
        'PROCUREMENT COMMITMENTS' AS Section,
        po.ChipsJULineItem,
        po.PONumber,
        po.ItemDescription,
        p.PartnerName AS LeadPartner,
        po.ProcurementType,
        po.EstimatedValueEUR,
        po.ActualValueEUR,
        po.ApprovalStatus,
        po.OrderDate
    FROM Core.ProcurementOrders po
    JOIN Core.Partners p ON po.LeadPartnerID = p.PartnerID
    WHERE po.OrderDate BETWEEN @PeriodStart AND @PeriodEnd
       OR po.ActualDelivery BETWEEN @PeriodStart AND @PeriodEnd
    ORDER BY po.ChipsJULineItem;

    -- Section 2: Open Access revenue this period
    SELECT
        'OPEN ACCESS REVENUE' AS Section,
        sc.ServiceCategory,
        COUNT(*) AS RequestsThisPeriod,
        SUM(ISNULL(sr.FinalPriceEUR, sr.QuotedPriceEUR)) AS TotalRevenueEUR,
        SUM(CASE WHEN sr.SMEDiscountApplied = 1 THEN 1 ELSE 0 END) AS SMERequests
    FROM Gateway.ServiceRequests sr
    JOIN Gateway.ServiceCatalog sc ON sr.ServiceID = sc.ServiceID
    WHERE sr.CreatedAt BETWEEN @PeriodStart AND @PeriodEnd
    GROUP BY sc.ServiceCategory;

    -- Section 3: Compliance status
    SELECT
        'DMP MILESTONES STATUS' AS Section,
        FAIRPrinciple,
        COUNT(*) AS TotalMilestones,
        SUM(CASE WHEN Status = 'Approved' THEN 1 ELSE 0 END) AS Approved,
        SUM(CASE WHEN Status = 'Pending' OR Status = 'In Progress' THEN 1 ELSE 0 END) AS InProgress,
        SUM(CASE WHEN Status = 'Overdue' THEN 1 ELSE 0 END) AS Overdue
    FROM Compliance.DMPMilestones
    GROUP BY FAIRPrinciple;
END;
GO

PRINT 'MODULE 3 COMPLETE: BI views and stored procedures created.';
GO
