[string]$SqlInstanceName = "SQL2017"
[string]$SqlAgName = "AG"
[string]$SqlPrimaryNode = "SRV01"
[string[]]$SqlSecondaryNodes = ("SRV02,SRV21").Split(",")
[string]$SqlAdminUsername = "DOMAIN\Username"

Import-Module dbatools, SqlServerDsc

if ($SqlInstanceName) {
	$SqlPrimary = Join-Path $SqlPrimaryNode $SqlInstanceName
}
else {
	$SqlPrimary = $SqlPrimaryNode
}

$SqlCred = Get-Credential -UserName $SqlAdminUsername -Message "Enter SQL Admin Password"
$SqlBackupFolder = (Get-DbaDefaultPath -SqlInstance $SqlPrimary -SqlCredential $SqlCred).Backup
$SqlShareFolder = Join-Path $SqlBackupFolder $SqlAgName
$SqlShareUnc = "\\$env:COMPUTERNAME\$SqlAgName"
$PrimaryHadr = Get-DbaAgHadr $SqlPrimary -SqlCredential $SqlCred

# Only executes on Primary. if Primary ServerName = Current ServerName 
if ($PrimaryHadr.ComputerNamePhysicalNetBIOS -ieq $env:COMPUTERNAME) {
    if (!(Test-Path $SqlShareFolder)) { 
        New-Item $SqlShareFolder -type directory 
    }

    [string[]]$SmbAccess = (Get-DbaService -Type Engine).StartName
    $SmbAccess += (Get-DbaService -ComputerName $SqlSecondaryNodes -Type Engine -Credential $SqlCred).StartName
    $SmbAccess = $SmbAccess | Select-Object -Unique

    $acl = Get-Acl $SqlShareFolder
    $SmbAccess.Where({$_.Length -gt 0}).ForEach({$acl.SetAccessRule($(New-Object system.security.accesscontrol.filesystemaccessrule($_,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))})

    Set-Acl $SqlShareFolder $acl

    if (Get-SmbShare | Where { $_.Name -eq $SqlAgName }) {
        Grant-SmbShareAccess -Name $SqlAgName -AccountName $SmbAccess.Where({$_.Length -gt 0}) -AccessRight Full -Force
        Write-Output "Granted permissions to existing share $SqlShareUnc"
    } else {
        New-SmbShare –Name $SqlAgName –Path $SqlShareFolder -FullAccess $SmbAccess.Where({$_.Length -gt 0})
        Write-Output "Created new share $SqlShareUnc"
    }

    $UserDatabases = Get-DbaDatabase -SqlInstance $SqlPrimary -Status Normal -ExcludeDatabase _dbaid -ExcludeSystem | Where { $_.AvailabilityGroupName -ine $SqlAgName } | Sort-Object -Property Size
    $UserDatabases | Set-DbaDbRecoveryModel -RecoveryModel Full -Confirm:$false

    foreach ($db in $UserDatabases) {
        $SqlJobCmdBau = "SELECT [command] FROM msdb.dbo.sysjobsteps WHERE [step_name] = N'DatabaseBackup - USER_DATABASES - LOG' AND [step_id] = 1"
        $SqlJobCmdTemp = "SELECT STUFF([command], CHARINDEX('USER_DATABASES', [command]), 14, 'USER_DATABASES,-$($db.Name)') FROM msdb.dbo.sysjobsteps WHERE [step_name] = N'DatabaseBackup - USER_DATABASES - LOG' AND [step_id] = 1"
        $CmdBau = Invoke-DbaQuery -SqlInstance $SqlPrimary -Query $SqlJobCmdBau -SqlCredential $SqlCred
        $CmdTemp = Invoke-DbaQuery -SqlInstance $SqlPrimary -Query $SqlJobCmdTemp -SqlCredential $SqlCred

        Set-DbaAgentJobStep -SqlInstance $SqlPrimary -Job "DatabaseBackup - USER_DATABASES - LOG" -StepName "DatabaseBackup - USER_DATABASES - LOG" -Command $CmdTemp[0] -SqlCredential $SqlCred

        Backup-DbaDatabase -SqlInstance $SqlPrimary -Database $db.Name -BackupDirectory $SqlShareUnc -Type Full -FileCount 4 -CompressBackup
        Backup-DbaDatabase -SqlInstance $SqlPrimary -Database $db.Name -BackupDirectory $SqlShareUnc -Type Log -CompressBackup
 
        # Create the availability group on the instance tagged as the primary replica
        #region
        $Params = @{
            AvailabilityGroupName   = $SqlAgName
            BackupPath              = $SqlShareUnc
            DatabaseName            = @($db.Name)
            InstanceName            = $SqlInstanceName
            ServerName              = $SqlPrimaryNode
            Ensure                  = 'Present'
            ProcessOnlyOnActiveNode = $true
            PsDscRunAsCredential    = $SqlCred
        }

        if (Invoke-DscResource -ModuleName SqlServerDsc -Name SqlAGDatabase -Property $Params -Method Test) {
            Write-Output 'Skipping SqlAGDatabase - Already Configured...'	
        }
        else {
            Write-Output 'Configuring SqlAGDatabase...'
	        Invoke-DscResource -ModuleName SqlServerDsc -Name SqlAGDatabase -Property $Params -Method Set
        }
        #endregion

        Set-DbaAgentJobStep -SqlInstance $SqlPrimary -Job "DatabaseBackup - USER_DATABASES - LOG" -StepName "DatabaseBackup - USER_DATABASES - LOG" -Command $CmdBau[0] -SqlCredential $SqlCred
    }
}
