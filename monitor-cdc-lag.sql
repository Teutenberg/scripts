SET NOCOUNT ON
DECLARE @LSN NVARCHAR(46), @LSN_HEX NVARCHAR(25);
SELECT TOP 1 @LSN = [last_commit_lsn] FROM sys.dm_cdc_log_scan_sessions WHERE [session_id] = 0;
SELECT @LSN_HEX = CAST(CAST(CONVERT(VARBINARY, SUBSTRING(@LSN, 1, 8), 2) AS INT) AS VARCHAR)
	+ ':' + CAST(CAST(CONVERT(VARBINARY, SUBSTRING(@LSN, 10, 8), 2) AS INT) AS VARCHAR)
	+ ':' + CAST(CAST(CONVERT(VARBINARY, SUBSTRING(@LSN, 19, 4), 2) AS INT) AS VARCHAR);

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
	CROSS APPLY (SELECT [last_commit_lsn], [last_commit_time] FROM sys.dm_cdc_log_scan_sessions WHERE [session_id] = 0) [cdc]
WHERE [a].[object_tracked_by_cdc] = 1
GROUP BY [a].[object_name]
