Import-Module SqlPs

[array]$SourceServers = get-content "C:\Datacom\db_audit\servers.txt"
[string]$sql = get-content "C:\Datacom\db_audit\db_audit_last_access.sql"

[string]$DestinationConnectionString = "Data Source=PSVMMAP01\MAPS;Initial Catalog=wayne_db_audit;Integrated Security=True"
[string]$DestinationTableName = "last_user_access_staging"

foreach ($server in $SourceServers)
{
    [string]$ConnectionString = "Data Source=`"" + $server + "`";Initial Catalog=master;Integrated Security=True"

    $sourceConnection  = New-Object System.Data.SqlClient.SQLConnection($ConnectionString)
    $sourceConnection.open()
    $commandSourceData  = New-Object system.Data.SqlClient.SqlCommand($sql,$sourceConnection)
    $commandSourceData.CommandTimeout = 1000
    $reader = $commandSourceData.ExecuteReader()

    try
    {
        $bulkCopy = new-object ("Data.SqlClient.SqlBulkCopy") $DestinationConnectionString
        $bulkCopy.DestinationTableName = $DestinationTableName
        $bulkCopy.BatchSize = 5000
        $bulkCopy.BulkCopyTimeout = 300
        $bulkCopy.WriteToServer($reader)
    }
    catch
    {
        $ex = $_.Exception
        Write-Host "Write-DataTable$($connectionName):$ex.Message"
    }
    finally
    {
        $reader.close() 
    }
}

Invoke-Sqlcmd -ServerInstance PSVMMAP01\MAPS -Query "EXEC [wayne_db_audit].[dbo].[stage_last_user_access];" -QueryTimeout 0 -ConnectionTimeout 1000
