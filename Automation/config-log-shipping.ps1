$PrimaryDatabaseName     = 'test'
$PrimaryServerInstance   = 'DEMO\TEST6' 
$PrimaryLogshippingDir   = 'G:\logship_send'

$SecondaryDatabaseName   = 'test'
$SecondaryServerInstance = 'DEMO\TEST5'
$SecondaryLogshippingDir = 'G:\logship_receive'

$SqlSysAdminGroup = 'administrators'

$pComputerName = $PrimaryServerInstance.Split('\')[0]
$pInstanceName = $PrimaryServerInstance.Split('\')[1]
$pShareName = Split-Path $PrimaryLogshippingDir -Leaf
$pSharePath = '\\' + (Join-Path $pComputerName  (Split-Path $PrimaryLogshippingDir -Leaf))
$pServiceNameSql = if ($pInstanceName -and $pInstanceName -ine 'MSSQLSERVER') { 'MSSQL$' + $pInstanceName } else { 'MSSQLSERVER' } 
$pServiceNameAgt = if ($pInstanceName -and $pInstanceName -ine 'MSSQLSERVER') { 'SQLAGENT$' + $pInstanceName } else { 'SQLSERVERAGENT' } 
$pServiceAccountSql = (Get-WmiObject Win32_Service -ComputerName $pComputerName | Where-Object { $_.Name -like $pServiceNameSql }).StartName
$pServiceAccountAgt = (Get-WmiObject Win32_Service -ComputerName $pComputerName | Where-Object { $_.Name -like $pServiceNameAgt }).StartName

$sComputerName = $SecondaryServerInstance.Split('\')[0]
$sInstanceName = $SecondaryServerInstance.Split('\')[1]
$sShareName = Split-Path $SecondaryLogshippingDir -Leaf
$sSharePath = '\\' + (Join-Path $sComputerName  (Split-Path $SecondaryLogshippingDir -Leaf))
$sServiceNameSql = if ($sInstanceName -and $sInstanceName -ine 'MSSQLSERVER') { 'MSSQL$' + $sInstanceName } else { 'MSSQLSERVER' } 
$sServiceNameAgt = if ($sInstanceName -and $sInstanceName -ine 'MSSQLSERVER') { 'SQLAGENT$' + $sInstanceName } else { 'SQLSERVERAGENT' } 
$sServiceAccountSql = (Get-WmiObject Win32_Service -ComputerName $sComputerName | Where-Object { $_.Name -like $sServiceNameSql }).StartName
$sServiceAccountAgt = (Get-WmiObject Win32_Service -ComputerName $sComputerName | Where-Object { $_.Name -like $sServiceNameAgt }).StartName

$pSetupLSSql = "DECLARE @BackupJobId UNIQUEIDENTIFIER, @RetCode INT;
EXEC @RetCode = master.dbo.sp_add_log_shipping_primary_database @database = N'$PrimaryDatabaseName',@backup_directory = N'$PrimaryLogshippingDir',@backup_share = N'$pSharePath'
	,@backup_job_name = N'LSBackup_$PrimaryDatabaseName',@backup_retention_period = 4320,@backup_compression = 2,@backup_threshold = 60,@threshold_alert_enabled = 1
	,@history_retention_period = 5760,@backup_job_id = @BackupJobId OUTPUT; 
IF (@@ERROR = 0 AND @RetCode = 0)
BEGIN 
	DECLARE @BackUpScheduleID INT;
	EXEC msdb.dbo.sp_add_schedule @schedule_name =N'LSBackupSchedule_$PrimaryDatabaseName',@enabled = 1
		,@freq_type = 4,@freq_interval = 1,@freq_subday_type = 4 ,@freq_subday_interval = 15 ,@freq_recurrence_factor = 0,@schedule_id = @BackUpScheduleID OUTPUT; 
	EXEC msdb.dbo.sp_attach_schedule @job_id = @BackupJobId, @schedule_id = @BackUpScheduleID;  
	EXEC msdb.dbo.sp_update_job @job_id = @BackupJobId, @enabled = 1;
    EXEC master.dbo.sp_add_log_shipping_primary_secondary @primary_database = N'$PrimaryDatabaseName',@secondary_server = N'$SecondaryServerInstance',@secondary_database = N'$SecondaryDatabaseName';
END"

$pAddBackupTranIgnoreSql = "DECLARE @job_id UNIQUEIDENTIFIER, @command NVARCHAR(MAX);
SELECT @job_id = [job_id] FROM msdb.dbo.sysjobs WHERE [name] = N'_dbaid_backup_user_tran';
IF (@job_id IS NOT NULL)
BEGIN
	SELECT @command = STUFF([command], CHARINDEX('USER_DATABASES',[command])+14, 0, ',-$PrimaryDatabaseName') FROM msdb.dbo.sysjobsteps WHERE [job_id] = @job_id AND [step_id] = 1;
	EXEC msdb.dbo.sp_update_jobstep @job_id=@job_id, @step_id=1, @command=@command;
END"

$sSetupLSSql = "DECLARE @CopyJobId UNIQUEIDENTIFIER, @RestoreJobId UNIQUEIDENTIFIER, @RetCode INT;
EXEC @RetCode = master.dbo.sp_add_log_shipping_secondary_primary @primary_server = N'$PrimaryServerInstance', @primary_database = N'$PrimaryDatabaseName' 
    ,@backup_source_directory = N'$pSharePath ',@backup_destination_directory = N'$sSharePath' 
	,@copy_job_name = N'LSCopy_$PrimaryServerInstance_$PrimaryDatabaseName',@restore_job_name = N'LSRestore_$PrimaryServerInstance_$PrimaryDatabaseName' 
	,@file_retention_period = 4320, @overwrite = 1, @copy_job_id = @CopyJobId OUTPUT, @restore_job_id = @RestoreJobId OUTPUT;
IF (@@ERROR = 0 AND @RetCode = 0) 
BEGIN 
	DECLARE @CopyJobScheduleID INT, @RestoreJobScheduleID INT;
	EXEC msdb.dbo.sp_add_schedule @schedule_name =N'DefaultCopyJobSchedule_$PrimaryServerInstance_$PrimaryDatabaseName' 
        ,@enabled = 1,@freq_type = 4,@freq_interval = 1,@freq_subday_type = 4,@freq_subday_interval = 15,@freq_recurrence_factor = 0,@schedule_id = @CopyJobScheduleID OUTPUT;
	EXEC msdb.dbo.sp_attach_schedule @job_id = @CopyJobId, @schedule_id = @CopyJobScheduleID;
	EXEC msdb.dbo.sp_add_schedule @schedule_name =N'DefaultRestoreJobSchedule_$PrimaryServerInstance_$PrimaryDatabaseName' 
	    ,@enabled = 1,@freq_type = 4,@freq_interval = 1,@freq_subday_type = 4,@freq_subday_interval = 15,@freq_recurrence_factor = 0,@schedule_id = @RestoreJobScheduleID OUTPUT;
	EXEC msdb.dbo.sp_attach_schedule @job_id = @RestoreJobId, @schedule_id = @RestoreJobScheduleID;
	EXEC master.dbo.sp_add_log_shipping_secondary_database @secondary_database = N'$SecondaryDatabaseName',@primary_server = N'$PrimaryServerInstance',@primary_database = N'$PrimaryDatabaseName' 
	    ,@restore_delay = 0,@restore_mode = 0,@disconnect_users = 0,@restore_threshold = 45,@threshold_alert_enabled = 1,@history_retention_period = 5760;
	EXEC msdb.dbo.sp_update_job @job_id = @CopyJobId, @enabled = 1;
	EXEC msdb.dbo.sp_update_job @job_id = @RestoreJobId, @enabled = 1;
END"

$sDataDir = Invoke-Sqlcmd -ServerInstance $SecondaryServerInstance -Database 'master' -Query "SELECT [path]=CONVERT(SYSNAME, SERVERPROPERTY('InstanceDefaultDataPath'))" -OutputSqlErrors $true
$sLogDir = Invoke-Sqlcmd -ServerInstance $SecondaryServerInstance -Database 'master' -Query "SELECT [path]=CONVERT(SYSNAME, SERVERPROPERTY('InstanceDefaultLogPath'))" -OutputSqlErrors $true
$sBackupFileList = Invoke-Sqlcmd -ServerInstance $SecondaryServerInstance -Database 'master' -Query "RESTORE FILELISTONLY FROM DISK = N'$pSharePath\$PrimaryDatabaseName.bak'" | Select LogicalName, PhysicalName, Type
$sMoveStatement = ($sBackupFileList.ForEach({"MOVE '" + $_.LogicalName + "' TO '" + (&{if ($_.Type -eq 'L') {$sLogDir.path} else {$sDataDir.path}}) + (Split-Path $_.PhysicalName -Leaf) + "'"})) -join ', '
$sRestoreBackup = "RESTORE DATABASE [$PrimaryDatabaseName] FROM DISK = N'$pSharePath\$PrimaryDatabaseName.bak' WITH NORECOVERY, $sMoveStatement"

#region: SETUP LogShipping on Primary
Invoke-Command -ComputerName $pComputerName -ScriptBlock {if (!(Test-Path $Using:PrimaryLogshippingDir)) { New-Item $Using:PrimaryLogshippingDir -type directory }}

Invoke-Command -ComputerName $pComputerName -ScriptBlock {
    $acl = Get-Acl $Using:PrimaryLogshippingDir
    $acl.SetAccessRule($(New-Object Security.AccessControl.FileSystemAccessRule($Using:SqlSysAdminGroup,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))
    $acl.SetAccessRule($(New-Object system.security.accesscontrol.filesystemaccessrule($Using:pServiceNameSql,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))
    $acl.SetAccessRule($(New-Object system.security.accesscontrol.filesystemaccessrule($Using:sServiceNameAgt,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))
    Set-Acl $Using:PrimaryLogshippingDir $acl

    if (Get-SmbShare | Where { $_.Name -eq $Using:pShareName }) {
        Grant-SmbShareAccess -Name $Using:pShareName -AccountName $Using:SqlSysAdminGroup, $Using:pServiceNameSql, $Using:pServiceNameAgt, $Using:sServiceNameSql, $Using:sServiceNameAgt -AccessRight Full -Force
    } else {
        New-SmbShare –Name $Using:pShareName –Path $Using:PrimaryLogshippingDir -FullAccess $Using:SqlSysAdminGroup, $Using:pServiceNameSql, $Using:pServiceNameAgt, $Using:sServiceNameSql, $Using:sServiceNameAgt
    }
}

Invoke-Sqlcmd -ServerInstance $PrimaryServerInstance -Database 'master' -Query $pAddBackupTranIgnoreSql -OutputSqlErrors $true
Invoke-Sqlcmd -ServerInstance $PrimaryServerInstance -Database 'master' -Query "ALTER DATABASE [$PrimaryDatabaseName] SET RECOVERY FULL WITH NO_WAIT" -OutputSqlErrors $true
Invoke-Sqlcmd -ServerInstance $PrimaryServerInstance -Database 'master' -Query "BACKUP DATABASE [$PrimaryDatabaseName] TO DISK = N'$PrimaryLogshippingDir\$PrimaryDatabaseName.bak' WITH NOINIT" -OutputSqlErrors $true
Invoke-Sqlcmd -ServerInstance $PrimaryServerInstance -Database 'master' -Query $pSetupLSSql -OutputSqlErrors $true
#endregion

#region: SETUP LogShipping on Secondary
Invoke-Command -ComputerName $sComputerName -ScriptBlock {if (!(Test-Path $Using:SecondaryLogshippingDir)) { New-Item $Using:SecondaryLogshippingDir -type directory }}

Invoke-Command -ComputerName $sComputerName -ScriptBlock {
    $acl = Get-Acl $Using:SecondaryLogshippingDir
    $acl.SetAccessRule($(New-Object Security.AccessControl.FileSystemAccessRule($Using:SqlSysAdminGroup,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))
    $acl.SetAccessRule($(New-Object system.security.accesscontrol.filesystemaccessrule($Using:sServiceNameSql,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))
    $acl.SetAccessRule($(New-Object system.security.accesscontrol.filesystemaccessrule($Using:sServiceNameAgt,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))
    Set-Acl $Using:SecondaryLogshippingDir $acl

    if (Get-SmbShare | Where { $_.Name -eq $Using:sShareName }) {
        Grant-SmbShareAccess -Name $Using:sShareName -AccountName $Using:SqlSysAdminGroup, $Using:sServiceNameSql, $Using:sServiceNameAgt -AccessRight Full -Force
    } else {
        New-SmbShare –Name $Using:sShareName –Path $Using:SecondaryLogshippingDir -FullAccess $Using:SqlSysAdminGroup, $Using:sServiceNameSql, $Using:sServiceNameAgt
    }
}

Invoke-Sqlcmd -ServerInstance $SecondaryServerInstance -Database 'master' -Query $sRestoreBackup -OutputSqlErrors $true
Invoke-Sqlcmd -ServerInstance $SecondaryServerInstance -Database 'master' -Query $sSetupLSSql -OutputSqlErrors $true
#endregion
