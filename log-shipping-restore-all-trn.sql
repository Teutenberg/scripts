/*##  EXECUTE IN SQLCMD MODE  ##*/
/*##  NOTE: Transaction log files need to have datetime stamp in filename for correct ordering  ##*/
/* 
This script will try to restore all trn files in a directory. 
Use-case 1: Logshipping goes out-of-sync and you need to restore a large number of logs to re-sync.
Use-case 2: Restore a database from a previous nights full backup and rollforward all log backups.
*/

:SETVAR DB "db_name"
:SETVAR TRN_DIR "C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQL2014\MSSQL\Backup\"
:SETVAR FILTER "%.trn"


DECLARE @file_list TABLE ([file] NVARCHAR(256), [a] INT, [b] INT)
DECLARE @file_name NVARCHAR(256), @full_name NVARCHAR(512);

INSERT INTO @file_list
	EXEC xp_dirtree N'$(TRN_DIR)', 1, 1;

DECLARE File_Curse CURSOR FAST_FORWARD
FOR 
SELECT [file] 
FROM @file_list
WHERE [file] LIKE N'$(FILTER)'
ORDER BY [file]

OPEN File_Curse  
  
FETCH NEXT FROM File_Curse   
INTO @file_name

WHILE @@FETCH_STATUS = 0  
BEGIN 
	SET @full_name = REPLACE(N'$(TRN_DIR)' + N'\' + @file_name, N'\\', N'\');

	BEGIN TRY
		--RESTORE LOG [$(DB)] FROM DISK = @full_name WITH NORECOVERY;
		PRINT 'Restored file: ' + @file_name;
	END TRY
	BEGIN CATCH
		PRINT 'Skipping file: ' + @file_name;
	END CATCH

	FETCH NEXT FROM File_Curse   
	INTO @file_name
END   
CLOSE File_Curse;  
DEALLOCATE File_Curse; 
GO