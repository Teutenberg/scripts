<# USER PARAMETERS #>
[string]$SQLSetupPath          = 'C:\Setup\sqlsetup\mssql2017'
[string]$SQLUpdatePath         = 'C:\Setup\sqlsetup\mssql2017'
[string]$SQLInstanceName       = 'TEST3'
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

<# AUTO PARAMETERS #>
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

$SSMSParams = @{
    Name      = 'SSMS-Setup-ENU'
    Ensure    = 'Present'
    Path      = $SSMSPackage
    Arguments = '/install /passive /norestart'
    ProductId = $SSMSProductId
}

$checkmkParams = @{
    Name      = 'Check_MK Agent 1.2.4p5'
    Ensure    = 'Present'
    Path      = $CheckMkPackage
    Arguments = '/S'
    ProductId = ''
}


<# INSTALL SQLSERVER #>
if ($SQLSetupPath) {
    $testSqlSetup = Invoke-DscResource -ModuleName @{ModuleName='SqlServerDsc'; ModuleVersion='11.4.0.0'} -Name SqlSetup -Property $sqlSetupParams -Method Test

    if (!$testSqlSetup) {
        $setSqlSetup = Invoke-DscResource -ModuleName @{ModuleName='SqlServerDsc'; ModuleVersion='11.4.0.0'} -Name SqlSetup -Property $sqlSetupParams -Method Set
    }
    
    Write-Host 'GET: SQL Server DSC' -BackgroundColor White -ForegroundColor Black
    Invoke-DscResource -ModuleName @{ModuleName='SqlServerDsc'; ModuleVersion='11.4.0.0'} -Name SqlSetup -Property $sqlSetupParams -Method Get
}

<# INSTALL SSMS #>
if ($SSMSPackage) {
    $testSSMS = Invoke-DscResource -ModuleName @{ModuleName='PSDesiredStateConfiguration'; ModuleVersion='1.1'} -Name Package -Property $SSMSParams -Method Test

    if (!$testSSMS) {
        $setSSMS = Invoke-DscResource -ModuleName @{ModuleName='PSDesiredStateConfiguration'; ModuleVersion='1.1'} -Name Package -Property $SSMSParams -Method Set
    }

    Write-Host 'GET: SSMS DSC' -BackgroundColor White -ForegroundColor Black
    Invoke-DscResource -ModuleName @{ModuleName='PSDesiredStateConfiguration'; ModuleVersion='1.1'} -Name Package -Property $SSMSParams -Method Get
}

<# INSTALL CHECKMK #>
if ($CheckMkPackage) {
    $testCheckmk = Invoke-DscResource -ModuleName @{ModuleName='PSDesiredStateConfiguration'; ModuleVersion='1.1'} -Name Package -Property $checkmkParams -Method Test

    if (!$testCheckmk) {
        $setCheckmk = Invoke-DscResource -ModuleName @{ModuleName='PSDesiredStateConfiguration'; ModuleVersion='1.1'} -Name Package -Property $checkmkParams -Method Set
    }

    Write-Host 'GET: CheckMk DSC' -BackgroundColor White -ForegroundColor Black
    Invoke-DscResource -ModuleName @{ModuleName='PSDesiredStateConfiguration'; ModuleVersion='1.1'} -Name Package -Property $checkmkParams -Method Get
}
