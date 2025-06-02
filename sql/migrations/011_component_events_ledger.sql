-- Migration: Add ComponentEvents ledger table for Azure SQL Ledger
-- Created: Component Association Feature Implementation
-- Description: Creates a ledger table to track component attachment/detachment events for immutable audit trail

-- Create ComponentEvents ledger table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'ComponentEvents' AND SCHEMA_NAME(schema_id) = 'HandReceipt')
BEGIN
    CREATE TABLE HandReceipt.ComponentEvents (
        EventID UNIQUEIDENTIFIER DEFAULT NEWID() PRIMARY KEY,
        ParentPropertyID BIGINT NOT NULL,
        ComponentPropertyID BIGINT NOT NULL,
        AttachingUserID BIGINT NOT NULL,
        EventType NVARCHAR(50) NOT NULL CHECK (EventType IN ('ATTACHED', 'DETACHED')),
        Position NVARCHAR(100) NULL,
        Notes NVARCHAR(1000) NULL,
        EventTimestamp DATETIME2(7) NOT NULL DEFAULT SYSUTCDATETIME(),
        
        -- Ledger table specific columns will be automatically added by Azure SQL Ledger
        -- No need to explicitly define them
        
        CONSTRAINT FK_ComponentEvents_ParentProperty 
            FOREIGN KEY (ParentPropertyID) REFERENCES HandReceipt.Properties(ID),
        CONSTRAINT FK_ComponentEvents_ComponentProperty 
            FOREIGN KEY (ComponentPropertyID) REFERENCES HandReceipt.Properties(ID),
        CONSTRAINT FK_ComponentEvents_User 
            FOREIGN KEY (AttachingUserID) REFERENCES HandReceipt.Users(ID)
    ) WITH (LEDGER = ON);
    
    PRINT 'ComponentEvents ledger table created successfully';
END
ELSE
BEGIN
    PRINT 'ComponentEvents table already exists';
END

-- Create indexes for better performance
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_ComponentEvents_ParentPropertyID' AND object_id = OBJECT_ID('HandReceipt.ComponentEvents'))
BEGIN
    CREATE INDEX IX_ComponentEvents_ParentPropertyID ON HandReceipt.ComponentEvents(ParentPropertyID);
    PRINT 'Index IX_ComponentEvents_ParentPropertyID created';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_ComponentEvents_ComponentPropertyID' AND object_id = OBJECT_ID('HandReceipt.ComponentEvents'))
BEGIN
    CREATE INDEX IX_ComponentEvents_ComponentPropertyID ON HandReceipt.ComponentEvents(ComponentPropertyID);
    PRINT 'Index IX_ComponentEvents_ComponentPropertyID created';
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_ComponentEvents_EventTimestamp' AND object_id = OBJECT_ID('HandReceipt.ComponentEvents'))
BEGIN
    CREATE INDEX IX_ComponentEvents_EventTimestamp ON HandReceipt.ComponentEvents(EventTimestamp DESC);
    PRINT 'Index IX_ComponentEvents_EventTimestamp created';
END

-- Update the general history view to include component events
IF EXISTS (SELECT * FROM sys.views WHERE name = 'GeneralHistory' AND SCHEMA_NAME(schema_id) = 'HandReceipt')
BEGIN
    -- Drop the existing view so we can recreate it with component events
    DROP VIEW HandReceipt.GeneralHistory;
    PRINT 'Dropped existing GeneralHistory view for recreation';
END

