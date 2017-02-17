USE[master];
GO

SET NOCOUNT ON;

DECLARE @start_datetime DATETIME, @end_datetime DATETIME, @sanitize BIT, @mindate DATETIME, @loop INT, @lognum INT;
DECLARE @enumerrorlogs TABLE ([archive] INT, [date] DATETIME, [file_size_byte] BIGINT);
	
SET @start_datetime = DATEADD(DAY,-1,GETDATE());

IF OBJECT_ID('tempdb..#__Errorlog') IS NOT NULL
	DROP TABLE #__Errorlog;
IF OBJECT_ID('tempdb..#__SeverityError') IS NOT NULL
	DROP TABLE #__SeverityError;

CREATE TABLE #__Errorlog ([id] BIGINT IDENTITY(1,1) PRIMARY KEY, [log_date] DATETIME,[source] NVARCHAR(100),[message] NVARCHAR(MAX));
CREATE TABLE #__SeverityError ([id] BIGINT IDENTITY(1,1) PRIMARY KEY, [log_date] DATETIME, [source] NVARCHAR(100), [message_header] NVARCHAR(MAX), [message] NVARCHAR(MAX));

INSERT INTO @enumerrorlogs EXEC [master].[dbo].[xp_enumerrorlogs];
SELECT @lognum = MAX([archive]) FROM @enumerrorlogs;

IF (@end_datetime IS NULL)
	SET @end_datetime = GETDATE();

SET @mindate = GETDATE()
SET @loop = 0;
/* Insert error log messages */
WHILE (@loop <= @lognum)
BEGIN
	INSERT INTO #__Errorlog([log_date],[source],[message])
		EXEC [master].[dbo].[xp_readerrorlog] @loop, 1, NULL, NULL, @start_datetime, @end_datetime;

	IF (@@ROWCOUNT = 0)
	BEGIN
		BREAK;
	END

	SET @loop = @loop + 1;
END;

;WITH ErrorSet
AS
(
	SELECT [E].[id]
		,[E].[log_date]
		,[E].[source]
		,[E].[message]
	FROM #__Errorlog [E]
)
INSERT INTO #__SeverityError([log_date],[source],[message_header],[message])
	SELECT [A].[log_date]
		,CASE WHEN [B].[message] LIKE '%found % errors and repaired % errors%'
			THEN N'SQL Server'
			WHEN [B].[message] LIKE 'SQL Server has encountered%' 
			THEN N'SQL Server'
			ELSE [A].[source] END AS [source]
		,CASE WHEN [B].[message] LIKE '%found % errors and repaired % errors%'
			THEN N'ERROR:DBCC'
			WHEN [B].[message] LIKE 'SQL Server has encountered%' 
			THEN N'WARNING:Encountered'
			ELSE [A].[message] END AS [message_header]
		,[B].[message] AS [message]
	FROM ErrorSet [A]
		INNER JOIN ErrorSet [B]
			ON [A].[id]+1 = [B].[id]
	WHERE [A].[message] LIKE 'Error:%Severity:%State:%'
		OR ([B].[message] LIKE '%found % errors and repaired % errors%'
			AND [B].[message] NOT LIKE '%found 0 errors and repaired 0 errors%')
		OR [B].[message] LIKE 'SQL Server has encountered%'
	ORDER BY [A].[id] ASC;

SELECT [E].[log_date]
	,[E].[source]
	,[E].[message_header]
	,[E].[message]
FROM #__SeverityError [E]
ORDER BY [E].[log_date];