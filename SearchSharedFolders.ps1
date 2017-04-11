$Shares = Get-Content -Path ".\shares.txt"
[array]$Found = @();

foreach ($Path in $Shares)
{
    Get-ChildItem "$Path" -Recurse | 
        Where-Object { $_.extension -eq ".txt" -or $_.extension -eq ".config" -or $_.extension -eq ".msg" -or $_.extension -eq ".xml" -or $_.extension -eq ".doc" -or $_.extension -eq ".xls" -or $_.extension -eq ".docx" -or $_.extension -eq ".xlsx" } | 
            Select-String -Context 0 -pattern "(password=)|(password:)|(<password>)|(user id=)|(;pwd=)|(;uid=)" | 
                Out-File ".\Results.txt" -NoClobber -Append 
}
