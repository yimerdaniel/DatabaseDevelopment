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

/****** Object:  StoredProcedure [dbo].[stp_InsertVirtualTours]    Script Date: 10/21/2017 2:12:22 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[stp_InsertVirtualTours]
	
AS
BEGIN


	insert	
	into	dbo.tbllistingextrafiles
		(mlsnumber, filetype, url)
	select	ztmls3236.mlsnumber, 4, _Virtual_Tour --4/1/2009, brothe: removed lower() ticket 31491
	from	ztmls3236 ztmls3236
		left join tbllistingextrafiles tbllistingextrafiles
			on ( tbllistingextrafiles.mlsnumber = ztmls3236.mlsnumber)
			and ( tbllistingextrafiles.filetype = 4 ) 			 
	where	_Virtual_Tour is not null
			and (tbllistingextrafiles.mlsnumber is null )
			

--4/1/2009, brothe: added from ticket 31491
	-- Update Changed VTours
	update tbllistingextrafiles
	set url = _Virtual_Tour
	from tbllistingextrafiles tbllistingextrafiles
		left join ztmls3236 ztmls3236
			on ( tbllistingextrafiles.mlsnumber = ztmls3236.mlsnumber)
			and ( tbllistingextrafiles.filetype = 4 ) 
			and (tbllistingextrafiles.insertuser = 'sql_agent')
			and url <> _Virtual_Tour
	where _Virtual_Tour is not null


	-- Update ExtraFilesCode
	update	ztmls3236
	set	extrafilescode = extrafilescode | 4
	where	(extrafilescode & 4 = 0) and
		(mlsnumber in (
			select	mlsnumber
			from	tbllistingextrafiles tbllistingextrafiles
			where	filetype = 4
		))

END











GO


