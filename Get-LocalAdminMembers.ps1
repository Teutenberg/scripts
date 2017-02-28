$server = "SERVER1"
$instance = "Default"
$database = "_dbaid"
$tableSchema = "dbo"
$tableName = "localhost_administrators"

Import-Module ActiveDirectory
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null

$smoServer = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList "$server\$instance"
$smoDatabase = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Database
$smoDatabase = $smoServer.Databases.Item($database)
$smoTable = $smoDatabase.tables | where-object { $_.Schema -eq $tableSchema -and $_.Name -eq $tableName } 

if ($smoTable -eq $null)
{
    $smoTable = New-Object('Microsoft.SqlServer.Management.Smo.Table') $smoDatabase, $tableName, $tableSchema

    #Add various columns to the table.   
    $Type = [Microsoft.SqlServer.Management.Smo.DataType]::varchar(128)
    $col1 =  New-Object -TypeName Microsoft.SqlServer.Management.Smo.Column -argumentlist $smoTable,"server", $Type
    $col2 =  New-Object -TypeName Microsoft.SqlServer.Management.Smo.Column -argumentlist $smoTable,"sid", $Type
    $col3 =  New-Object -TypeName Microsoft.SqlServer.Management.Smo.Column -argumentlist $smoTable,"account", $Type  
    $col4 =  New-Object -TypeName Microsoft.SqlServer.Management.Smo.Column -argumentlist $smoTable,"source", $Type  
    $smoTable.Columns.Add($col1)
    $smoTable.Columns.Add($col2)
    $smoTable.Columns.Add($col3)
    $smoTable.Columns.Add($col4)
    $smoTable.Create()
}
else
{
    $smoDatabase.ExecuteNonQuery("DELETE FROM [$tableSchema].[$tableName];")
}

$localAdmins = $([ADSI]("WinNT://$server/Administrators,group")).Members() | ForEach  { $_.GetType().InvokeMember("Adspath", "GetProperty", $null, $_, $null).Split("/")[-2] +
            "," + $_.GetType().InvokeMember("Adspath", "GetProperty", $null, $_, $null).Split("/")[-1] + "," + $_.GetType().InvokeMember("Class", "GetProperty", $null, $_, $null) } | 
            ConvertFrom-Csv -Header $("Domain","Name","Class")

foreach ($account in $LocalAdmins)
{
    if ($account.Class -eq "User" -and $account.Domain -ne $env:computername)
    {
        $member = Get-ADUser -Identity $account.Name -Properties * | Select SID, UserPrincipalName, @{Name="Source";Expression={$account.Domain}}
        $smoDatabase.ExecuteNonQuery("INSERT INTO [$tableSchema].[$tableName] VALUES('$server','$($member.SID)','$($member.UserPrincipalName)','$($member.Source)')")
    }
    if ($account.Class -eq "Group" -and $account.Domain -ne $env:computername)
    {
        $members = Get-ADGroupMember -Identity $account.Name -recursive | Get-ADUser -Properties * | Select SID, UserPrincipalName, @{Name="Source";Expression={$account.Name}}

        foreach ($member in $members)
        {
            $smoDatabase.ExecuteNonQuery("INSERT INTO [$tableSchema].[$tableName] VALUES('$server','$($member.SID)','$($member.UserPrincipalName)','$($member.Source)')")
        }
    }
    if ($account.Domain -eq $env:computername)
    {
        $sid = $(New-Object System.Security.Principal.NTAccount($account.Name)).Translate([System.Security.Principal.SecurityIdentifier]).Value
        $smoDatabase.ExecuteNonQuery("INSERT INTO [$tableSchema].[$tableName] VALUES('$server','$sid','$($account.Name)','$($account.Domain)')")
    }
}
