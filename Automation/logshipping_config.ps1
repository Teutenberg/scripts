$PrimaryServerInstance   = 'DEMO\TEST6' 
$PrimaryLogshippingDir   = 'G:\logship_send'

$SecondaryServerInstance = 'DEMO\TEST5'
$SecondaryLogshippingDir = 'G:\logship_receive'

$SqlSysAdminGroup = 'administrators'

$pComputerName = $PrimaryServerInstance.Split('\')[0]
$pInstanceName = $PrimaryServerInstance.Split('\')[1]
$pShareName = Split-Path $PrimaryLogshippingDir -Leaf
$pServiceNameSql = if ($pInstanceName -and $pInstanceName -ine 'MSSQLSERVER') { 'MSSQL$' + $pInstanceName } else { 'MSSQLSERVER' } 
$pServiceNameAgt = if ($pInstanceName -and $pInstanceName -ine 'MSSQLSERVER') { 'SQLAGENT$' + $pInstanceName } else { 'SQLSERVERAGENT' } 
$pServiceAccountSql = (Get-WmiObject Win32_Service -ComputerName $pComputerName | Where-Object { $_.Name -like $pServiceNameSql }).StartName
$pServiceAccountAgt = (Get-WmiObject Win32_Service -ComputerName $pComputerName | Where-Object { $_.Name -like $pServiceNameAgt }).StartName

$sComputerName = $SecondaryServerInstance.Split('\')[0]
$sInstanceName = $SecondaryServerInstance.Split('\')[1]
$sShareName = Split-Path $SecondaryLogshippingDir -Leaf
$sServiceNameSql = if ($sInstanceName -and $sInstanceName -ine 'MSSQLSERVER') { 'MSSQL$' + $sInstanceName } else { 'MSSQLSERVER' } 
$sServiceNameAgt = if ($sInstanceName -and $sInstanceName -ine 'MSSQLSERVER') { 'SQLAGENT$' + $sInstanceName } else { 'SQLSERVERAGENT' } 
$sServiceAccountSql = (Get-WmiObject Win32_Service -ComputerName $sComputerName | Where-Object { $_.Name -like $sServiceNameSql }).StartName
$sServiceAccountAgt = (Get-WmiObject Win32_Service -ComputerName $sComputerName | Where-Object { $_.Name -like $sServiceNameAgt }).StartName

Invoke-Command -ComputerName $pComputerName -ScriptBlock {if (!(Test-Path $Using:PrimaryLogshippingDir)) { New-Item $Using:PrimaryLogshippingDir -type directory }}
Invoke-Command -ComputerName $sComputerName -ScriptBlock {if (!(Test-Path $Using:SecondaryLogshippingDir)) { New-Item $Using:SecondaryLogshippingDir -type directory }}

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
