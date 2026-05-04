-- ============================================================
-- PIXEurope Pilot Line Data Platform
-- MODULE 2: SAMPLE DATA, TRIGGERS & INDEXES
-- ============================================================

USE PIXEurope;
GO

-- ============================================================
-- SAMPLE DATA: Partners (20 fictional but realistic institutions)
-- ============================================================

INSERT INTO Core.Partners (PartnerCode, PartnerName, Country, CountryCode, City, ContactEmail, IsLead)
VALUES
('ICFO',  'Institut de Ciències Fotòniques',           'Spain',       'ES', 'Castelldefels', 'data@icfo.eu',      1),
('IMEC',  'Interuniversity Microelectronics Centre',   'Belgium',     'BE', 'Leuven',        'data@imec.be',      0),
('CEA',   'Commissariat à l''Énergie Atomique',        'France',      'FR', 'Grenoble',      'data@cea.fr',       0),
('FRAU',  'Fraunhofer Institute for Photonics',        'Germany',     'DE', 'Jena',          'data@fraunhofer.de',0),
('TNOP',  'Technical University of Netherlands Optics','Netherlands', 'NL', 'Eindhoven',     'data@tue.nl',       0),
('VTT',   'VTT Technical Research Centre',             'Finland',     'FI', 'Espoo',         'data@vtt.fi',       0),
('IST',   'Instituto Superior Técnico',                'Portugal',    'PT', 'Lisbon',        'data@ist.pt',       0),
('WAWA',  'Warsaw Photonics Institute',                'Poland',      'PL', 'Warsaw',        'data@wawa.pl',      0),
('AIT',   'Austrian Institute of Technology',          'Austria',     'AT', 'Vienna',        'data@ait.ac.at',    0),
('UK_NPL','National Physical Laboratory',              'UK',          'GB', 'Teddington',    'data@npl.co.uk',    0);
GO

-- ============================================================
-- SAMPLE DATA: Equipment Categories
-- ============================================================

INSERT INTO Core.EquipmentCategories (CategoryName, Description)
VALUES
('Lithography',   'Equipment for patterning photonic structures at micro/nano scale'),
('Deposition',    'Chemical and physical deposition systems for thin film growth'),
('Etching',       'Dry and wet etching systems for material removal'),
('Metrology',     'Measurement and characterisation equipment'),
('Packaging',     'Assembly and packaging equipment for PICs'),
('Testing',       'Optical and electrical testing systems');
GO

-- ============================================================
-- SAMPLE DATA: Equipment (representative items)
-- ============================================================

INSERT INTO Core.Equipment (AssetTag, EquipmentName, CategoryID, PartnerID, Manufacturer, ModelNumber, SerialNumber, PurchaseDate, PurchasePriceEUR, InstallationDate, WarrantyExpiryDate, Status, Location)
VALUES
('ICFO-LIT-001', 'Deep UV Lithography System',        1, 1, 'ASML',    'PAS5500/300', 'SN2024001', '2024-06-01', 4500000.00, '2024-09-15', '2027-09-15', 'Active',             'Cleanroom A, Bay 3'),
('ICFO-DEP-001', 'PECVD Silicon Nitride Deposition',  2, 1, 'Oxford',  'Plasmalab80', 'SN2024002', '2024-07-01',  380000.00, '2024-10-01', '2026-10-01', 'Active',             'Cleanroom A, Bay 5'),
('IMEC-ETH-001', 'Inductively Coupled Plasma Etcher', 3, 2, 'Lam Res', 'Kiyo 45',    'SN2024003', '2024-08-15',  920000.00, '2024-11-01', '2027-11-01', 'Active',             'Cleanroom B, Bay 2'),
('ICFO-MET-001', 'Scanning Electron Microscope',      4, 1, 'Zeiss',   'Ultra 55',   'SN2024004', '2024-05-01',  750000.00, '2024-08-01', '2026-08-01', 'Under Maintenance',  'Metrology Lab'),
('CEA-DEP-001',  'Molecular Beam Epitaxy System',     2, 3, 'Riber',   'MBE49',      'SN2024005', '2024-09-01', 2100000.00, '2025-01-15', '2028-01-15', 'Active',             'MBE Lab, Grenoble'),
('FRAU-TST-001', 'Optical Vector Analyser',           6, 4, 'Keysight','N7788B',     'SN2024006', '2024-10-01',  180000.00, '2024-11-15', '2026-11-15', 'Active',             'Testing Lab 1');
GO

