-- ============================================================
-- PIXEurope Pilot Line Data Platform
-- MODULE 4: PRACTICE EXERCISES & INTERVIEW USE CASES
-- ============================================================
-- Run these queries after Modules 1-3 to test your platform.
-- Each exercise maps to a real interview question or scenario.
-- Study the comments — they are your interview talking points.
-- ============================================================

USE PIXEurope;
GO

-- ============================================================
-- EXERCISE 1: "Show me the equipment fleet status across all partners"
-- INTERVIEW QUESTION: "How would you give the Pilot Line Director
-- a real-time view of equipment availability across 20 sites?"
-- ============================================================

SELECT 
    PartnerCode,
    Country,
    COUNT(*) AS TotalEquipment,
    SUM(CASE WHEN Status = 'Active' THEN 1 ELSE 0 END) AS Active,
    SUM(CASE WHEN Status = 'Under Maintenance' THEN 1 ELSE 0 END) AS UnderMaintenance,
    SUM(CASE WHEN Status = 'Out of Service' THEN 1 ELSE 0 END) AS OutOfService,
    ROUND(
        CAST(SUM(CASE WHEN Status = 'Active' THEN 1 ELSE 0 END) AS FLOAT) /
        CAST(COUNT(*) AS FLOAT) * 100, 1
    ) AS AvailabilityPct,
    SUM(ISNULL(PurchasePriceEUR, 0)) AS TotalAssetValueEUR
FROM BI.vw_EquipmentStatusDashboard
GROUP BY PartnerCode, Country
ORDER BY TotalAssetValueEUR DESC;

-- ← TALKING POINT: "I designed a view that aggregates equipment status
--   across all partners in real time. The Director can filter by country,
--   see availability rates, and total asset value without touching raw tables."

GO

-- ============================================================
-- EXERCISE 2: "Which equipment is warranty-expiring in 90 days?"
-- INTERVIEW QUESTION: "How does your platform support preventive
-- maintenance and avoid unexpected equipment failures?"
-- ============================================================

SELECT
    AssetTag,
    EquipmentName,
    CategoryName,
    PartnerCode,
    WarrantyExpiryDate,
    DATEDIFF(DAY, CAST(GETDATE() AS DATE), WarrantyExpiryDate) AS DaysUntilExpiry,
    OpenWorkOrders,
    TotalMaintenanceCostEUR
FROM BI.vw_EquipmentStatusDashboard
WHERE WarrantyStatus IN ('Expiring Soon', 'Expired')
ORDER BY WarrantyExpiryDate ASC;

-- ← TALKING POINT: "Preventive maintenance is a core function of the CMMS.
--   This query flags items with expiring warranties so the team can 
--   schedule maintenance BEFORE breakdown — reducing unplanned downtime
--   which would directly impact Pilot Line availability and Open Access delivery."

GO

-- ============================================================
-- EXERCISE 3: "Show me the Open Access funnel — what's the conversion rate?"
-- INTERVIEW QUESTION: "How do you track whether the Pilot Line is 
-- meeting its Open Access mandate from Chips JU?"
-- ============================================================

SELECT
    ApplicationStatus,
    COUNT(*) AS RequestCount,
    SUM(ISNULL(QuotedPriceEUR, 0)) AS TotalQuotedEUR,
    ROUND(CAST(COUNT(*) AS FLOAT) / (SELECT COUNT(*) FROM Gateway.ServiceRequests) * 100, 1) AS PctOfTotal,
    AVG(DaysInSystem) AS AvgDaysInSystem
FROM BI.vw_OpenAccessPipeline
GROUP BY ApplicationStatus
ORDER BY 
    CASE ApplicationStatus
        WHEN 'Submitted' THEN 1
        WHEN 'Under Review' THEN 2
        WHEN 'Quote Sent' THEN 3
        WHEN 'Accepted' THEN 4
        WHEN 'Contract Signed' THEN 5
        WHEN 'In Progress' THEN 6
        WHEN 'Completed' THEN 7
        WHEN 'Rejected' THEN 8
        WHEN 'Withdrawn' THEN 9
    END;

-- ← TALKING POINT: "The EU Chips Act mandates open access to the Pilot Line.
--   I designed a full funnel view so we can measure: submission-to-completion
--   time, rejection rate (which Chips JU will scrutinise), and revenue generated
--   per service category. This feeds directly into our quarterly Chips JU report."

GO

-- ============================================================
-- EXERCISE 4: "Which partner is handling the most external work?"
-- INTERVIEW QUESTION: "How do you ensure workload is balanced 
-- across Pilot Line partners and no site is bottlenecked?"
-- ============================================================

