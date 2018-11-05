SET NOCOUNT ON
DECLARE @LSN NVARCHAR(23), @LSN_HEX NVARCHAR(25), @l1 INT, @l2 INT, @l3 INT;

SELECT TOP 1 @LSN = REVERSE(REPLACE(REVERSE([last_commit_lsn]), CHAR(0), '')) FROM sys.dm_cdc_log_scan_sessions WHERE [session_id] = 0;
SELECT @l1 = CHARINDEX(':', @LSN, 0), @l2 = CHARINDEX(':', @LSN, @l1), @l3 = LEN(@LSN)-@l2-@l1
SELECT @LSN_HEX = CAST(CAST(CONVERT(VARBINARY, SUBSTRING(@LSN, 1, @l1-1), 2) AS INT) AS VARCHAR)
	+ ':' + CAST(CAST(CONVERT(VARBINARY, SUBSTRING(@LSN, @l1+1, @l2-1), 2) AS INT) AS VARCHAR)
	+ ':' + CAST(CAST(CONVERT(VARBINARY, SUBSTRING(@LSN, @l1+@l2+1, @l3), 2) AS INT) AS VARCHAR);

;WITH LogData
AS
(
SELECT [row] = ROW_NUMBER() OVER(PARTITION BY [log].[Transaction ID], [log].[Operation] ORDER BY [log].[Current LSN])
	,[operation] = [log].[Operation]
	,[current_lsn] = [log].[Current LSN]
	,[previous_lsn] = [log].[Previous LSN]
	,[tran_id] = [log].[Transaction ID]
	,[object_name] = OBJECT_NAME([p].[object_id])
	,[object_tracked_by_cdc] = [t].[is_tracked_by_cdc]
	,[commit_time] = [log].[End Time]
FROM fn_dblog(@LSN_HEX, NULL) [log]
	LEFT JOIN sys.allocation_units [au]
		ON [log].[AllocUnitId] = [au].[allocation_unit_id]
	LEFT JOIN sys.partitions [p]
		ON [au].[container_id] = CASE [au].[type] 
			WHEN 1 THEN [p].[hobt_id]
			WHEN 2 THEN [p].[partition_id]
			WHEN 3 THEN [p].[hobt_id] END
	LEFT JOIN sys.tables [t]
		ON [p].[object_id] = [t].[object_id]
WHERE [log].[Operation] IN (N'LOP_INSERT_ROWS', N'LOP_COMMIT_XACT')
)
SELECT [a].[object_name]
	,[log_last_commit_time] = MAX([b].[commit_time])
	,[cdc_last_commit_time] = MAX([cdc].[last_commit_time])
	,[cdc_scan_lag_min] = DATEDIFF(MINUTE, MAX([cdc].[last_commit_time]), GETDATE())
	,[cdc_pending_commands] = COUNT(*)
FROM LogData [a]
	INNER JOIN LogData [b]
		ON [a].[tran_id] = [b].[tran_id]
			AND [a].[row] = [b].[row]
			AND [a].[operation] = N'LOP_INSERT_ROWS'
			AND [b].[operation] = N'LOP_COMMIT_XACT'
	CROSS APPLY (SELECT [last_commit_lsn], [last_commit_time], [latency] FROM sys.dm_cdc_log_scan_sessions WHERE [session_id] = 0) [cdc]
WHERE [a].[object_tracked_by_cdc] = 1
GROUP BY [a].[object_name]
