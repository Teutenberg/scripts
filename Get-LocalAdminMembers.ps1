$cn = new-object System.Data.SqlClient.SqlConnection("Data Source=WS12SQL;Integrated Security=SSPI;Initial Catalog=ServerAnalysis");

Import-Module ActiveDirectory

$localAdmins = $([ADSI]("WinNT://$env:computername/Administrators,group")).Members() | 
        ForEach  { $_.GetType().InvokeMember("Adspath", "GetProperty", $null, $_, $null).Split("/")[-2] +
            "," + 
            $_.GetType().InvokeMember("Adspath", "GetProperty", $null, $_, $null).Split("/")[-1] + 
            "," + 
            $_.GetType().InvokeMember("Class", "GetProperty", $null, $_, $null) } | 
        ConvertFrom-Csv -Header $("Domain","Name","Class");

$dt = new-object Data.datatable;
$dt.Columns.Add("sid") | out-null
$dt.Columns.Add("name") | out-null
$dt.Columns.Add("source") | out-null

foreach ($account in $LocalAdmins) 
{
    if ($account.Class -eq "User" -and $account.Domain -ne $env:computername)
    {
        $member = Get-ADUser -Identity $account.Name -Properties * | Select SID, UserPrincipalName, @{Name="Source";Expression={$account.Domain}}
        $dt.Rows.Add($member.SID, $member.UserPrincipalName, $member.Source) | out-null
    }
    if ($account.Class -eq "Group" -and $account.Domain -ne $env:computername)
    {
        $members = Get-ADGroupMember -Identity $account.Name -recursive | Get-ADUser -Properties * | Select SID, UserPrincipalName, @{Name="Source";Expression={$account.Name}}

        foreach ($member in $members)
        {
            $dt.Rows.Add($member.SID, $member.UserPrincipalName, $member.Source) | out-null
        }
    }
    if ($account.Domain -eq $env:computername)
    {
        $dt.Rows.Add($(New-Object System.Security.Principal.NTAccount($account.Name)).Translate([System.Security.Principal.SecurityIdentifier]).Value, $account.Name, $account.Domain) | out-null
    }
}

$cn.Open()
$bc = new-object ("System.Data.SqlClient.SqlBulkCopy") $cn
$bc.DestinationTableName = "dbo.LogicalDisk"
$bc.WriteToServer($dt)
$cn.Close()