SELECT
    DeliveringPartner,
    COUNT(*) AS TotalAssignedRequests,
    SUM(CASE WHEN ApplicationStatus IN ('In Progress','Contract Signed') THEN 1 ELSE 0 END) AS ActiveNow,
    SUM(CASE WHEN ApplicationStatus = 'Completed' THEN 1 ELSE 0 END) AS Completed,
    SUM(ISNULL(EstimatedRevenueEUR, 0)) AS TotalRevenueEUR,
    AVG(ISNULL(SatisfactionScore, 0)) AS AvgSatisfaction
FROM BI.vw_OpenAccessPipeline
GROUP BY DeliveringPartner
ORDER BY ActiveNow DESC;

GO

-- ============================================================
-- EXERCISE 5: "Show the procurement execution vs. budget — are we on track?"
-- INTERVIEW QUESTION: "How do you give Chips JU confidence that 
-- public funds are being spent correctly and on schedule?"
-- ============================================================

SELECT
    ChipsJULineItem,
    COUNT(*) AS OrderCount,
    SUM(EstimatedValueEUR) AS TotalBudgetEUR,
    SUM(ISNULL(ActualValueEUR, 0)) AS TotalActualEUR,
    SUM(EstimatedValueEUR) - SUM(ISNULL(ActualValueEUR, 0)) AS RemainingBudgetEUR,
    ROUND(
        SUM(ISNULL(ActualValueEUR, 0)) / NULLIF(SUM(EstimatedValueEUR), 0) * 100, 1
    ) AS ExecutionPct,
    SUM(CASE WHEN DeliveryFlag LIKE '%Overdue%' THEN 1 ELSE 0 END) AS OverdueOrders
FROM BI.vw_ProcurementFinancials
WHERE ChipsJULineItem IS NOT NULL
GROUP BY ChipsJULineItem
ORDER BY TotalBudgetEUR DESC;

-- ← TALKING POINT: "Every euro in PIXEurope is traced to a Chips JU budget line.
--   My procurement view calculates execution rate — how much of the approved budget 
--   has been committed and delivered. An execution rate below 70% at year-end triggers
--   a Chips JU review. I built this so the Financial Manager has a live warning system."

GO

-- ============================================================
-- EXERCISE 6: Traceability — "Who changed this equipment record and when?"
-- INTERVIEW QUESTION: "Can you demonstrate full audit traceability
-- as required by EU compliance frameworks?"
-- ============================================================

-- Simulate an equipment status change (will be auto-logged by trigger)
UPDATE Core.Equipment
SET Status = 'Under Maintenance', UpdatedAt = SYSDATETIME()
WHERE AssetTag = 'ICFO-MET-001';

-- Now query the audit trail
SELECT
    AuditID,
    EventTimestamp,
    TableName,
    RecordID,
    ActionType,
    ChangedBy,
    OldValues,
    NewValues
FROM Compliance.AuditLog
WHERE TableName = 'Equipment'
ORDER BY EventTimestamp DESC;

-- ← TALKING POINT: "I implemented a T-SQL trigger on the Equipment table that 
--   captures every INSERT, UPDATE, and DELETE in a JSON-formatted audit log.
--   If a Chips JU auditor asks 'who changed equipment ICFO-MET-001 and when' —
--   I can answer that in one query. This is the traceability requirement in the JD."

GO

-- ============================================================
-- EXERCISE 7: GDPR Compliance — "Are we at risk of missing any deadlines?"
-- INTERVIEW QUESTION: "How does your system handle GDPR compliance 
-- for external Gateway users?"
-- ============================================================

SELECT * FROM BI.vw_ComplianceDashboard
ORDER BY DaysUntilDeadline ASC;

-- Simulate registering a new company using the stored procedure
DECLARE @NewID INT;
EXEC Gateway.usp_RegisterExternalCompany
    @CompanyName        = 'QuantumLight Startups SL',
    @Country            = 'Spain',
    @CountryCode        = 'ES',
    @CompanyType        = 'Startup',
    @VATNumber          = 'ESB99887766',
    @ContactName        = 'Sofia Martínez',
    @ContactEmail       = 's.martinez@quantumlight.es',
    @GDPRVersion        = 'v2.1',
    @NewCompanyID       = @NewID OUTPUT;

SELECT @NewID AS NewCompanyID;

-- ← TALKING POINT: "GDPR gives individuals 30 days to get a response to data requests.
--   My compliance view tracks every open request with a countdown. Red = breach risk.
--   The registration procedure also auto-timestamps GDPR consent with the policy version —
--   so we can prove exactly what the user agreed to, and when."

GO

-- ============================================================
-- EXERCISE 8: Executive KPI Dashboard — The Board Report
-- INTERVIEW QUESTION: "If the Pilot Line Director walks into a 
-- board meeting, what single-screen summary would you give them?"
-- ============================================================

