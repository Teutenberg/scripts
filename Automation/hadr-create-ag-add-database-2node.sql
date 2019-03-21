-- YOU MUST EXECUTE THE FOLLOWING SCRIPT IN SQLCMD MODE.
:SETVAR PRIMARY		"SORBSPSQLQ01\SP2013"
:SETVAR SECONDARY1 "SORBSPSQLQ02\SP2013"
:SETVAR SERVICEACCOUNT "BNZNAG\SrvSQLsrvSP01PPTE"
:SETVAR AGNAME "AG-SP-PPTE"
:SETVAR DATABASE "AGTest"

:Connect $(PRIMARY)

USE [master]
GO

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'$(SERVICEACCOUNT)')
	CREATE LOGIN [$(SERVICEACCOUNT)] FROM WINDOWS WITH DEFAULT_DATABASE=[master];

GRANT CONNECT ON ENDPOINT::[hadr-endpoint] TO [$(SERVICEACCOUNT)];
GRANT CONNECT SQL TO [$(SERVICEACCOUNT)];
GO

DECLARE @url_p NVARCHAR(128), @url_s1 NVARCHAR(128), @sql NVARCHAR(MAX);
SET @url_p = N'TCP://' + SUBSTRING('$(PRIMARY)',0,CHARINDEX('\', '$(PRIMARY)')) + N'.BNZNAG.NZ.THENATIONAL.com:5022';
SET @url_s1 = N'TCP://' + SUBSTRING('$(SECONDARY1)',0,CHARINDEX('\', '$(SECONDARY1)')) + N'.BNZNAG.NZ.THENATIONAL.com:5022';

IF NOT EXISTS (SELECT * FROM sys.availability_groups WHERE [name] = N'$(AGNAME)')
BEGIN
	SET @sql = N'CREATE AVAILABILITY GROUP [$(AGNAME)]
	WITH (AUTOMATED_BACKUP_PREFERENCE = SECONDARY)
	FOR 
	REPLICA ON 
		N''$(PRIMARY)'' WITH (
			ENDPOINT_URL = N''' + @url_p + N''', 
			FAILOVER_MODE = AUTOMATIC, 
			AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, 
			SESSION_TIMEOUT = 30, 
			BACKUP_PRIORITY = 50, 
			PRIMARY_ROLE(ALLOW_CONNECTIONS = ALL), 
			SECONDARY_ROLE(ALLOW_CONNECTIONS = NO)
		),
		N''$(SECONDARY1)'' WITH (
			ENDPOINT_URL = N''' + @url_s1 + N''', 
			FAILOVER_MODE = AUTOMATIC, 
			AVAILABILITY_MODE = SYNCHRONOUS_COMMIT, 
			SESSION_TIMEOUT = 30, 
			BACKUP_PRIORITY = 50, 
			PRIMARY_ROLE(ALLOW_CONNECTIONS = ALL), 
			SECONDARY_ROLE(ALLOW_CONNECTIONS = NO)
		);';
	
	EXEC sp_executesql @sql;
	PRINT '[$(PRIMARY)] - Created availability group [$(AGNAME)]';
END
GO

IF NOT EXISTS (SELECT * FROM sys.availability_databases_cluster [db] 
	INNER JOIN sys.availability_groups [g] ON [db].[group_id] = [g].[group_id] 
	WHERE [db].[database_name] = N'$(DATABASE)' AND [g].[name] = N'$(AGNAME)')
BEGIN
	ALTER AVAILABILITY GROUP [$(AGNAME)] ADD DATABASE [$(DATABASE)];
	PRINT '[$(PRIMARY)] - Added database [$(DATABASE)] to AG [$(AGNAME)]';
END
GO

DECLARE @path NVARCHAR(128);
SET @path = N'\\' + SUBSTRING('$(PRIMARY)',0,CHARINDEX('\', '$(PRIMARY)')) + N'\$(AGNAME)\$(DATABASE).bak';

IF EXISTS (SELECT * 
			FROM sys.dm_hadr_database_replica_states [s]
				INNER JOIN sys.availability_replicas [r] ON [s].replica_id = [r].[replica_id]
				INNER JOIN sys.availability_groups [ag] ON [s].[group_id] = [ag].[group_id]
				INNER JOIN sys.databases [db] ON [s].[database_id] = [db].[database_id]
			WHERE [db].[name] = N'AGTest'
				AND [ag].[name] = N'AG-SP-PPTE'
				AND [s].[synchronization_state] = 0
				AND [r].[replica_server_name] IN (N'$(PRIMARY)', N'$(SECONDARY1)'))
BEGIN
	BACKUP DATABASE [$(DATABASE)] TO DISK = @path WITH COPY_ONLY, FORMAT, INIT, SKIP, REWIND, NOUNLOAD, COMPRESSION;
END
GO

:Connect $(SECONDARY1)
IF NOT EXISTS (SELECT * FROM sys.availability_groups WHERE [name] = N'$(AGNAME)')
BEGIN
	ALTER AVAILABILITY GROUP [$(AGNAME)] JOIN;
	PRINT '[$(SECONDARY1)] - Joined server to AG [$(AGNAME)]';
END

DECLARE @path NVARCHAR(128);
SET @path = N'\\' + SUBSTRING('$(PRIMARY)',0,CHARINDEX('\', '$(PRIMARY)')) + N'\$(AGNAME)\$(DATABASE).bak';

IF NOT EXISTS (SELECT * 
				FROM sys.dm_hadr_database_replica_states [s]
					INNER JOIN sys.availability_replicas [r] ON [s].replica_id = [r].[replica_id]
					INNER JOIN sys.availability_groups [ag] ON [s].[group_id] = [ag].[group_id]
					INNER JOIN sys.databases [db] ON [s].[database_id] = [db].[database_id]
				WHERE [db].[name] = N'$(DATABASE)'
					AND [ag].[name] = N'$(AGNAME)'
					AND [s].[synchronization_state] <> 0
					AND [r].[replica_server_name] = @@SERVERNAME)
	RESTORE DATABASE [$(DATABASE)] FROM DISK = @path WITH NORECOVERY, NOUNLOAD, REPLACE;
GO


:Connect $(PRIMARY)
DECLARE @path NVARCHAR(128);
SET @path = N'\\' + SUBSTRING('$(PRIMARY)',0,CHARINDEX('\', '$(PRIMARY)')) + N'\$(AGNAME)\$(DATABASE).trn';

IF EXISTS (SELECT * 
			FROM sys.dm_hadr_database_replica_states [s]
				INNER JOIN sys.availability_replicas [r] ON [s].replica_id = [r].[replica_id]
				INNER JOIN sys.availability_groups [ag] ON [s].[group_id] = [ag].[group_id]
				INNER JOIN sys.databases [db] ON [s].[database_id] = [db].[database_id]
			WHERE [db].[name] = N'$(DATABASE)'
				AND [ag].[name] = N'$(AGNAME)'
				AND [s].[synchronization_state] = 0
				AND [r].[replica_server_name] IN (N'$(PRIMARY)', N'$(SECONDARY1)'))
BEGIN
	BACKUP LOG [$(DATABASE)] TO DISK = @path WITH NOFORMAT, INIT, NOSKIP, REWIND, NOUNLOAD, COMPRESSION;
END
GO

:Connect $(SECONDARY1)
DECLARE @path NVARCHAR(128);
SET @path = N'\\' + SUBSTRING('$(PRIMARY)',0,CHARINDEX('\', '$(PRIMARY)')) + N'\$(AGNAME)\$(DATABASE).trn';

IF NOT EXISTS (SELECT * 
				FROM sys.dm_hadr_database_replica_states [s]
					INNER JOIN sys.availability_replicas [r] ON [s].replica_id = [r].[replica_id]
					INNER JOIN sys.availability_groups [ag] ON [s].[group_id] = [ag].[group_id]
					INNER JOIN sys.databases [db] ON [s].[database_id] = [db].[database_id]
				WHERE [db].[name] = N'$(DATABASE)'
					AND [ag].[name] = N'$(AGNAME)'
					AND [s].[synchronization_state] <> 0
					AND [r].[replica_server_name] = @@SERVERNAME)
	RESTORE LOG [$(DATABASE)] FROM DISK = @path WITH NORECOVERY, NOUNLOAD;
GO

-- Wait for the replica to start communicating
begin try
declare @conn bit
declare @count int
declare @replica_id uniqueidentifier 
declare @group_id uniqueidentifier
set @conn = 0
set @count = 30 -- wait for 5 minutes 

if (serverproperty('IsHadrEnabled') = 1)
	and (isnull((select member_state from master.sys.dm_hadr_cluster_members where upper(member_name COLLATE Latin1_General_CI_AS) = upper(cast(serverproperty('ComputerNamePhysicalNetBIOS') as nvarchar(256)) COLLATE Latin1_General_CI_AS)), 0) <> 0)
	and (isnull((select state from master.sys.database_mirroring_endpoints), 1) = 0)
begin
    select @group_id = ags.group_id from master.sys.availability_groups as ags where name = N'$(AGNAME)'
	select @replica_id = replicas.replica_id from master.sys.availability_replicas as replicas where upper(replicas.replica_server_name COLLATE Latin1_General_CI_AS) = upper(@@SERVERNAME COLLATE Latin1_General_CI_AS) and group_id = @group_id
	while @conn <> 1 and @count > 0
	begin
		set @conn = isnull((select connected_state from master.sys.dm_hadr_availability_replica_states as states where states.replica_id = @replica_id), 1)
		if @conn = 1
		begin
			-- exit loop when the replica is connected, or if the query cannot find the replica status
			break
		end
		waitfor delay '00:00:10'
		set @count = @count - 1
	end
end
end try
begin catch
	-- If the wait loop fails, do not stop execution of the alter database statement
end catch

IF NOT EXISTS (SELECT * 
				FROM sys.dm_hadr_database_replica_states [s]
					INNER JOIN sys.availability_replicas [r] ON [s].replica_id = [r].[replica_id]
					INNER JOIN sys.availability_groups [ag] ON [s].[group_id] = [ag].[group_id]
					INNER JOIN sys.databases [db] ON [s].[database_id] = [db].[database_id]
				WHERE [db].[name] = N'$(DATABASE)'
					AND [ag].[name] = N'$(AGNAME)'
					AND [s].[synchronization_state] <> 0
					AND [r].[replica_server_name] = @@SERVERNAME)
BEGIN
	ALTER DATABASE [$(DATABASE)] SET HADR AVAILABILITY GROUP = [$(AGNAME)];
	PRINT '[$(SECONDARY1)] - Joined database [$(DATABASE)] to AG [$(AGNAME)]';
END
GO