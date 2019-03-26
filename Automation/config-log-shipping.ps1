Param(
    [parameter(Mandatory=$true, HelpMessage='(Mandatory) Primary source SQL Server: "HOST\INSTANCE"')]
    [ValidateNotNullOrEmpty()]
    [string]
    $PrimaryServerInstance,
    
    [parameter(Mandatory=$true, HelpMessage='(Mandatory) Secondary destination SQL Server: "HOST\INSTANCE"')]
    [ValidateNotNullOrEmpty()]
    [string]
    $SecondaryServerInstance,

    [parameter(Mandatory=$true, HelpMessage='(Mandatory) Primary source SQL database: "DBNAME"')]
    [ValidateNotNullOrEmpty()]
    [string]
    $PrimaryDatabaseName,

    [parameter(Mandatory=$false, HelpMessage='Secondary destination SQL database (Default=PrimaryDatabaseName): "DBNAME"')]
    [ValidateNotNullOrEmpty()]
    [string]
    $SecondaryDatabaseName = $PrimaryDatabaseName + '_blah',
     
    [parameter(Mandatory=$false, HelpMessage='Primary source SMB share path (Default=database backup path): "E:\logshipping"')]
    [ValidateNotNullOrEmpty()]
    [string]
    $PrimaryLogshippingDir,

    [parameter(Mandatory=$false, HelpMessage='Secondary destination SMB share path (Default=database backup path): "E:\logshipping"')]
    [ValidateNotNullOrEmpty()]
    [string]
    $SecondaryLogshippingDir,

    [parameter(Mandatory=$false, HelpMessage='Restore the secondary database to the same directory structure as the primary database (Default=Default database paths): "$true"')]
    [ValidateNotNullOrEmpty()]
    [bool]
    $SecondaryRestoreMatchDir = $true,

    [parameter(Mandatory=$false, HelpMessage='SQL Server sysadmin AD group will be granted permissions to the SMB shares: "domain\groupname"')]
    [ValidateNotNullOrEmpty()]
    [string]
    $SqlSysAdminGroup
)
#region: <# AUTO PARAMETERS #>
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo");
$pSQLServerObject = New-Object Microsoft.SqlServer.Management.Smo.Server($PrimaryServerInstance)
$sSQLServerObject = New-Object Microsoft.SqlServer.Management.Smo.Server($SecondaryServerInstance)

if (!$PrimaryLogshippingDir) {
    $PrimaryLogshippingDir = Join-Path $pSQLServerObject.BackupDirectory 'logshipping\send'
}
if (!$SecondaryLogshippingDir) {
    $SecondaryLogshippingDir = Join-Path $sSQLServerObject.BackupDirectory 'logshipping\receive'
}

$pServerInstance = $pSQLServerObject.Name
$pComputerName = $pSQLServerObject.ComputerNamePhysicalNetBIOS
$pInstanceName = $pSQLServerObject.ServiceName
$pInstanceId = $pSQLServerObject.ServiceInstanceId
[array]$pDatabaseFiles = $pSQLServerObject.databases[$PrimaryDatabaseName].FileGroups.Files | Select Name, FileName, @{Name='Type';E={'D'}}
$pDatabaseFiles += $pSQLServerObject.databases[$PrimaryDatabaseName].LogFiles | Select Name, FileName, @{Name='Type';E={'L'}}
$pLogShipDir = $PrimaryLogshippingDir
$pShareName = Split-Path $pLogShipDir -Leaf
$pSharePath = '\\' + (Join-Path $pComputerName $pShareName) 
$pServiceAccountSql = $pSQLServerObject.ServiceAccount
$pServiceAccountAgt = $pSQLServerObject.JobServer.ServiceAccount

$sServerInstance = $sSQLServerObject.Name
$sComputerName = $sSQLServerObject.ComputerNamePhysicalNetBIOS
$sInstanceName = $sSQLServerObject.ServiceName
$sInstanceId = $sSQLServerObject.ServiceInstanceId
$sLogShipDir = $SecondaryLogshippingDir
$sShareName = Split-Path $sLogShipDir -Leaf
$sSharePath = '\\' + (Join-Path $sComputerName $sShareName)
$sServiceAccountSql = $sSQLServerObject.ServiceAccount
$sServiceAccountAgt = $sSQLServerObject.JobServer.ServiceAccount
$sDefaultDataDir = $sSQLServerObject.DefaultFile
$sDefaultLogDir = $sSQLServerObject.DefaultLog
$sMoveStr = ''

