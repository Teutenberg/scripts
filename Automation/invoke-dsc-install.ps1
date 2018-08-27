<# USER PARAMETERS #>
[string]$SQLSetupPath          = 'C:\Setup\sqlsetup\mssql2017'
[string]$SQLUpdatePath         = 'C:\Setup\sqlsetup\mssql2017'
[string]$SQLInstanceName       = 'TEST5'
[string]$SQLCollation          = 'Latin1_General_CI_AS'
[string[]]$SQLSysAdminAccounts = 'demo\waynet'
[string]$SQLDataDrive          = 'E:\'
[string]$SQLLogDrive           = 'F:\'
[string]$SQLTempdbDrive        = 'G:\'
[string]$SQLBackupDrive        = 'G:\'
[string]$SSMSPackage           = 'C:\Setup\sqlsetup\SSMS-Setup-ENU.exe'
[string]$SSMSProductId         = '945B6BB0-4D19-4E0F-AE57-B2D94DA32313'
[string]$DBAidSetupPath        = 'C:\Setup\dbaid'
[string]$CheckMkPackage        = 'C:\Setup\checkmk\check-mk-agent-1.2.4p5.exe'

#region: INSTALL SQLSERVER #
$SQLMajorVersion = (Get-Item -Path $(Join-Path $SQLSetupPath 'setup.exe')).VersionInfo.ProductVersion.Split('.')[0]
$BrowserSvcStartupType = if ($SQLInstanceName -eq 'MSSQLSERVER') { 'Disabled' } else { 'Automatic' }

