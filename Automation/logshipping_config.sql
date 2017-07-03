-- Execute the following statements at the Primary to configure Log Shipping 
-- The script needs to be run at the Primary in the context of the [msdb] database.  
------------------------------------------------------------------------------------- 
-- Adding the Log Shipping configuration 
-- ****** Begin: Script to be run at Primary ******

:SETVAR DatabaseName "MyDatabase"
:SETVAR PrimaryServer "MySQLServer"
:SETVAR SecondaryServer "MyDRSQLServer"
:SETVAR LogShippingDirName "logshipping"

DECLARE @LS_BackupJobId UNIQUEIDENTIFIER
	,@LS_PrimaryId UNIQUEIDENTIFIER
	,@SP_Add_RetCode INT
	,@LS_BackUpScheduleUID UNIQUEIDENTIFIER
	,@LS_BackUpScheduleID INT
	,@LS_BackUpDirectory VARCHAR(256)
	,@LS_BackUpFile VARCHAR(256)
	,@XP_Tree TABLE(subdirectory NVARCHAR(255), depth INT);

ALTER DATABASE [$(DatabaseName)] SET RECOVERY FULL WITH NO_WAIT;

EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @LS_BackUpDirectory OUTPUT;
SET @LS_BackupDirectory = @LS_BackupDirectory + '\$(LogShippingDirName)\$(DatabaseName)';
SET @LS_BackUpFile = @LS_BackupDirectory + '\$(DatabaseName).bak';

INSERT INTO @XP_Tree
	EXEC master.sys.xp_dirtree @LS_BackupDirectory;

IF NOT EXISTS (SELECT 1 FROM @DirTree WHERE [subdirectory] = '$(DatabaseName)')
	EXEC master.dbo.xp_create_subdir @LS_BackupDirectory;

BACKUP DATABASE [$(DatabaseName)] TO DISK=@LS_BackUpFile WITH COMPRESSION;

EXEC @SP_Add_RetCode = master.dbo.sp_add_log_shipping_primary_database @database = N'$(DatabaseName)' 
		,@backup_directory = @LS_BackUpDirectory 
		,@backup_share = N'\\$(PrimaryServer)\$(LogShippingDirName)\$(DatabaseName)' 
		,@backup_job_name = N'LSBackup_$(DatabaseName)' 
		,@backup_retention_period = 4320
		,@backup_compression = 1
		,@backup_threshold = 60 
		,@threshold_alert_enabled = 1
		,@history_retention_period = 5760
		,@overwrite = 1
		,@backup_job_id = @LS_BackupJobId OUTPUT, @primary_id = @LS_PrimaryId OUTPUT;

IF (@@ERROR = 0 AND @SP_Add_RetCode = 0) 
BEGIN 
	EXEC msdb.dbo.sp_add_schedule @schedule_name =N'DefaultLogBackupJobSchedule' 
			,@enabled = 1 
			,@freq_type = 4 
			,@freq_interval = 1 
			,@freq_subday_type = 4 
			,@freq_subday_interval = 10 
			,@freq_recurrence_factor = 0 
			,@active_start_date = 20170703 
			,@active_end_date = 99991231 
			,@active_start_time = 0 
			,@active_end_time = 235900 
			,@schedule_uid = @LS_BackUpScheduleUID OUTPUT, @schedule_id = @LS_BackUpScheduleID OUTPUT;

	EXEC msdb.dbo.sp_attach_schedule @job_id = @LS_BackupJobId, @schedule_id = @LS_BackUpScheduleID;
	EXEC msdb.dbo.sp_update_job @job_id = @LS_BackupJobId, @enabled = 1;
END 

EXEC master.dbo.sp_add_log_shipping_primary_secondary @primary_database=N'$(DatabaseName)'
	,@secondary_server=N'$(SecondaryServer)'
	,@secondary_database=N'$(DatabaseName)'
	,@overwrite=1; 

-- ****** End: Script to be run at Primary  ******

-- Execute the following statements at the Secondary to configure Log Shipping 
-- the script needs to be run at the Secondary in the context of the [msdb] database. 
------------------------------------------------------------------------------------- 
-- Adding the Log Shipping configuration 
-- ****** Begin: Script to be run at Secondary ******