if ($SecondaryRestoreMatchDir) {
    $sMoveStr = ($pDatabaseFiles.ForEach({", MOVE '" + $_.Name + "' TO '" + $_.FileName.Replace($pInstanceId,$sInstanceId).Replace($PrimaryDatabaseName,$SecondaryDatabaseName) + "'"})) -join ''
} else {
    $sMoveStr = ($pDatabaseFiles.ForEach({", MOVE '" + $_.Name + "' TO '" + (&{if ($_.Type -eq 'L') {$sDefaultLogDir} else {$sDefaultDataDir}}) + (Split-Path $_.FileName -Leaf).Replace($PrimaryDatabaseName,$SecondaryDatabaseName) + "'"})) -join ''
}

$sRestoreBackup = "RESTORE DATABASE [$SecondaryDatabaseName] FROM DISK = N'$pSharePath\$PrimaryDatabaseName.bak' WITH REPLACE, NORECOVERY$sMoveStr"

$pSetupLSSql = "DECLARE @BackupJobId UNIQUEIDENTIFIER, @RetCode INT;
EXEC @RetCode = master.dbo.sp_add_log_shipping_primary_database @database = N'$PrimaryDatabaseName',@backup_directory = N'$pLogShipDir',@backup_share = N'$pSharePath'
	,@backup_job_name = N'LSBackup_$PrimaryDatabaseName',@backup_retention_period = 4320,@backup_compression = 2,@backup_threshold = 60,@threshold_alert_enabled = 1
	,@history_retention_period = 5760,@backup_job_id = @BackupJobId OUTPUT,@overwrite = 1; 
IF (@@ERROR = 0 AND @RetCode = 0)
BEGIN 
	DECLARE @BackUpScheduleID INT;
	EXEC msdb.dbo.sp_add_schedule @schedule_name =N'LSBackupSchedule_$PrimaryDatabaseName',@enabled = 1
		,@freq_type = 4,@freq_interval = 1,@freq_subday_type = 4 ,@freq_subday_interval = 15 ,@freq_recurrence_factor = 0,@schedule_id = @BackUpScheduleID OUTPUT; 
	EXEC msdb.dbo.sp_attach_schedule @job_id = @BackupJobId, @schedule_id = @BackUpScheduleID;  
	EXEC msdb.dbo.sp_update_job @job_id = @BackupJobId, @enabled = 1;
    EXEC master.dbo.sp_add_log_shipping_primary_secondary @primary_database = N'$PrimaryDatabaseName',@secondary_server = N'$sServerInstance',@secondary_database = N'$SecondaryDatabaseName',@overwrite = 1;
END"

$pAddBackupTranIgnoreSql = "DECLARE @job_id UNIQUEIDENTIFIER, @step_cmd NVARCHAR(MAX);
SELECT @job_id = [job_id] FROM msdb.dbo.sysjobs WHERE [name] = N'_dbaid_backup_user_tran';
SELECT @step_cmd = [command] FROM msdb.dbo.sysjobsteps WHERE [job_id] = @job_id AND [step_id] = 1;
IF (@job_id IS NOT NULL AND @step_cmd NOT LIKE N'%,-$PrimaryDatabaseName%')
BEGIN
	SELECT @step_cmd = STUFF(@step_cmd, CHARINDEX('USER_DATABASES',@step_cmd)+14, 0, ',-$PrimaryDatabaseName')
	EXEC msdb.dbo.sp_update_jobstep @job_id=@job_id, @step_id=1, @command=@step_cmd;
END"

$sSetupLSSql = "DECLARE @CopyJobId UNIQUEIDENTIFIER, @RestoreJobId UNIQUEIDENTIFIER, @RetCode INT;
EXEC @RetCode = master.dbo.sp_add_log_shipping_secondary_primary @primary_server = N'$pServerInstance', @primary_database = N'$PrimaryDatabaseName' 
    ,@backup_source_directory = N'$pSharePath ',@backup_destination_directory = N'$sSharePath' 
	,@copy_job_name = N'LSCopy_$pServerInstance`_$PrimaryDatabaseName',@restore_job_name = N'LSRestore_$pServerInstance`_$PrimaryDatabaseName' 
	,@file_retention_period = 4320, @overwrite = 1, @copy_job_id = @CopyJobId OUTPUT, @restore_job_id = @RestoreJobId OUTPUT;
