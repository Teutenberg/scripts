USE [master]
GO

/****** Object:  Database [wayne_db_audit]    Script Date: 9/03/2017 9:01:55 a.m. ******/
CREATE DATABASE [db_audit]
GO

USE [db_audit]
GO

CREATE TABLE [dbo].[last_user_access_staging](
	[server_name] [nvarchar](128) NOT NULL,
	[db_name] [nvarchar](128) NOT NULL,
	[db_last_access] [datetime] NULL,
	[server_last_restart] [datetime] NOT NULL,
	[report_datatime] [datetime] NOT NULL
) ON [PRIMARY]
GO

CREATE TABLE [dbo].[last_user_access](
	[server_name] [nvarchar](128) NOT NULL,
	[db_name] [nvarchar](128) NOT NULL,
	[db_last_access] [datetime] NULL,
	[server_last_restart] [datetime] NOT NULL,
	[report_datatime] [datetime] NOT NULL
) ON [PRIMARY]
GO

CREATE PROCEDURE [dbo].[stage_last_user_access]
AS
BEGIN
	MERGE [dbo].[last_user_access] AS [target]
	USING (
	SELECT [server_name]
		,[db_name]
		,[db_last_access]
		,[server_last_restart]
		,[report_datatime]
	FROM [dbo].[last_user_access_staging]
	) AS [source]
	ON ([target].[server_name] = [source].[server_name] 
		AND [target].[db_name] = [source].[db_name]) 
	WHEN MATCHED THEN
		UPDATE SET [target].[db_last_access] = ISNULL([source].[db_last_access], [target].[db_last_access])
			,[target].[server_last_restart] = [source].[server_last_restart]
			,[target].[report_datatime] = [source].[report_datatime]
	WHEN NOT MATCHED BY TARGET THEN 
		INSERT VALUES ([source].[server_name]
		,[source].[db_name]
		,ISNULL([source].[db_last_access], [source].[server_last_restart])
		,[source].[server_last_restart]
		,[source].[report_datatime])
	WHEN NOT MATCHED BY SOURCE AND DATEDIFF(DAY, [target].[report_datatime], GETDATE()) > 5 THEN
		DELETE;

	TRUNCATE TABLE [dbo].[last_user_access_staging];
END
GO