-- Recreate the general history view with component events included
CREATE VIEW HandReceipt.GeneralHistory AS
WITH CombinedHistory AS (
    -- Equipment Events
    SELECT
        EventID AS eventId,
        'EquipmentEvent' AS eventType,
        EventTimestamp AS timestamp,
        TRY_CAST(PerformingUserID AS BIGINT) AS userId,
        TRY_CAST(ItemID AS BIGINT) AS itemId,
        JSON_OBJECT(
            'eventTypeDetail', EventType,
            'notes', Notes
        ) AS detailsJson,
        ledger_transaction_id AS ledgerTransactionId,
        ledger_sequence_number AS ledgerSequenceNumber
    FROM HandReceipt.EquipmentEvents_LedgerHistory

    UNION ALL

    -- Transfer Events
    SELECT
        EventID AS eventId,
        'TransferEvent' AS eventType,
        EventTimestamp AS timestamp,
        TRY_CAST(InitiatingUserID AS BIGINT) AS userId,
        TRY_CAST(ItemID AS BIGINT) AS itemId,
        JSON_OBJECT(
            'transferRequestId', TransferRequestID,
            'fromUserId', FromUserID,
            'toUserId', ToUserID,
            'eventTypeDetail', EventType,
            'notes', Notes
        ) AS detailsJson,
        ledger_transaction_id AS ledgerTransactionId,
        ledger_sequence_number AS ledgerSequenceNumber
    FROM HandReceipt.TransferEvents_LedgerHistory

    UNION ALL

    -- Verification Events
    SELECT
        EventID AS eventId,
        'VerificationEvent' AS eventType,
        VerificationTimestamp AS timestamp,
        TRY_CAST(VerifyingUserID AS BIGINT) AS userId,
        TRY_CAST(ItemID AS BIGINT) AS itemId,
        JSON_OBJECT(
            'verificationStatus', VerificationStatus,
            'notes', Notes
        ) AS detailsJson,
        ledger_transaction_id AS ledgerTransactionId,
        ledger_sequence_number AS ledgerSequenceNumber
    FROM HandReceipt.VerificationEvents_LedgerHistory

    UNION ALL

    -- Maintenance Events
    SELECT
        EventID AS eventId,
        'MaintenanceEvent' AS eventType,
        EventTimestamp AS timestamp,
        TRY_CAST(InitiatingUserID AS BIGINT) AS userId,
        TRY_CAST(ItemID AS BIGINT) AS itemId,
        JSON_OBJECT(
            'maintenanceRecordId', MaintenanceRecordID,
            'eventTypeDetail', EventType,
            'maintenanceType', MaintenanceType,
            'description', Description
        ) AS detailsJson,
        ledger_transaction_id AS ledgerTransactionId,
        ledger_sequence_number AS ledgerSequenceNumber
    FROM HandReceipt.MaintenanceEvents_LedgerHistory

    UNION ALL

    -- Status Change Events
    SELECT
        EventID AS eventId,
        'StatusChangeEvent' AS eventType,
        ChangeTimestamp AS timestamp,
        TRY_CAST(ReportingUserID AS BIGINT) AS userId,
        TRY_CAST(ItemID AS BIGINT) AS itemId,
        JSON_OBJECT(
            'previousStatus', PreviousStatus,
            'newStatus', NewStatus,
            'reason', Reason
        ) AS detailsJson,
        ledger_transaction_id AS ledgerTransactionId,
        ledger_sequence_number AS ledgerSequenceNumber
    FROM HandReceipt.StatusChangeEvents_LedgerHistory

    UNION ALL

    -- Component Events (NEW)
    SELECT
        EventID AS eventId,
        'ComponentEvent' AS eventType,
        EventTimestamp AS timestamp,
        TRY_CAST(AttachingUserID AS BIGINT) AS userId,
        TRY_CAST(ParentPropertyID AS BIGINT) AS itemId, -- Use parent property as the main item
        JSON_OBJECT(
            'eventTypeDetail', EventType,
            'parentPropertyId', ParentPropertyID,
            'componentPropertyId', ComponentPropertyID,
            'position', Position,
            'notes', Notes
        ) AS detailsJson,
        ledger_transaction_id AS ledgerTransactionId,
        ledger_sequence_number AS ledgerSequenceNumber
    FROM HandReceipt.ComponentEvents_LedgerHistory
)
SELECT eventId, eventType, timestamp, userId, itemId, detailsJson, ledgerTransactionId, ledgerSequenceNumber
FROM CombinedHistory;

PRINT 'GeneralHistory view recreated with ComponentEvents included';

PRINT 'Component Events ledger migration completed successfully'; 