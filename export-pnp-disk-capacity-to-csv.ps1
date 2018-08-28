[string[]]$ServerNames = 'localhost'
$OutputDir = 'C:\Temp'

$ApolloUrl = 'https://vombatus.datacom.co.nz/thruk/main.html'
$ServiceFilter = 'fs_*'

if (!$myApolloSession) {
    if (!$Cred) {
        $Cred = Get-Credential
    }

    Invoke-WebRequest -Uri $ApolloUrl -Credential $Cred -SessionVariable myApolloSession
} 

foreach ($Server in $ServerNames) {
    $serviceUrl = 'https://vombatus.datacom.co.nz/thruk/cgi-bin/status.cgi?view_mode=json&host=' + $Server + '&columns=display_name'
    $Services = ((Invoke-WebRequest -Uri $serviceUrl -WebSession $myApolloSession).Content | ConvertFrom-Json).Where({ $_.display_name -ilike $serviceFilter })

    if ($Services) {
        [string]$timestamp = Get-Date -Format 'yyyyMMddHHmmss'
        [string]$outFile = Join-Path $outputDir ($Server + '_' + $serviceFilter.Replace('*','%') + "_$timestamp.csv")
        $PnpData = $null

        foreach ($s in $Services) {
            $PnpUrl = 'https://vombatus.datacom.co.nz/pnp4nagios//xport/csv?host=' + $Server + '&view=3&srv=' + $s.display_name
            [datetime]$d = '1970-01-01 00:00:00' 
            $Raw = ((Invoke-WebRequest -Uri $PnpUrl -WebSession $myApolloSession).Content | ConvertFrom-Csv -Delimiter ';')
            $PnpData += $Raw | Select @{Name="service";Expression={$s.display_name}},`
                                    @{Name="localtime";Expression={$d.AddSeconds($_.timestamp).ToLocalTime()}},`
                                    @{Name="min_mb";Expression={ ($_ | Select -ExpandProperty *__MIN) }},`
                                    @{Name="max_mb";Expression={ ($_ | Select -ExpandProperty *__MAX) }},`
                                    @{Name="avg_mb";Expression={ ($_ | Select -ExpandProperty *__AVERAGE) }},`
                                    growth_MIN,`
                                    growth_MAX,`
                                    growth_AVERAGE,`
                                    trend_MIN,`
                                    trend_MAX,`
                                    trend_AVERAGE,`
                                    trend_hoursleft_MIN,`
                                    trend_hoursleft_MAX,`
                                    trend_hoursleft_AVERAGE -skiplast 1
        }
    
        $PnpData | Export-Csv -Path $outFile -NoTypeInformation
    }
}
