[string]$SqlServer = "SQLSERVERINSTANCE"
[array]$CisBenchmark = @()

$CisBenchmark += @{
    Name = "1.1 Ensure Latest SQL Server Service Packs and Hotfixes are Installed (Not Scored)"
    Test = "SELECT SERVERPROPERTY('ProductLevel') as SP_installed,SERVERPROPERTY('ProductVersion') as Version;"
    Score = $null   
}

$CisBenchmark += @{
    Name = "1.2 Ensure Single-Function Member Servers are Used (Not Scored)"
    Test = $null
    Score = $null
}

$CisBenchmark += @{
    Name = "2.1 Ensure 'Ad Hoc Distributed Queries' Server Configuration Option is set to '0' (Scored)"
    Test = "SELECT name
                ,[value_configured] = CAST(value as int)
                ,[value_in_use] = CAST(value_in_use as int)
                ,[score] = CASE WHEN CAST(value as int)+CAST(value_in_use as int)=0 THEN 1 ELSE 0 END 
            FROM sys.configurations 
            WHERE name = 'Ad Hoc Distributed Queries';"
    Score = $null
}

$CisBenchmark += @{
    Name = "2.2 Ensure 'CLR Enabled' Server Configuration Option is set to '0' (Scored)"
    Test = "SELECT name
                ,[value_configured] = CAST(value as int)
                ,[value_in_use] = CAST(value_in_use as int)
                ,[score] = CASE WHEN CAST(value as int)+CAST(value_in_use as int)=0 THEN 1 ELSE 0 END 
            FROM sys.configurations 
            WHERE name = 'clr enabled';"
    Score = $null
}

$CisBenchmark += @{
    Name = "2.3 Ensure 'Cross DB Ownership Chaining' Server Configuration Option is set to '0' (Scored)"
    Test = "SELECT name
                ,[value_configured] = CAST(value as int)
                ,[value_in_use] = CAST(value_in_use as int)
                ,[score] = CASE WHEN CAST(value as int)+CAST(value_in_use as int)=0 THEN 1 ELSE 0 END 
            FROM sys.configurations 
            WHERE name = 'cross db ownership chaining';"
    Score = $null
}

$CisBenchmark += @{
    Name = "Ensure 'Database Mail XPs' Server Configuration Option is set to '0' (Scored)"
    Test = "SELECT name
                ,[value_configured] = CAST(value as int)
                ,[value_in_use] = CAST(value_in_use as int)
                ,[score] = CASE WHEN CAST(value as int)+CAST(value_in_use as int)=0 THEN 1 ELSE 0 END 
            FROM sys.configurations 
            WHERE name = 'Database Mail XPs';"
    Score = $null
}

$CisBenchmark += @{
    Name = "2.5 Ensure 'Ole Automation Procedures' Server Configuration Option is set to '0' (Scored)"
    Test = "SELECT name
                ,[value_configured] = CAST(value as int)
                ,[value_in_use] = CAST(value_in_use as int)
                ,[score] = CASE WHEN CAST(value as int)+CAST(value_in_use as int)=0 THEN 1 ELSE 0 END 
            FROM sys.configurations 
            WHERE name = 'Ole Automation Procedures';"
    Score = $null
}

$CisBenchmark += @{
    Name = "2.6 Ensure 'Remote Access' Server Configuration Option is set to '0' (Scored)"
    Test = "SELECT name
                ,[value_configured] = CAST(value as int)
                ,[value_in_use] = CAST(value_in_use as int)
                ,[score] = CASE WHEN CAST(value as int)+CAST(value_in_use as int)=0 THEN 1 ELSE 0 END 
            FROM sys.configurations 
            WHERE name = 'remote access';"
    Score = $null
}

