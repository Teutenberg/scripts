DECLARE @objects TABLE ([db_id] INT, [object_id] INT, [object_name] VARCHAR(128));

INSERT INTO @objects
EXEC sp_MSforeachdb 'SELECT DB_ID(''?'') AS [db_id], [object_id], [name] FROM [?].sys.objects WHERE [is_ms_shipped] = 0 AND [type] = ''U'';';

SELECT @@SERVERNAME AS [server_name]
	,[db_name]
	,MAX(CASE WHEN [db_last_access] = '19000101' THEN NULL ELSE [db_last_access] END) AS [db_last_access]
	,[server_last_restart]
	,GETDATE() AS [report_datetime]
FROM
(SELECT [D].[name] AS [db_name],
	ISNULL([X].[last_user_seek],'19000101') AS [last_user_seek],
	ISNULL([X].[last_user_scan],'19000101') AS [last_user_scan],
	ISNULL([X].[last_user_lookup],'19000101') AS [last_user_lookup],
	ISNULL([X].[last_user_update],'19000101') AS [last_user_update],
	(SELECT [create_date] FROM sys.databases WHERE [name] = 'tempdb') AS [server_last_restart]
FROM sys.databases [D]
	LEFT JOIN (SELECT [S].[database_id]
					,[S].[last_user_seek]
					,[S].[last_user_scan]
					,[S].[last_user_lookup]
					,[S].[last_user_update] 
				FROM sys.dm_db_index_usage_stats [S]
					INNER JOIN @objects [O]
						ON [S].[database_id] = [O].[db_id]
							AND [S].[object_id] = [O].[object_id]) [X]
		ON [D].[database_id] = [X].[database_id]
WHERE [D].[name] NOT IN ('master', 'msdb', 'model', 'tempdb', '_dbaid')
	AND [D].[state] = 0
	AND [D].[is_in_standby] = 0) AS [source]
UNPIVOT
(
	[db_last_access] FOR [access_type] IN
	([last_user_seek], [last_user_scan], [last_user_lookup], [last_user_update])
) AS [unpivot]
GROUP BY [db_name]
	,[server_last_restart];