DECLARE @LS_Secondary__CopyJobId UNIQUEIDENTIFIER
	,@LS_Secondary__RestoreJobId UNIQUEIDENTIFIER
	,@LS_Secondary__SecondaryId UNIQUEIDENTIFIER 
	,@LS_Add_RetCode INT
	,@LS_Add_RetCode2 INT
	,@LS_SecondaryCopyJobScheduleUID UNIQUEIDENTIFIER
	,@LS_SecondaryRestoreJobScheduleUID UNIQUEIDENTIFIER
	,@LS_SecondaryCopyJobScheduleID INT
	,@LS_SecondaryRestoreJobScheduleID INT;

EXEC @LS_Add_RetCode = master.dbo.sp_add_log_shipping_secondary_primary @primary_server = N'$(PrimaryServer)' 
	,@primary_database = N'$(DatabaseName)' 
	,@backup_source_directory = N'\\$(PrimaryServer)\$(LogShippingDirName)\$(DatabaseName)' 
	,@backup_destination_directory = N'\\$(SecondaryServer)\$(LogShippingDirName)\$(DatabaseName)' 
	,@copy_job_name = N'LSCopy_$(PrimaryServer)_$(DatabaseName)' 
	,@restore_job_name = N'LSRestore_$(PrimaryServer)_$(DatabaseName)' 
	,@file_retention_period = 4320 
	,@overwrite = 1 
	,@copy_job_id = @LS_Secondary__CopyJobId OUTPUT 
	,@restore_job_id = @LS_Secondary__RestoreJobId OUTPUT 
	,@secondary_id = @LS_Secondary__SecondaryId OUTPUT 

IF (@@ERROR = 0 AND @LS_Add_RetCode = 0) 
BEGIN 
	EXEC msdb.dbo.sp_add_schedule @schedule_name =N'DefaultCopyJobSchedule' 
		,@enabled = 1 
		,@freq_type = 4 
		,@freq_interval = 1 
		,@freq_subday_type = 4 
		,@freq_subday_interval = 10 
		,@freq_recurrence_factor = 0 
		,@active_start_date = 20170703 
		,@active_end_date = 99991231 
		,@active_start_time = 500 
		,@active_end_time = 235900 
		,@schedule_uid = @LS_SecondaryCopyJobScheduleUID OUTPUT, @schedule_id = @LS_SecondaryCopyJobScheduleID OUTPUT;

	EXEC msdb.dbo.sp_add_schedule @schedule_name =N'DefaultRestoreJobSchedule' 
		,@enabled = 1 
		,@freq_type = 4 
		,@freq_interval = 1 
		,@freq_subday_type = 4 
		,@freq_subday_interval = 15 
		,@freq_recurrence_factor = 0 
		,@active_start_date = 20170703 
		,@active_end_date = 99991231 
		,@active_start_time = 0 
		,@active_end_time = 235900 
		,@schedule_uid = @LS_SecondaryRestoreJobScheduleUID OUTPUT, @schedule_id = @LS_SecondaryRestoreJobScheduleID OUTPUT;

	EXEC msdb.dbo.sp_attach_schedule @job_id = @LS_Secondary__CopyJobId, @schedule_id = @LS_SecondaryCopyJobScheduleID;  
	EXEC msdb.dbo.sp_attach_schedule @job_id = @LS_Secondary__RestoreJobId, @schedule_id = @LS_SecondaryRestoreJobScheduleID;
END 

IF (@@ERROR = 0 AND @LS_Add_RetCode = 0) 
BEGIN 
	EXEC @LS_Add_RetCode2 = master.dbo.sp_add_log_shipping_secondary_database @secondary_database = N'$(DatabaseName)' 
		,@primary_server = N'$(PrimaryServer)', @primary_database = N'$(DatabaseName)' 
		,@restore_delay = 0 
		,@restore_mode = 0 
		,@disconnect_users	= 0 
		,@restore_threshold = 60   
		,@threshold_alert_enabled = 1 
		,@history_retention_period	= 5760 
		,@overwrite = 1 
END 

IF (@@error = 0 AND @LS_Add_RetCode = 0) 
BEGIN 
	EXEC msdb.dbo.sp_update_job @job_id = @LS_Secondary__CopyJobId, @enabled = 1;
	EXEC msdb.dbo.sp_update_job @job_id = @LS_Secondary__RestoreJobId, @enabled = 1;
END 

-- ****** End: Script to be run at Secondary ******