$sqlSetupParams = @{
    SourcePath            = $SQLSetupPath
    InstanceName          = $SQLInstanceName
    Features              = 'SQLENGINE'
    SQLCollation          = $SQLCollation
    SQLSysAdminAccounts   = $SQLSysAdminAccounts
    InstallSharedDir      = 'C:\Program Files\Microsoft SQL Server'
    InstallSharedWOWDir   = 'C:\Program Files (x86)\Microsoft SQL Server'
    InstanceDir           = 'C:\Program Files\Microsoft SQL Server'
    InstallSQLDataDir     = ($SQLDataDrive + '\')
    SQLUserDBDir          = (Join-Path $SQLDataDrive "MSSQL$SQLMajorVersion.$SQLInstanceName\MSSQL\DATA")
    SQLUserDBLogDir       = (Join-Path $SQLLogDrive  "MSSQL$SQLMajorVersion.$SQLInstanceName\MSSQL\DATA")
    SQLTempDBDir          = (Join-Path $SQLTempdbDrive "MSSQL$SQLMajorVersion.$SQLInstanceName\MSSQL\DATA")
    SQLTempDBLogDir       = (Join-Path $SQLTempdbDrive "MSSQL$SQLMajorVersion.$SQLInstanceName\MSSQL\DATA")
    SQLBackupDir          = (Join-Path $SQLBackupDrive  "MSSQL$SQLMajorVersion.$SQLInstanceName\MSSQL\DATA")
    UpdateEnabled         = 'True'
    UpdateSource          = $SQLUpdatePath
    ForceReboot           = $false
    BrowserSvcStartupType = $BrowserSvcStartupType
}

if ($SQLSetupPath) {
    $testSqlSetup = Invoke-DscResource -ModuleName @{ModuleName='SqlServerDsc'; ModuleVersion='11.4.0.0'} -Name SqlSetup -Property $sqlSetupParams -Method Test

    if (!$testSqlSetup) {
        Write-Host 'Installing(SqlSetup)...' -BackgroundColor White -ForegroundColor Black
        Invoke-DscResource -ModuleName @{ModuleName='SqlServerDsc'; ModuleVersion='11.4.0.0'} -Name SqlSetup -Property $sqlSetupParams -Method Set -Verbose
    } else {
        Write-Host 'Skipping(SqlSetup)... SQL Instance already exists.' -BackgroundColor Yellow -ForegroundColor Black
    } 
} else {
    Write-Host 'Skipping(SqlSetup)... No setup path provided.' -BackgroundColor Yellow -ForegroundColor Black
}
#endregion

#region: INSTALL SSMS #
$SSMSParams = @{
    Name      = 'SSMS-Setup-ENU'
    Ensure    = 'Present'
    Path      = $SSMSPackage
    Arguments = '/install /passive /norestart'
    ProductId = $SSMSProductId
}

if ($SSMSPackage) {
    $testSSMS = Invoke-DscResource -ModuleName @{ModuleName='PSDesiredStateConfiguration'; ModuleVersion='1.1'} -Name Package -Property $SSMSParams -Method Test

    if (!$testSSMS) {
        Write-Host 'Installing(SSMS)...' -BackgroundColor White -ForegroundColor Black
        Invoke-DscResource -ModuleName @{ModuleName='PSDesiredStateConfiguration'; ModuleVersion='1.1'} -Name Package -Property $SSMSParams -Method Set -Verbose
    } else {
        Write-Host 'Skipping(SSMS)... Package already installed.' -BackgroundColor Yellow -ForegroundColor Black
    }
} else {
    Write-Host 'Skipping(SSMS)... No package provided.' -BackgroundColor Yellow -ForegroundColor Black
}
#endregion

#region: INSTALL CHECKMK #
if ($CheckMkPackage) {
    $iService = (Get-WmiObject win32_service | ?{$_.Name -like 'Check_MK_Agent'}).PathName
    $installCheckMk = $true

    if ($iService) {
        $iVersion = ([string](.$iService version)).Replace('Check_MK_Agent version ','')
        $pVersion = (Split-Path $CheckMkPackage -Leaf).Replace('check-mk-agent-','').Replace('.exe','')

        if ($iVersion -eq $pVersion) {
            $installCheckMk = $false
        }
    }

    if ($installCheckMk) {
        Write-Host 'Installing CheckMk...' -BackgroundColor White -ForegroundColor Black
        Start-Process -Wait -FilePath $CheckMkPackage -ArgumentList "/S" -PassThru
    } else {
        Write-Host 'Skipping(CheckMk)... Package already installed.' -BackgroundColor Yellow -ForegroundColor Black
    }
} else {
    Write-Host 'Skipping(CheckMk). No package provided.' -BackgroundColor Yellow -ForegroundColor Black
}
#endregion

#region: INSTALL DBAID #
if ($DBAidSetupPath) {
    
    # Create database if not exists
    $testCreateDBAid = Invoke-Sqlcmd -ServerInstance (Join-Path $env:COMPUTERNAME $SQLInstanceName) -Query "SELECT [name] FROM sys.databases WHERE [name] = N'_dbaid'"

    if (!$testCreateDBAid) {
        Write-Host 'Creating DBAid database...' -BackgroundColor White -ForegroundColor Black
        Invoke-Sqlcmd -ServerInstance (Join-Path $env:COMPUTERNAME $SQLInstanceName) -InputFile (Join-Path $DBAidSetupPath 'dbaid_release_create.sql') -OutputSqlErrors $true -Verbose
    } else {
        Write-Host 'Skipping(DBAid)... Database already exists.' -BackgroundColor Yellow -ForegroundColor Black
    }

    # Copy over DBAid executables if not exist 
    ROBOCOPY "$DBAidSetupPath" "C:\Datacom\DBAid" /copy:DAT /dcopy:DAT /MT /xo /r:10 /w:5 /xf "dbaid.checkmk.*" | Out-Null

    # Copy over DBAid checkmk plug-in if not exist 
    $CheckMkLocal = Join-Path (Split-Path (Get-WmiObject win32_service | ?{$_.Name -like 'Check_MK_Agent'}).PathName -Parent) 'local'
    if ($CheckMkLocal) {
        ROBOCOPY "$DBAidSetupPath" "$CheckMkLocal" "dbaid.checkmk.*" /e /copy:DAT /dcopy:DAT /MT /xo /r:10 /w:5 | Out-Null
    }

} else {
    Write-Host 'Skipping(DBAid)... No setup path provided.' -BackgroundColor Yellow -ForegroundColor Black
}
#endregion