-- ============================================================
-- SAMPLE DATA: Procurement Orders (Joint and Individual)
-- ============================================================

INSERT INTO Core.ProcurementOrders (PONumber, ProcurementType, LeadPartnerID, ItemDescription, EstimatedValueEUR, ActualValueEUR, SupplierName, TenderRequired, ApprovalStatus, ApprovedBy, ApprovalDate, OrderDate, ExpectedDelivery, ChipsJULineItem)
VALUES
('JP-2026-0001', 'Joint',      1, 'Batch purchase of cleanroom consumables (photoresist, solvents) for Q1 2026', 85000.00, 79500.00, 'Sigma-Aldrich', 1, 'Delivered',  'Valerio Pruneri', '2025-11-15', '2025-12-01', '2026-01-15', 'WP3-CONSUMABLES-Q1'),
('JP-2026-0002', 'Joint',      2, 'High-vacuum pumping systems (3 units) for IMEC, FRAU, VTT',                  320000.00, NULL,     'Pfeiffer Vacuum',1, 'Approved',   'Pilot Line Board', '2026-02-01', '2026-03-01', '2026-09-01', 'WP2-EQUIP-002'),
('IP-2026-0003', 'Individual', 1, 'Replacement laser source for ICFO lithography system',                         45000.00, 43200.00, 'II-VI Incorp.',  1, 'Delivered',  'ICFO Procurement', '2026-01-10', '2026-01-15', '2026-03-01', 'WP2-MAINT-ICFO'),
('JP-2026-0004', 'Joint',      1, 'Shared data platform hosting and infrastructure (cloud + on-prem)',            95000.00, NULL,     NULL,             1, 'Pending',    NULL, NULL, NULL, NULL, 'WP5-DATAPLATFORM');
GO

-- Joint procurement participants
INSERT INTO Core.ProcurementParticipants (ProcurementID, PartnerID, ShareEUR, SharePct)
VALUES
(1, 1, 30000.00, 37.74),  -- ICFO share in JP-2026-0001
(1, 2, 25000.00, 31.45),  -- IMEC share
(1, 3, 24500.00, 30.81),  -- CEA share
(2, 2, 120000.00,37.50),  -- IMEC share in JP-2026-0002
(2, 4, 100000.00,31.25),  -- FRAU share
(2, 6,  60000.00,18.75),  -- VTT share (estimated, tender not finalised)
(2, 5,  40000.00,12.50);  -- TNOP share
GO

-- ============================================================
-- SAMPLE DATA: External Companies (Gateway/CRM)
-- ============================================================

INSERT INTO Gateway.Companies (CompanyName, Country, CountryCode, CompanyType, VATNumber, PrimaryContactName, PrimaryContactEmail, GDPRConsentDate, GDPRConsentVersion, AccountStatus)
VALUES
('LightPath Technologies SL',   'Spain',       'ES', 'SME',            'ESB12345678', 'Ana García',      'a.garcia@lightpath.es',    '2026-01-10', 'v2.1', 'Active'),
('PhotonicWave GmbH',           'Germany',     'DE', 'Startup',        'DE987654321', 'Hans Müller',     'h.muller@photonicwave.de', '2026-02-14', 'v2.1', 'Active'),
('OptaSense Ltd',               'UK',          'GB', 'SME',            'GB123456789', 'Claire Ashton',   'c.ashton@optasense.co.uk', '2026-01-28', 'v2.1', 'Active'),
('Luminary Research SA',        'France',      'FR', 'Research Institute','FR456789012','Pierre Dubois', 'p.dubois@luminary.fr',     '2026-03-01', 'v2.1', 'Verified'),
('Nanophotonics BV',            'Netherlands', 'NL', 'SME',            'NL789012345', 'Jan de Boer',     'j.deboer@nanophotonics.nl','2026-03-15', 'v2.1', 'Pending');
GO

-- ============================================================
-- SAMPLE DATA: Service Catalog
-- ============================================================

