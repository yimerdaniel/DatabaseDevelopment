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

/****** Object:  StoredProcedure [dbo].[stp_Imprev_VirtualTours]    Script Date: 10/21/2017 4:34:37 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[stp_Imprev_VirtualTours]
as


/*
Drop temp tables if still exist
*/
IF OBJECT_ID('tempdb.dbo.#tblImprevVT', 'U') IS NOT NULL
BEGIN
	DROP TABLE #tblImprevVT
END


IF OBJECT_ID('tempdb.dbo.#tblMLSBoxes', 'U') IS NOT NULL
BEGIN
	DROP TABLE #tblMLSBoxes
END



/*
Create temp table to insert initial staging data into. Also adding server info (join to brokerdata..tblmls)
*/
CREATE TABLE #tblImprevVT (MLSPrefix VARCHAR (5), MLSNumber VARCHAR(50), URL VARCHAR (500), ExtraFilesCode INT, MlSBox VARCHAR (100), DBName VARCHAR (50), MLSID INT)

/*
Create temp table to insert distinct mls boxes and databases
*/
CREATE TABLE #tblMLSBoxes (ID INT Identity(1,1) NOT NULL,MLSBox VARCHAR(100),DBName VARCHAR(100),MLSID INT)


/*
INSERT STAGING DATA INTO TEMP
*/
INSERT INTO #tblImprevVT
SELECT dts.mlsprefix,dts.MLSNumber,dts.URL,dts.ExtraFilesCode,tbl.MLsServerName,tbl.DBName,tbl.MLSID
FROM tblDTS_VirtualTour_Imprev dts join brokerdata..tblmls (NOLOCK) tbl
ON dts.MLSPrefix=tbl.MLSPrefix
WHERE TBL.ACTIVEFLAG=1

--REMOVE ONCE LIVE
and tbl.DBName IN ('fl-bonitaspringsmls2','fl-regionalmls2')

--SELECT * FROM #tblImprevVT

/*
INSERT MLS SERVER AND DATABASE INFO FROM STAGING TEMP TABLE.
*/
INSERT INTO #tblMLSBoxes
SELECT DISTINCT MLSBOX, DBNAME, MLSID
FROM #tblImprevVT
ORDER BY MLSBOX

--SELECT * FROM #tblMLSBoxes


/*
Loop through distinct MLS databases and insert/update/delete data in/from tbllistingextrafiles.
Also updates extrafilescode in ztmls
*/

DECLARE @MLSBox VARCHAR(100)
DECLARE @DBName VARCHAR(100)
DECLARE @MLSID VARCHAR(100)
DECLARE @IDCounter INT
DECLARE @InsertSQL VARCHAR(8000)
DECLARE @UpdateSQL VARCHAR(8000)
DECLARE @DeleteSQL VARCHAR(8000)

SET @IDCounter = 1


WHILE @IDCounter IS NOT NULL

	BEGIN
		
		SET @MLSBox = (SELECT MLSBox FROM #tblMLSBoxes WHERE ID = @IDCounter)
		SET @DBName = (SELECT DBName FROM #tblMLSBoxes WHERE ID = @IDCounter)
		SET @MLSID = (SELECT MLSID FROM #tblMLSBoxes WHERE ID = @IDCounter)
		
		
		SET @InsertSQL = 'INSERT INTO [' + @MLSBox + '].[' + @DBName + '].dbo.tbllistingextrafiles_temp (MLSNumber,FileType,URL)
					SELECT ztmls.MLSNumber,temp.ExtraFilesCode,temp.URL
					FROM #tblImprevVT temp
					JOIN [' + @MLSBox + '].[' + @DBName + '].dbo.ztmls' + @MLSID + ' ztmls 
					ON ztmls.MLSNumberAlpha = temp.MLSNumber
					WHERE temp.URL <> ''''
					AND ztmls.MLSNumber NOT IN (
						SELECT MLSNumber FROM [' + @MLSBox + '].[' + @DBName + '].dbo.tbllistingextrafiles_temp
						WHERE temp.Extrafilescode = tbllistingextrafiles_temp.FileType
					)'
		
		--SELECT (@InsertSQL)   BREAK
		EXEC (@InsertSQL)
		
		
		SET @UpdateSQL = 'UPDATE [' + @MLSBox + '].[' + @DBName + '].dbo.tbllistingextrafiles_temp
						SET efc.URL = temp.URL
						FROM [' + @MLSBox + '].[' + @DBName + '].dbo.tbllistingextrafiles_temp efc
						JOIN [' + @MLSBox + '].[' + @DBName + '].dbo.ztmls' + @MLSID + ' ztmls 
						ON ztmls.MLSNumber = efc.MLSNumber 
						JOIN #tblImprevVT temp
						ON ztmls.MLSNumberAlpha = CAST(temp.MLSNumber as VARCHAR(100))
						WHERE temp.URL <> ''''
						AND temp.URL <> efc.URL
						AND efc.FileType = temp.ExtraFilesCode'
		
		--SELECT (@UpdateSQL)  BREAK
		EXEC (@UpdateSQL)
		
		
		SET @DeleteSQL = 'DELETE FROM efc FROM [' + @MLSBox + '].[' + @DBName + '].dbo.tbllistingextrafiles_temp efc
						  JOIN [' + @MLSBox + '].[' + @DBName + '].dbo.ztmls' + @MLSID + ' ztmls 
						  ON ztmls.MLSNumber = efc.MLSNumber 
						  JOIN #tblImprevVT temp
						  ON ztmls.MLSNumberAlpha = CAST(temp.MLSNumber as VARCHAR(100))
						  WHERE temp.URL = ''''
						  AND temp.ExtraFilesCode = efc.FileType'
						
		--SELECT (@DeleteSQL)  BREAK
		EXEC (@DeleteSQL)
		
		
		
		/*
		TODO: UPDATE ExtraFilesCode in ZTMLS
		*/
		
		
		
		DELETE FROM #tblMLSBoxes WHERE ID = @IDCounter
		
		SET @IDCounter = (SELECT MIN(ID) FROM #tblMLSBoxes)
	END
	
	
	/*
	Drop temp tables
	*/
	DROP TABLE #tblImprevVT
	DROP TABLE #tblMLSBoxes

GO