SELECT
    '=== EQUIPMENT ===' AS Category, '' AS Metric, '' AS Value
UNION ALL
SELECT '', 'Total Equipment Items',    CAST(TotalEquipmentItems AS NVARCHAR)    FROM BI.vw_ExecutiveKPIs
UNION ALL
SELECT '', 'Fleet Availability %',     CAST(FleetAvailabilityPct AS NVARCHAR) + '%' FROM BI.vw_ExecutiveKPIs
UNION ALL
SELECT '', 'Under Maintenance',        CAST(UnderMaintenance AS NVARCHAR)       FROM BI.vw_ExecutiveKPIs
UNION ALL
SELECT '=== NETWORK ===', '', ''
UNION ALL
SELECT '', 'Active Partners',          CAST(ActivePartners AS NVARCHAR)         FROM BI.vw_ExecutiveKPIs
UNION ALL
SELECT '', 'Countries Represented',    CAST(CountriesRepresented AS NVARCHAR)   FROM BI.vw_ExecutiveKPIs
UNION ALL
SELECT '=== OPEN ACCESS ===', '', ''
UNION ALL
SELECT '', 'Active External Users',    CAST(ActiveExternalUsers AS NVARCHAR)    FROM BI.vw_ExecutiveKPIs
UNION ALL
SELECT '', 'Total Service Requests',   CAST(TotalServiceRequests AS NVARCHAR)   FROM BI.vw_ExecutiveKPIs
UNION ALL
SELECT '', 'Revenue Generated (EUR)',  FORMAT(TotalRevenueGenerated,'N2')       FROM BI.vw_ExecutiveKPIs
UNION ALL
SELECT '=== COMPLIANCE ===', '', ''
UNION ALL
SELECT '', 'DMP Milestones Approved',  CAST(DMPMilestonesApproved AS NVARCHAR) + ' / ' + CAST(DMPMilestonesTotal AS NVARCHAR) FROM BI.vw_ExecutiveKPIs
UNION ALL
SELECT '', 'Overdue GDPR Requests',   CAST(OverdueGDPRRequests AS NVARCHAR)    FROM BI.vw_ExecutiveKPIs;

GO

-- ============================================================
-- EXERCISE 9: Generate Chips JU Monthly Financial Report
-- ============================================================

EXEC Compliance.usp_GenerateChipsJUFinancialReport 
    @ReportYear = 2026, 
    @ReportMonth = 3;  -- March 2026
GO

-- ============================================================
-- INTERVIEW CHEAT SHEET: Answer These Questions Cold
-- ============================================================
/*
Q: "What is a FOREIGN KEY and why does it matter here?"
A: "A foreign key ensures referential integrity. In PIXEurope, every 
   maintenance work order must reference a valid equipment item.
   Without a foreign key constraint, someone could log maintenance
   on equipment that doesn't exist — corrupting our Chips JU reports."

Q: "Why did you use schemas (Core, Gateway, Compliance, BI)?"
A: "Schemas serve two purposes: organization and access control.
   In SQL Server, I can grant the Open Access Manager read/write 
   to Gateway schema only, while the Financial Manager gets Core
   and Compliance read-only. This is a security best practice
   and satisfies the data governance requirements in the JD."

Q: "What is a stored procedure vs. a view?"
A: "A view is a saved SELECT query — read-only, always live data.
   A stored procedure is executable code with parameters, validation
   logic, error handling, and transaction control. I use views for
   dashboards and reporting, stored procedures for data entry 
   workflows where I need to enforce business rules."

Q: "How does your audit trigger work?"
A: "The trigger fires automatically after any INSERT, UPDATE, or DELETE
   on the Equipment table. It captures the before and after state as JSON
   and writes it to the audit log with the database user and timestamp.
   This is fully automatic — no developer can forget to log a change."

Q: "What are FAIR data principles and how did you implement them?"
A: "FAIR stands for Findable, Accessible, Interoperable, Reusable.
   In the database: Findable = equipment and datasets have unique asset
   tags and metadata. Accessible = the Gateway view makes data available
   to external users through a structured interface. Interoperable = 
   common schema across all 20 partners. Reusable = audit trail and 
   DMP milestones table tracks compliance with data licensing."

Q: "How would you handle a GDPR erasure request?"
A: "First I'd log it in the GDPRDataSubjectRequests table immediately
   to start the 30-day clock. Then I'd identify all personal data 
   linked to that CompanyID — contact details, service request history.
   For active contracts, GDPR allows retention for legitimate interest.
   For inactive records, I'd pseudonymise or delete personal fields
   and log the action in the audit trail. The compliance dashboard 
   would turn red if we hadn't responded within 30 days."
*/