IF (@@ERROR = 0 AND @RetCode = 0) 
BEGIN 
	DECLARE @CopyJobScheduleID INT, @RestoreJobScheduleID INT;
	EXEC msdb.dbo.sp_add_schedule @schedule_name =N'DefaultCopyJobSchedule_$pServerInstance`_$PrimaryDatabaseName' 
        ,@enabled = 1,@freq_type = 4,@freq_interval = 1,@freq_subday_type = 4,@freq_subday_interval = 15,@freq_recurrence_factor = 0,@schedule_id = @CopyJobScheduleID OUTPUT;
	EXEC msdb.dbo.sp_attach_schedule @job_id = @CopyJobId, @schedule_id = @CopyJobScheduleID;
	EXEC msdb.dbo.sp_add_schedule @schedule_name =N'DefaultRestoreJobSchedule_$pServerInstance`_$PrimaryDatabaseName' 
	    ,@enabled = 1,@freq_type = 4,@freq_interval = 1,@freq_subday_type = 4,@freq_subday_interval = 15,@freq_recurrence_factor = 0,@schedule_id = @RestoreJobScheduleID OUTPUT;
	EXEC msdb.dbo.sp_attach_schedule @job_id = @RestoreJobId, @schedule_id = @RestoreJobScheduleID;
	EXEC master.dbo.sp_add_log_shipping_secondary_database @secondary_database = N'$SecondaryDatabaseName',@primary_server = N'$pServerInstance',@primary_database = N'$PrimaryDatabaseName' 
	    ,@restore_delay = 0,@restore_mode = 0,@disconnect_users = 0,@restore_threshold = 45,@threshold_alert_enabled = 1,@history_retention_period = 5760,@overwrite = 1;
	EXEC msdb.dbo.sp_update_job @job_id = @CopyJobId, @enabled = 1;
	EXEC msdb.dbo.sp_update_job @job_id = @RestoreJobId, @enabled = 1;
END"

#endregion

#region: SETUP LogShipping
Invoke-Command -ComputerName $pComputerName -ScriptBlock {if (!(Test-Path $Using:pLogShipDir)) { New-Item $Using:pLogShipDir -type directory }}
Invoke-Command -ComputerName $sComputerName -ScriptBlock {if (!(Test-Path $Using:sLogShipDir)) { New-Item $Using:sLogShipDir -type directory }}

Invoke-Command -ComputerName $pComputerName -ScriptBlock {
    $SmbAccess = $Using:SqlSysAdminGroup, $Using:pServiceAccountSql, $Using:pServiceAccountAgt, $Using:sServiceAccountSql, $Using:sServiceAccountAgt
    $acl = Get-Acl $Using:pLogShipDir
    $SmbAccess.Where({$_.Length -gt 0}).ForEach({$acl.SetAccessRule($(New-Object system.security.accesscontrol.filesystemaccessrule($_,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))})
    Set-Acl $Using:pLogShipDir $acl

    if (Get-SmbShare | Where { $_.Name -eq $Using:pShareName }) {
        Grant-SmbShareAccess -Name $Using:pShareName -AccountName $SmbAccess.Where({$_.Length -gt 0}) -AccessRight Full -Force
    } else {
        New-SmbShare –Name $Using:pShareName –Path $Using:pLogShipDir -FullAccess $SmbAccess.Where({$_.Length -gt 0})
    }
}

Invoke-Command -ComputerName $sComputerName -ScriptBlock {
    $SmbAccess = $Using:SqlSysAdminGroup, $Using:sServiceAccountSql, $Using:sServiceAccountAgt
    $acl = Get-Acl $Using:sLogShipDir
    $SmbAccess.Where({$_.Length -gt 0}).ForEach({$acl.SetAccessRule($(New-Object system.security.accesscontrol.filesystemaccessrule($_,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))})
    Set-Acl $Using:sLogShipDir $acl

    if (Get-SmbShare | Where { $_.Name -eq $Using:sShareName }) {
        Grant-SmbShareAccess -Name $Using:sShareName -AccountName $SmbAccess.Where({$_.Length -gt 0}) -AccessRight Full -Force
    } else {
        New-SmbShare –Name $Using:sShareName –Path $Using:sLogShipDir -FullAccess $SmbAccess.Where({$_.Length -gt 0})
    }
}

Invoke-Sqlcmd -ServerInstance $pServerInstance -Database 'master' -Query $pAddBackupTranIgnoreSql -OutputSqlErrors $true
Invoke-Sqlcmd -ServerInstance $pServerInstance -Database 'master' -Query "ALTER DATABASE [$PrimaryDatabaseName] SET RECOVERY FULL WITH NO_WAIT" -OutputSqlErrors $true
Invoke-Sqlcmd -ServerInstance $pServerInstance -Database 'master' -Query "BACKUP DATABASE [$PrimaryDatabaseName] TO DISK = N'$pLogShipDir\$PrimaryDatabaseName.bak' WITH NOINIT" -OutputSqlErrors $true
Invoke-Sqlcmd -ServerInstance $sServerInstance -Database 'master' -Query $sRestoreBackup -OutputSqlErrors $true
Invoke-Sqlcmd -ServerInstance $pServerInstance -Database 'master' -Query $pSetupLSSql -OutputSqlErrors $true
Invoke-Sqlcmd -ServerInstance $sServerInstance -Database 'master' -Query $sSetupLSSql -OutputSqlErrors $true
#endregion
