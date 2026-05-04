-- ============================================================
-- VERIFYING SCHEMA DESIGN : Logical organization of database objects.
-- ============================================================

USE PIXEurope;
GO

SELECT 
    name AS SchemaName, 
    schema_id AS InternalID,
    SCHEMA_NAME(principal_id) AS SchemaOwner
FROM sys.schemas
WHERE name IN ('Core', 'Gateway', 'Compliance', 'BI')
ORDER BY name;