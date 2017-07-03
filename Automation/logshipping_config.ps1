$InstName = "MSSQLSERVER"
$SqlAdminGroup = "DOMAIN\MSSQL-Admins"
$LsDirName = "logshipping"

$RegPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\" + $(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').$InstName;
$BakPath = $(Get-ItemProperty "$RegPath\\MSSQLServer").BackupDirectory
$LsPath = Join-Path -Path $BakPath -ChildPath $LsDirName
$NtServiceSql = "NT Service\MSSQL"
$NtServiceAgt = "NT Service\SQL"

if (($InstName.Length -eq 0) -or ($InstName -eq "MSSQLSERVER"))
{
    $NtServiceSql = $NtServiceSql + "SERVER"
    $NtServiceAgt = $NtServiceAgt + "SERVERAGENT"
}
else
{
    $NtServiceSql = $NtServiceSql + "`$$InstName"
    $NtServiceAgt = $NtServiceAgt + "AGENT`$$InstName"
}

If (!(Test-Path $LsPath))
{
    New-Item $LsPath -type directory
}

$Acl = Get-Acl $LsPath
$Acl.SetAccessRule($(New-Object Security.AccessControl.FileSystemAccessRule($SqlAdminGroup,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))
$Acl.SetAccessRule($(New-Object system.security.accesscontrol.filesystemaccessrule($NtServiceSql,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))
$Acl.SetAccessRule($(New-Object system.security.accesscontrol.filesystemaccessrule($NtServiceAgt,"FullControl","ContainerInherit,ObjectInherit","None","Allow")))
Set-Acl $LsPath $Acl

New-SmbShare –Name $LsDirName –Path $LsPath -FullAccess $SqlAdminGroup, $NtServiceSql, $NtServiceAgt