INSERT INTO Gateway.ServiceCatalog (ServiceCode, ServiceName, ServiceCategory, Description, BaseRateEUR, RateUnit, SMEDiscountPct, MaxCapacityPerMonth, LeadTimeWeeks)
VALUES
('PROTO-WAFER',  'Wafer Prototyping Run',              'Prototyping', 'Full wafer prototyping run through the Pilot Line process flow', 12000.00, 'per wafer run', 30.00, 8,  6),
('PROTO-MPW',    'Multi-Project Wafer (MPW) Shuttle',  'Prototyping', 'Shared wafer run — multiple customers share one wafer to reduce cost', 3500.00,'per design', 25.00, 20, 4),
('TRAIN-INTRO',  'Introductory PIC Design Course',     'Training',    '3-day course on photonic integrated circuit design fundamentals',  1200.00, 'per person',   20.00, 15, 2),
('TRAIN-ADV',    'Advanced Process Integration Course','Training',    '5-day advanced course on process flows and design kits',           2800.00, 'per person',   20.00, 10, 3),
('ACCESS-PDK',   'Process Design Kit (PDK) Access',    'Design Kit Access','Annual licence to PIXEurope standard PDK library',          4500.00, 'per year',     15.00, NULL,1),
('CONSULT-PROC', 'Process Consulting',                 'Consulting',  'Expert advisory sessions on process compatibility and yield',      250.00,  'per hour',     10.00, NULL,1),
('TEST-OPT',     'Optical Characterisation Service',   'Testing',     'Full optical characterisation of delivered PIC samples',           800.00,  'per sample',    0.00, 30, 2);
GO

-- ============================================================
-- SAMPLE DATA: Service Requests
-- ============================================================

INSERT INTO Gateway.ServiceRequests (RequestNumber, CompanyID, ServiceID, AssignedPartnerID, RequestTitle, ProjectDescription, RequestedStartDate, RequestedEndDate, QuotedPriceEUR, SMEDiscountApplied, ApplicationStatus, TechReviewDate, TechReviewOutcome, ContractDate, ActualStartDate)
VALUES
('SR-2026-00001', 1, 1, 1, 'Silicon Nitride Waveguide Prototype for Sensing Application',     'LightPath needs to prototype a Si3N4 waveguide array for environmental gas sensing. Target wavelength 1550nm.',  '2026-04-01', '2026-06-30',  8400.00, 1, 'In Progress',       '2026-02-20', 'Feasible',  '2026-03-10', '2026-04-05'),
('SR-2026-00002', 2, 5, 1, 'PDK Access for InP Platform Development',                        'PhotonicWave requires 12-month PDK access to begin designing InP-based laser integration structures.',             '2026-03-15', '2027-03-14',  3825.00, 0, 'Contract Signed',   '2026-02-28', 'Feasible',  '2026-03-05', NULL),
('SR-2026-00003', 3, 7, 4, 'Optical Characterisation of Fabricated Samples',                  'OptaSense has 12 PIC samples from external fab requiring characterisation against PIXEurope baseline specs.',    '2026-04-20', '2026-04-25',   800.00, 0, 'Quote Sent',        '2026-03-18', 'Feasible',  NULL, NULL),
('SR-2026-00004', 5, 2, 1, 'MPW Shuttle Access — First Tape-Out',                             'Nanophotonics BV first tape-out on PIXEurope platform. Si waveguide + MZI structures for telecom applications.', '2026-06-01', '2026-09-30',  2625.00, 1, 'Under Review',      NULL, NULL, NULL, NULL),
('SR-2026-00005', 4, 6, 3, 'Process Consulting — III-V Integration Feasibility',              'Luminary Research needs 8 hours consulting on III-V material integration into the PIXEurope Si platform.',       '2026-04-10', '2026-04-10',  2000.00, 0, 'Accepted',          '2026-03-25', 'Feasible',  NULL, NULL);
GO

-- ============================================================
-- SAMPLE DATA: DMP Milestones (FAIR principles tracking)
-- ============================================================

INSERT INTO Compliance.DMPMilestones (MilestoneCode, MilestoneName, FAIRPrinciple, DueDate, ResponsiblePartnerID, Status, SubmissionDate)
VALUES
('DMP-F-M6',  'Findability: Metadata catalogue deployed for all equipment datasets',        'F', '2025-12-31', 1, 'Submitted', '2025-12-20'),
('DMP-A-M6',  'Accessibility: Open Access portal live and accepting applications',          'A', '2026-03-31', 1, 'In Progress', NULL),
('DMP-I-M12', 'Interoperability: Common data schema adopted by all 20 partners',           'I', '2026-06-30', 1, 'Pending', NULL),
('DMP-R-M12', 'Reusability: All equipment datasets published with open licences',          'R', '2026-06-30', 2, 'Pending', NULL),
('DMP-F-M18', 'Findability: PIXEurope datasets indexed in European Open Science Cloud',    'F', '2026-12-31', 1, 'Pending', NULL),
('DMP-A-M18', 'Accessibility: 50+ external companies onboarded through Gateway',           'A', '2026-12-31', 1, 'Pending', NULL);
GO

