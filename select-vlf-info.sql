 /*Create two temp tables, one for current db VLF and one for the total VLFs collected*/
DECLARE @vlf_temp TABLE ([FileID] VARCHAR(3)
						,[FileSize] NUMERIC(20,0)
						,[StartOffset] BIGINT
						,[FSeqNo] BIGINT
						,[Status] CHAR(1)
						,[Parity] VARCHAR(4)
						,[CreateLSN] NUMERIC(25,0));

DECLARE @vlf_temp_2012 TABLE ([RecoveryUnitId] INT
							,[FileID] VARCHAR(3)
							,[FileSize] NUMERIC(20,0)
							,[StartOffset] BIGINT
							,[FSeqNo] BIGINT
							,[Status] CHAR(1)
							,[Parity] VARCHAR(4)
							,[CreateLSN] NUMERIC(25,0));
 
DECLARE @vlf_temp_total TABLE ([name] SYSNAME, [vlf_count] INT);

DECLARE @file_info AS TABLE ([database_id] INT,
							[file_name] NVARCHAR(128),
							[size_used_mb] NUMERIC(20,2),
							[size_reserved_mb] NUMERIC(20,2));

DECLARE @product NUMERIC(4,2), @db_name sysname, @stmt varchar(40);

INSERT INTO @file_info
		EXEC sp_MSforeachdb N'USE [?]; 
			SELECT DB_ID() AS [database_id]
				,[m].[name]
				,CAST(ISNULL(fileproperty([m].[name],''SpaceUsed''),0)/128.00 AS NUMERIC(20,2)) AS [size_used_mb]
				,CAST([m].[size]/128.00 AS NUMERIC(20,2)) AS [size_reserved_mb]
			FROM [sys].[database_files] [m]
			WHERE [m].[type] IN (1)'; 

SELECT @product = LEFT(CAST(SERVERPROPERTY('productversion') AS VARCHAR), 4);

DECLARE [db_curse] CURSOR FAST_FORWARD
FOR SELECT [name] FROM [sys].[databases];

OPEN [db_curse];
FETCH NEXT FROM [db_curse] INTO @db_name;

WHILE (@@fetch_status <> -1)
BEGIN
      IF (@@fetch_status <> -2)
      BEGIN
			IF @product >= 11     
				INSERT INTO @vlf_temp_2012 EXEC ('DBCC LOGINFO ([' + @db_name + ']) WITH NO_INFOMSGS');
			ELSE
				INSERT INTO @vlf_temp EXEC ('DBCC LOGINFO ([' + @db_name + ']) WITH NO_INFOMSGS');

            INSERT INTO @vlf_temp_total
				SELECT @db_name, COUNT(*) 
				FROM @vlf_temp
				UNION ALL 
				SELECT @db_name, COUNT(*) 
				FROM @vlf_temp_2012;

            DELETE @vlf_temp;
			DELETE @vlf_temp_2012;
      END
      FETCH NEXT FROM [db_curse] INTO @db_name;
END
CLOSE [db_curse];
DEALLOCATE [db_curse];

SELECT TOP 10 @@servername AS [server_name]
	,[vlf].[name] AS [db_name]
	,[vlf].[vlf_count] AS [vlf_count]
	,N'USE [' 
		+ [vlf].[name] 
		+ ']; DBCC SHRINKFILE (N''' 
		+ [fi].[file_name] 
		+ ''' , 0, TRUNCATEONLY); USE [master]; ALTER DATABASE [' 
		+ [vlf].[name] 
		+ '] MODIFY FILE ( NAME = N''' 
		+ [fi].[file_name] 
		+ ''', SIZE = ' 
		+ '1000' --CAST(FLOOR([fi].[size_reserved_mb]) AS NVARCHAR(20)) 
		+ 'MB )' AS [fixer_code]
FROM @vlf_temp_total [vlf]
	INNER JOIN @file_info [fi]
		ON DB_ID([vlf].[name]) = [fi].[database_id]
--WHERE [vlf_count] > 100
ORDER BY [vlf_count] DESC;