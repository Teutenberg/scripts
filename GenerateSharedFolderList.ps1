#$Servers = Get-Content -Path ".\server.txt"
$Servers = $(Get-ADComputer -Filter * -SearchBase "OU=Servers,DC=Domain,DC=co,DC=nz" | Select -Expand Name);

[array]$Shares = @();

foreach ($Server in $Servers)
{
    [array]$NetView = @();

    try
    {
        $NetView = $(net view $Server 2>$null);
    }
    catch { $NetView = @() }

    if ($NetView.Count -gt 2)
    {
        $NetView = $($NetView | select -Index $(7..$($NetView.Count - 3)));

        foreach ($Line in $NetView)
        {
            if ($Line.Contains(" Disk "))
            {
                $Path = "\\$Server\" + $Line.Substring(0, $Line.IndexOf(" Disk ")).Trim();
                
                if (Test-Path $Path 2>$null)
                {
                    try
                    {
                        Get-ChildItem $Path -ErrorAction Stop | Out-Null
                    
                        $Shares += $Path;
                    }
                    catch {}
                }
            }
        }
    }
}

$Shares | Out-File -FilePath ".\shares.txt"