$CisBenchmark += @{
    Name = "2.7 Ensure 'Remote Admin Connections' Server Configuration Option is set to '0' (Scored)"
    Test = "SELECT name
                ,[value_configured] = CAST(value as int)
                ,[value_in_use] = CAST(value_in_use as int)
                ,[score] = CASE WHEN SERVERPROPERTY('IsClustered')=0 AND CAST(value as int)+CAST(value_in_use as int)=0 THEN 1 
					WHEN SERVERPROPERTY('IsClustered')=1 THEN 1 ELSE 0 END 
            FROM sys.configurations 
            WHERE name = 'remote admin connections';"
    Score = $null
}

$CisBenchmark += @{
    Name = "2.8 Ensure 'Scan For Startup Procs' Server Configuration Option is set to '0' (Scored)"
    Test = "SELECT name
                ,[value_configured] = CAST(value as int)
                ,[value_in_use] = CAST(value_in_use as int)
                ,[score] = CASE WHEN CAST(value as int)+CAST(value_in_use as int)=0 THEN 1 ELSE 0 END 
            FROM sys.configurations 
            WHERE name = 'scan for startup procs';"
    Score = $null
}

$CisBenchmark += @{
    Name = "2.9 Ensure 'Trustworthy' Database Property is set to 'Off' (Scored)"
    Test = "SELECT [is_trustworthy_on] = COUNT(*)
	            ,[score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END
            FROM sys.databases
            WHERE is_trustworthy_on = 1
            AND name != 'msdb';"
    Score = $null
}

$CisBenchmark += @{
    Name = "2.10 Ensure Unnecessary SQL Server Protocols are set to 'Disabled' (Not Scored)"
    Test = $null
    Score = $null
}

$CisBenchmark += @{
    Name = "2.11 Ensure SQL Server is configured to use non-standard ports (Scored)"
    Test = "DECLARE @getValue VARCHAR(10);
            EXEC master..xp_instance_regread
            @rootkey = N'HKEY_LOCAL_MACHINE',
            @key = N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLServer\SuperSocketNetLib\Tcp\IPAll',
            @value_name = N'TcpPort',
            @value = @getValue OUTPUT;
            SELECT [TcpPort]=@getValue, [score]=CASE @getValue WHEN '1433' THEN 0 ELSE 0 END;"
    Score = $null
}

$CisBenchmark += @{
    Name = "2.12 Ensure 'Hide Instance' option is set to 'Yes' for Production SQL Server instances (Scored)"
    Test = "DECLARE @getValue INT;
            EXEC master..xp_instance_regread
            @rootkey = N'HKEY_LOCAL_MACHINE',
            @key = N'SOFTWARE\Microsoft\Microsoft SQL Server\MSSQLServer\SuperSocketNetLib',
            @value_name = N'HideInstance',
            @value = @getValue OUTPUT;
            SELECT [HideInstance]=@getValue, [score]=CASE @getValue WHEN 1 THEN 1 ELSE 0 END;"
    Score = $null
}

$CisBenchmark += @{
    Name = "2.13 Ensure the 'sa' Login Account is set to 'Disabled' (Scored)"
    Test = "SELECT name, is_disabled, [score]=CASE is_disabled WHEN 1 THEN 1 ELSE 0 END
            FROM sys.server_principals
            WHERE sid = 0x01;"
    Score = $null
}

$CisBenchmark += @{
    Name = "2.14 Ensure the 'sa' Login Account has been renamed (Scored)"
    Test = "SELECT name, [score]=CASE name WHEN 'sa' THEN 0 ELSE 1 END
            FROM sys.server_principals
            WHERE sid = 0x01;"
    Score = $null
}

$CisBenchmark += @{
    Name = "2.15 Ensure 'xp_cmdshell' Server Configuration Option is set to '0' (Scored)"
    Test = "SELECT name
                ,[value_configured] = CAST(value as int)
                ,[value_in_use] = CAST(value_in_use as int)
                ,[score] = CASE WHEN CAST(value as int)+CAST(value_in_use as int)=0 THEN 1 ELSE 0 END 
            FROM sys.configurations 
            WHERE name = 'xp_cmdshell';"
    Score = $null
}

$CisBenchmark += @{
    Name = "2.16 Ensure 'AUTO_CLOSE' is set to 'OFF' on contained databases (Scored)"
    Test = "BEGIN TRY
            EXEC ('SELECT [containment_is_auto_close_on]=COUNT(*),[score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END
            FROM sys.databases
            WHERE containment <> 0 and is_auto_close_on = 1;');
            END TRY 
            BEGIN CATCH
	            SELECT [note]='Does not have contained databases'
            END CATCH"
    Score = $null
}

$CisBenchmark += @{
    Name = "2.17 Ensure no login exists with the name 'sa' (Scored)"
    Test = "SELECT [login_named_sa]=COUNT(*), [score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END
            FROM sys.server_principals
            WHERE name = 'sa';"
    Score = $null
}

$CisBenchmark += @{
    Name = "3.1 Ensure 'Server Authentication' Property is set to 'Windows Authentication Mode' (Scored)"
    Test = "SELECT SERVERPROPERTY('IsIntegratedSecurityOnly') as [login_mode], [score]=CASE SERVERPROPERTY('IsIntegratedSecurityOnly') WHEN 1 THEN 1 ELSE 0 END;"
    Score = $null
}

$CisBenchmark += @{
    Name = "3.2 Ensure CONNECT permissions on the 'guest' user is Revoked within all SQL Server databases excluding the master, msdb and tempdb (Scored)"
    Test = "DECLARE @tbl TABLE ([DatabaseName] NVARCHAR(128));
            INSERT INTO @tbl
            EXEC sp_MSforeachdb 'USE [?];
            SELECT DB_NAME() AS DatabaseName
            FROM sys.database_permissions
            WHERE [grantee_principal_id] = DATABASE_PRINCIPAL_ID(''guest'')
            AND [state_desc] LIKE ''GRANT%''
            AND [permission_name] = ''CONNECT''
            AND DB_NAME() NOT IN (''master'',''tempdb'',''msdb'')';
            SELECT [guest_with_db_access]=COUNT(*),[score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END
            FROM @tbl;"
    Score = $null
}

$CisBenchmark += @{
    Name = "3.3 Ensure 'Orphaned Users' are Dropped From SQL Server Databases (Scored)"
    Test = "DECLARE @tbl TABLE ([UserName] NVARCHAR(128), UserSID VARBINARY(85))
            INSERT INTO @tbl
            EXEC sp_MSforeachdb 'USE [?]; EXEC sp_change_users_login @Action=''Report''';
            SELECT [orphaned_users]=COUNT(*),[score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END
            FROM @tbl;"
    Score = $null
}

$CisBenchmark += @{
    Name = "3.4 Ensure SQL Authentication is not used in contained databases (Scored)"
    Test = "BEGIN TRY
            DECLARE @db NVARCHAR(128), @sql VARCHAR(max), @cmd VARCHAR(max);
            DECLARE @tbl TABLE ([DBUser] NVARCHAR(128))
            DECLARE Curse CURSOR FAST_FORWARD
            FOR SELECT [name] FROM sys.databases WHERE [state]=0;
            SET @sql = 'USE [?]; IF EXISTS (SELECT [name] FROM sys.databases WHERE [database_id]=DB_ID() AND [containment]<>0) 
            SELECT name AS DBUser
            FROM sys.database_principals
            WHERE name NOT IN (''dbo'',''Information_Schema'',''sys'',''guest'')
            AND type IN (''U'',''S'',''G'')
            AND authentication_type = 2';
            OPEN Curse;
            FETCH NEXT FROM Curse INTO @db;
            WHILE(@@FETCH_STATUS=0)
            BEGIN
	            SET @cmd = REPLACE(@sql, '?', @db);
	            INSERT INTO @tbl EXEC(@cmd);
	            FETCH NEXT FROM Curse INTO @db;
            END
            CLOSE Curse;
            DEALLOCATE Curse;
            SELECT [sql_auth_in_contained_db]=COUNT(*),[score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END FROM @tbl
            END TRY
            BEGIN CATCH
	            SELECT [note]='Does not have contained databases'
            END CATCH"
    Score = $null
}

$CisBenchmark += @{
    Name = "3.5 Ensure the SQL Server’s MSSQL Service Account is Not an Administrator (Scored)"
    Test = $null
    Score = $null
}

$CisBenchmark += @{
    Name = "3.6 Ensure the SQL Server’s SQLAgent Service Account is Not an Administrator (Scored)"
    Test = $null
    Score = $null
}

$CisBenchmark += @{
    Name = "3.7 Ensure the SQL Server’s Full-Text Service Account is Not an Administrator (Scored)"
    Test = $null
    Score = $null
}

$CisBenchmark += @{
    Name = "3.8 Ensure only the default permissions specified by Microsoft are granted to the public server role (Scored)"
    Test = "SELECT [non_default_perms]=COUNT(*),[score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END
            FROM master.sys.server_permissions
            WHERE (grantee_principal_id = SUSER_SID(N'public') and state_desc LIKE 'GRANT%')
            AND NOT (state_desc = 'GRANT' 
	            and [permission_name] = 'VIEW ANY DATABASE'
	            and class_desc = 'SERVER')
            AND NOT (state_desc = 'GRANT' 
	            and [permission_name] = 'CONNECT' 
	            and class_desc = 'ENDPOINT' 
	            and major_id = 2)
            AND NOT (state_desc = 'GRANT' 
	            and [permission_name] = 'CONNECT' 
	            and class_desc = 'ENDPOINT' 
	            and major_id = 3)
            AND NOT (state_desc = 'GRANT' 
	            and [permission_name] = 'CONNECT' 
	            and class_desc = 'ENDPOINT' 
	            and major_id = 4)
            AND NOT (state_desc = 'GRANT' 
	            and [permission_name] = 'CONNECT' 
	            and class_desc = 'ENDPOINT' 
	            and major_id = 5);"
    Score = $null
}

$CisBenchmark += @{
    Name = "3.9 Ensure Windows BUILTIN groups are not SQL Logins (Scored)"
    Test = "SELECT [is_builtin_admin]=COUNT(*),[score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END
            FROM sys.server_principals pr
            JOIN sys.server_permissions pe
            ON pr.principal_id = pe.grantee_principal_id
            WHERE pr.name like 'BUILTIN%';"
    Score = $null
}

$CisBenchmark += @{
    Name = "3.10 Ensure Windows local groups are not SQL Logins (Scored)"
    Test = "SELECT [local_groups_with_logins]=COUNT(*),[score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END
            FROM sys.server_principals pr
            JOIN sys.server_permissions pe
            ON pr.[principal_id] = pe.[grantee_principal_id]
            WHERE pr.[type_desc] = 'WINDOWS_GROUP'
            AND pr.[name] like CAST(SERVERPROPERTY('MachineName') AS nvarchar) + '%';"
    Score = $null
}

$CisBenchmark += @{
    Name = "3.11 Ensure the public role in the msdb database is not granted access to SQL Agent proxies (Scored)"
    Test = "USE [msdb]
            GO
            SELECT [public_access_proxy]=COUNT(*),[score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END
            FROM dbo.sysproxylogin spl
            JOIN sys.database_principals dp
            ON dp.sid = spl.sid
            JOIN sysproxies sp
            ON sp.proxy_id = spl.proxy_id
            WHERE principal_id = USER_ID('public');
            GO"
    Score = $null
}

$CisBenchmark += @{
    Name = "4.1 Ensure 'MUST_CHANGE' Option is set to 'ON' for All SQL Authenticated Logins (Not Scored)"
    Test = $null
    Score = $null
}

$CisBenchmark += @{
    Name = "4.2 Ensure 'CHECK_EXPIRATION' Option is set to 'ON' for All SQL Authenticated Logins Within the Sysadmin Role (Scored)"
    Test = "SELECT DISTINCT 'sysadmin' AS [Access_Method], [no_expiration] = COUNT(*), [score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END
            FROM sys.sql_logins AS l
            WHERE IS_SRVROLEMEMBER('sysadmin',name) = 1
            AND l.is_expiration_checked <> 1
            AND l.sid <> 0x01
            UNION ALL
            SELECT DISTINCT 'CONTROL SERVER' AS 'Access_Method', [no_expiration] = COUNT(*), [score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END
            FROM sys.sql_logins AS l
            JOIN sys.server_permissions AS p
            ON l.principal_id = p.grantee_principal_id
            WHERE p.type = 'CL' AND p.state IN ('G', 'W')
            AND l.is_expiration_checked <> 1;"
    Score = $null
}

$CisBenchmark += @{
    Name = "4.3 Ensure 'CHECK_POLICY' Option is set to 'ON' for All SQL Authenticated Logins (Scored)"
    Test = "SELECT [policy_not_checked]=COUNT(*),[score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END
            FROM sys.sql_logins
            WHERE is_policy_checked = 0;"
    Score = $null
}

$CisBenchmark += @{
    Name = "5.1 Ensure 'Maximum number of error log files' is set to greater than or equal to '12' (Scored)"
    Test = "DECLARE @Errorlogs TABLE([no] INT, [date] DATETIME, [size] BIGINT)
            DECLARE @NumErrorLogs int;
            EXEC master.sys.xp_instance_regread
            N'HKEY_LOCAL_MACHINE',
            N'Software\Microsoft\MSSQLServer\MSSQLServer',
            N'NumErrorLogs',
            @NumErrorLogs OUTPUT;
            INSERT INTO @Errorlogs EXEC sp_enumerrorlogs
            SELECT [num_errorlogs]=CASE WHEN @NumErrorLogs IS NOT NULL THEN @NumErrorLogs ELSE COUNT(*) END
	            ,[score]=CASE WHEN (CASE WHEN @NumErrorLogs IS NOT NULL THEN @NumErrorLogs ELSE COUNT(*) END) < 12 THEN 0 ELSE 1 END
            FROM @Errorlogs"
    Score = $null
}

$CisBenchmark += @{
    Name = "5.2 Ensure 'Default Trace Enabled' Server Configuration Option is set to '1' (Scored)"
    Test = "SELECT name,
            CAST(value as int) as value_configured,
            CAST(value_in_use as int) as value_in_use,
            [score]=CASE WHEN CAST(value as int)+CAST(value_in_use as int) = 2 THEN 1 ELSE 0 END
            FROM sys.configurations
            WHERE name = 'default trace enabled';"
    Score = $null
}

$CisBenchmark += @{
    Name = "5.3 Ensure 'Login Auditing' is set to 'failed logins' (Scored)"
    Test = "DECLARE @tbl TABLE ([name] NVARCHAR(128), [config_value] NVARCHAR(128))
            INSERT INTO @tbl EXEC xp_loginconfig 'audit level';
            SELECT [name], [config_value], [score]=CASE WHEN [config_value] IN ('all','failure') THEN 1 ELSE 0 END FROM @tbl"
    Score = $null
}

$CisBenchmark += @{
    Name = "5.4 Ensure 'SQL Server Audit' is set to capture both 'failed' and 'successful logins' (Scored)"
    Test = "SELECT [score]=CASE COUNT(*) WHEN 3 THEN 1 ELSE 0 END
            FROM sys.server_audit_specification_details AS SAD
            JOIN sys.server_audit_specifications AS SA
            ON SAD.server_specification_id = SA.server_specification_id
            JOIN sys.server_audits AS S
            ON SA.audit_guid = S.audit_guid
            WHERE SAD.audit_action_id IN ('CNAU', 'LGFL', 'LGSD')
	            AND S.is_state_enabled = 1
	            AND SA.is_state_enabled = 1"
    Score = $null
}

$CisBenchmark += @{
    Name = "6.1 Ensure Sanitize Database and Application User Input is Sanitized (Not Scored)"
    Test = $null
    Score = $null
}

$CisBenchmark += @{
    Name = "6.2 Ensure 'CLR Assembly Permission Set' is set to 'SAFE_ACCESS' for All CLR Assemblies (Scored)"
    Test = "SELECT [non_safe_access]=COUNT(*), [score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END
            FROM sys.assemblies
            where is_user_defined = 1
            AND permission_set_desc <> N'SAFE_ACCESS'"
    Score = $null
}

$CisBenchmark += @{
    Name = "7.1 Ensure 'Symmetric Key encryption algorithm' is set to 'AES_128' or higher in non-system databases (Scored)"
    Test = "DECLARE @tbl TABLE ([db] NVARCHAR(128), [key] NVARCHAR(128))
            INSERT INTO @tbl
            EXEC sp_MSforeachdb N'USE [?]; SELECT db_name() AS Database_Name, name AS Key_Name
            FROM sys.symmetric_keys
            WHERE algorithm_desc NOT IN (''AES_128'',''AES_192'',''AES_256'')
            AND db_id() > 4;'
            SELECT [weak_keys]=COUNT(*), [score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END FROM @tbl"
    Score = $null
}

$CisBenchmark += @{
    Name = "7.2 Ensure Asymmetric Key Size is set to 'greater than or equal to 2048' in non-system databases (Scored)"
    Test = "DECLARE @tbl TABLE ([db] NVARCHAR(128), [key] NVARCHAR(128))
            INSERT INTO @tbl
            EXEC sp_MSforeachdb N'USE [?]; SELECT db_name() AS Database_Name, name AS Key_Name
            FROM sys.asymmetric_keys
            WHERE key_length < 2048
            AND db_id() > 4;'
            SELECT [weak_keys]=COUNT(*), [score]=CASE COUNT(*) WHEN 0 THEN 1 ELSE 0 END FROM @tbl"
    Score = $null
}

$CisBenchmark += @{
    Name = "8.1 Ensure 'SQL Server Browser Service' is configured correctly (Not Scored)"
    Test = $null
    Score = $null
}

foreach ($Benchmark in $CisBenchmark) { 
    Write-Host $Benchmark.Name -BackgroundColor DarkGray

    if ($Benchmark.Test) {
        $rt = Invoke-Sqlcmd -ServerInstance $SqlServer -Database master -Query $Benchmark.Test

        if ($rt.Score -eq 0) { Write-Host " FAILED! " -BackgroundColor Red }

        $rt | Format-Table -AutoSize
        $Benchmark.Score = $rt.Score
    } else {
        Write-Host "`nNo audit command defined. Manual detection required.`n`n"
    }
}

$TotalAvailable = $CisBenchmark.Score.Where({$_ -ge 0}).Count
$TotalScore = ($CisBenchmark.Score | Measure-Object -Sum).Sum
$TotalFail = $CisBenchmark.Score.Where({$_ -eq 0}).Count
$NotScored = $CisBenchmark.Score.Where({$_ -eq $null}).Count

if ($TotalFail -eq 0) {
    Write-Host "`tTotal Score: $TotalScore\$TotalAvailable    Total Failed: $TotalFail    Not Scored: $NotScored    " -BackgroundColor Green
} 
elseif ($TotalFail -gt 0) {
    Write-Host "`tTotal Score: $TotalScore\$TotalAvailable    Total Failed: $TotalFail    Not Scored: $NotScored    " -BackgroundColor Red
}
