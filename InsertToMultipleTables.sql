/*    ==Scripting Parameters==

    Source Server Version : SQL Server 2012 (11.0.3156)
    Source Database Engine Edition : Microsoft SQL Server Enterprise Edition
    Source Database Engine Type : Standalone SQL Server

    Target Server Version : SQL Server 2012
    Target Database Engine Edition : Microsoft SQL Server Enterprise Edition
    Target Database Engine Type : Standalone SQL Server
*/

USE [General]
GO

/****** Object:  StoredProcedure [dbo].[STP_InsertToMultipleTables]    Script Date: 10/21/2017 4:40:10 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[STP_InsertToMultipleTables]
AS
	IF OBJECT_ID('Tempdb..#TempTableNames', 'U') IS NOT NULL 
			DROP TABLE #TempTableNames

		CREATE TABLE #TempTableNames (id INT IDENTITY (1,1),TbleName VARCHAR(50))
		INSERT INTO #TempTableNames (TbleName)
		SELECT DISTINCT TbleName
		FROM CustStaging

DECLARE @Name VARCHAR(50)
DECLARE @counter INT
DECLARE @insert NVARCHAR (500) 

	SET @counter=1
--Insert values 
			WHILE @counter is not null 
					BEGIN 
						SET @Name=(SELECT tbleName FROM #TempTableNames WHERE id=@counter)
						SET @insert='TRUNCATE TABLE ' +@Name+' insert into ['+@Name+'](CustomerID,CustomerName,DateofBirth,ISActive,virtualtour,TblName) 
						select Customerid,CustomerName,DateofBirth,isactive,virtualtour,TbleName  
						from CustStaging where TbleName='''+@Name+''''
					EXEC (@insert)
				DELETE FROM #TempTableNames WHERE id=@counter
				SET @counter=(SELECT MIN(id) FROM #TempTableNames)
			END 







GO