-- ============================================================
-- AUDIT TRIGGER: Auto-log all changes to Core.Equipment
-- ============================================================
-- USE CASE: If equipment status changes (Active → Under Maintenance),
-- the Chips JU audit team can see exactly who changed it and when.
-- The trigger fires automatically — no developer needs to remember.
-- ============================================================

CREATE OR ALTER TRIGGER Core.trg_Equipment_Audit
ON Core.Equipment
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    -- Handle INSERTs
    IF EXISTS (SELECT 1 FROM inserted) AND NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO Compliance.AuditLog (DatabaseSchema, TableName, RecordID, ActionType, ChangedBy, NewValues)
        SELECT 
            'Core', 
            'Equipment', 
            CAST(i.EquipmentID AS NVARCHAR(100)),
            'INSERT',
            SYSTEM_USER,
            (SELECT i.AssetTag, i.EquipmentName, i.Status, i.PartnerID FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        FROM inserted i;
    END

    -- Handle UPDATEs
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO Compliance.AuditLog (DatabaseSchema, TableName, RecordID, ActionType, ChangedBy, OldValues, NewValues)
        SELECT 
            'Core',
            'Equipment',
            CAST(i.EquipmentID AS NVARCHAR(100)),
            'UPDATE',
            SYSTEM_USER,
            (SELECT d.AssetTag, d.Status, d.UpdatedAt FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
            (SELECT i.AssetTag, i.Status, i.UpdatedAt FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        FROM inserted i
        JOIN deleted d ON i.EquipmentID = d.EquipmentID;
    END

    -- Handle DELETEs
    IF NOT EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted)
    BEGIN
        INSERT INTO Compliance.AuditLog (DatabaseSchema, TableName, RecordID, ActionType, ChangedBy, OldValues)
        SELECT 
            'Core',
            'Equipment',
            CAST(d.EquipmentID AS NVARCHAR(100)),
            'DELETE',
            SYSTEM_USER,
            (SELECT d.AssetTag, d.EquipmentName, d.Status FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
        FROM deleted d;
    END
END;
GO

-- ============================================================
-- INDEXES: Speed up common query patterns
-- ============================================================
-- Without indexes, every query scans the entire table.
-- With indexes, the database jumps straight to the right rows.
-- ============================================================

-- Equipment: Fast lookup by partner (most common filter)
CREATE NONCLUSTERED INDEX IX_Equipment_PartnerID 
ON Core.Equipment(PartnerID) INCLUDE (AssetTag, EquipmentName, Status);

-- Equipment: Fast lookup by status (dashboard queries)
CREATE NONCLUSTERED INDEX IX_Equipment_Status 
ON Core.Equipment(Status) INCLUDE (AssetTag, EquipmentName, PartnerID);

-- Service Requests: Fast lookup by company
CREATE NONCLUSTERED INDEX IX_SR_CompanyID 
ON Gateway.ServiceRequests(CompanyID) INCLUDE (RequestNumber, ApplicationStatus, ServiceID);

-- Service Requests: Fast lookup by status (pipeline management)
CREATE NONCLUSTERED INDEX IX_SR_Status 
ON Gateway.ServiceRequests(ApplicationStatus) INCLUDE (RequestNumber, CompanyID, AssignedPartnerID);

-- Audit log: Fast lookup by table+record (traceability queries)
CREATE NONCLUSTERED INDEX IX_Audit_TableRecord 
ON Compliance.AuditLog(TableName, RecordID) INCLUDE (EventTimestamp, ActionType, ChangedBy);

-- DMP: Fast lookup by status and FAIR principle
CREATE NONCLUSTERED INDEX IX_DMP_Status 
ON Compliance.DMPMilestones(Status, FAIRPrinciple) INCLUDE (MilestoneCode, DueDate);

PRINT 'MODULE 2 COMPLETE: Sample data, triggers, and indexes created.';
GO
