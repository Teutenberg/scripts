DECLARE @parent_group_id INT; 
SET @parent_group_id = 1;

;WITH [folders] ([group_id], [parent_id], [group_name], [level])
AS
(
-- Anchor member definition
    SELECT [server_group_id]
		,[parent_id] 
		,[name]
		,0 AS [level]
	FROM [msdb].[dbo].[sysmanagement_shared_server_groups_internal]
	WHERE [server_group_id] = @parent_group_id
	UNION ALL
-- Recursive member definition
    SELECT [a].[server_group_id]
		,[a].[parent_id]
		,[a].[name]
		,[b].[level] + 1
    FROM [msdb].[dbo].[sysmanagement_shared_server_groups_internal] [a]
		INNER JOIN [folders] [b]
			ON [a].[parent_id] = [b].[group_id]
)
SELECT [f].[group_id]
	,[f].[parent_id]
	,[f].[group_name]
	,[s].[server_name]
FROM [folders] [f]
	LEFT JOIN [msdb].[dbo].[sysmanagement_shared_registered_servers_internal] [s]
		ON [f].[group_id] = [s].[server_group_id]
