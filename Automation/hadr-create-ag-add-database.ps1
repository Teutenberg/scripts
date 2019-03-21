$SqlPrimary = "server\instance"
$SqlSecondary1 = "server\instance"
$SqlSecondary2 = "server\instance"
$SqlSeviceAccount = "domain\serviceaccount"
$SqlAgName = "AG-APP-ENV"
$SqlDatabase = "DBNAME"

[string[]]$SqlCmdParams = @()
$SqlCmdParams += "PRIMARY=`"$SqlPrimary`""
$SqlCmdParams += "SECONDARY1=`"$SqlSecondary1`""
$SqlCmdParams += "SECONDARY2=`"$SqlSecondary2`""
$SqlCmdParams += "SERVICEACCOUNT=`"$SqlSeviceAccount`""
$SqlCmdParams += "AGNAME=`"$SqlAgName`""
$SqlCmdParams += "DATABASE=`"$SqlDatabase`""

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ($SqlSecondary2.Length -gt 0) {
    $url = "https://digital-dev.nz.thenational.com/stash/projects/DSM/repos/public-share/raw/hadr-create-ag-add-database-3node.sql"
}
else {
    $url = "https://digital-dev.nz.thenational.com/stash/projects/DSM/repos/public-share/raw/hadr-create-ag-add-database-2node.sql"
}

(Invoke-WebRequest $url).Content | Out-File -FilePath "$env:TEMP\hadr-create-ag-add-database.sql"
& Sqlcmd.exe -S $SqlPrimary -i "$env:TEMP\hadr-create-ag-add-database.sql" -v $SqlCmdParams -X
