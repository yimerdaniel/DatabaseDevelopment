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

/****** Object:  StoredProcedure [dbo].[stp_BetterXlat]    Script Date: 10/21/2017 4:40:41 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE procedure [dbo].[stp_BetterXlat]
(
@MLSID int
)
AS
/******************************************************************************
** Desc:  
**        
**        
*******************************************************************************
**       Change History
**************************************
** Date:        Author:             Description:
** ----------   --------            ------------
** 9/15/2014	Sancrant			Inserts/Updates into ztmls from vewMLS...Fully replaces Xlat
** 12/24/2014	Sancrant			Added support for FieldLockCode = 1                                   
**
**
******************************************************************************/
BEGIN TRY
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

/*******************************************************************************************************************************************
                  __   ___   ___ ___   _   ___ _    ___ ___ 
                  \ \ / /_\ | _ \_ _| /_\ | _ ) |  | __/ __|
                   \ V / _ \|   /| | / _ \| _ \ |__| _|\__ \
                    \_/_/ \_\_|_\___/_/ \_\___/____|___|___/
*******************************************************************************************************************************************/
DECLARE  
  @TheDateTime		DATETIME
, @ColumnList		NVARCHAR(MAX)
, @Insert			NVARCHAR(MAX)
, @UpdateColumns	NVARCHAR(MAX)
, @UpdateBegin		NVARCHAR(MAX)
, @UpdateEnd		NVARCHAR(MAX)
, @UpdateComplete	NVARCHAR(MAX)
, @DBName			NVARCHAR(MAX)
, @InputParams		NVARCHAR(MAX)
, @varErrorNotesBACK nvarchar(MAX)
, @DBNameBACK		nvarchar(MAX)
, @SuccessMsgBACK	nvarchar(MAX)
, @MLSServer		nvarchar(1000)
, @ColumnListBACK	nvarchar(max)
, @GrabColumnList	nvarchar(max)
, @ColumnInputParam	nvarchar(max)
, @UpdateInputParam nvarchar(max)
, @UpdateColumnsBACK nvarchar(max)
, @GrabUpdateColumns nvarchar(max)
, @ManualListings	nvarchar(max)
, @GrabUpdateColumns_FL1 nvarchar(max)--FL1 = FieldLock = 1
, @UpdateBegin_FL1 nvarchar(max)--FL1 = FieldLock = 1
, @UpdateEnd_FL1 nvarchar(max)--FL1 = FieldLock = 1
, @UpdateComplete_FL1 nvarchar(max)--FL1 = FieldLock = 1
, @UpdateColumnsBACK_FL1 nvarchar(max)--FL1 = FieldLock = 1
, @UpdateColumns_FL1 nvarchar(max)--FL1 = FieldLock = 1
, @UpdateInputParam_FL1 nvarchar(max)

-- Error Handling vars

, @ProcedureName	SYSNAME        
, @ErrorMessage     NVARCHAR(4000) 
, @ErrorNumber      INT            
, @ErrorSeverity    INT            
, @ErrorState       INT            
, @ErrorLine        INT            
, @ErrorProcedure   NVARCHAR(200)
, @Msg				nvarchar(1000)
, @ServerCheck		varchar(50)
, @MLSDeviceName	varchar(50)
, @CurrentDeviceName varchar(50)  


--Set OUTPUT params------------------------------------------------------------------------------------------------------------------------------
Set @ColumnInputParam =	'
							@ColumnList			nvarchar(MAX) OUTPUT

						'

Set @UpdateInputParam =	'
							@UpdateColumns			nvarchar(MAX) OUTPUT
						'

Set @InputParams =	'
							@varErrorNotes	nvarchar(MAX) OUTPUT
					'

Set @UpdateInputParam_FL1 =	'
								@UpdateColumns_FL1			nvarchar(MAX) OUTPUT
							'
---------------------------------------------------------------------------------------------------------------------------------------------------

/*
Currently not in use. Might need these later on...saved just in case
Set @MLSDeviceName = 
(
select MLS.MLSServerName
from brokerdata.dbo.tblmls mls with(nolock)
join brokerdata.dbo.tblNetworkDeviceDns dns with(nolock)
on mls.mlsservername = dns.dnsname
And mls.MLSID = @MLSID
join brokerdata.dbo.tblNetworkDevice net with(nolock)
on dns.NetworkDeviceID = net.NetworkDeviceID
where net.DeviceName = SERVERPROPERTY('MachineName')
)

Set @MLSServer = (Select MLSServerName from brokerdata.dbo.tblMLS with(noLock) where MLSID = @MLSID)

*/

Set @DBName = (Select DBName from brokerdata.dbo.tblMLS with(noLock) where MLSID = @MLSID)
Set @ServerCheck = (Select Name from sys.databases with(nolock) where name = @DBName)

Set @CurrentDeviceName = 
(
select net.[Function] --Gets you the server alias
From brokerdata.dbo.tblNetworkDeviceDns dns with(nolock)
join brokerdata.dbo.tblnetworkdevice net with(nolock)
on dns.networkdeviceid = net.networkdeviceid
and PrimaryDNSFlag = 1
Where net.DeviceName = SERVERPROPERTY('MachineName')
)


If (@ServerCheck is null)
	Begin
		Set @Msg = ''+@DBName+' Does not live on '+@CurrentDeviceName+'. Please make sure you are using the proper MLS Server for the given MLSID.'
		RaisError(@Msg,16,-1);
	End


--Insert------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Set @GrabColumnList = 
'
Select @ColumnList = Isnull(@ColumnList,'''') + 
	'''' + MLS.Column_name +  '',''
	from	['+@DBName+'].INFORMATION_SCHEMA.COLUMNS mls with(nolock)
	Join	['+@DBName+'].INFORMATION_SCHEMA.COLUMNS vew with(nolock)
	on		mls.column_name	= vew.column_name
	AND		mls.TABLE_NAME	= ''ztmls'+cast(@MLSID as nvarchar(5))+'''
	AND		vew.TABLE_NAME = ''vewmls''
	Join	['+@DBName+'].dbo.tblMLSField Field with(nolock)
	On		mls.Column_Name = Field.MLSFieldName			
	order	by MLS.Column_name

set @ColumnList = LEFT(@ColumnList, LEN(@ColumnList) - 1)						

'

exec sp_executesql @GrabColumnList,@ColumnInputParam, @ColumnList = @ColumnListBACK OUTPUT

--Select @ColumnListBACK

Set @Insert = 
	'
	USE ['+@DBName+']

	Declare
		 @ProcedureName	SYSNAME        
		, @ErrorMessage     NVARCHAR(4000) 
		, @ErrorNumber      INT            
		, @ErrorSeverity    INT            
		, @ErrorState       INT            
		, @ErrorLine        INT            
		, @ErrorProcedure   NVARCHAR(200)
		, @DbName			varchar(50)

	Begin Try
	Insert Into ztmls'+cast(@MLSID as nvarchar(5))+'' + '('+@ColumnListBACK+')
	Select '+@ColumnListBACK+'
	From VewMLS v
	where not exists
	(
	select 1
	from ztmls'+cast(@MLSID as nvarchar(5))+'' + ' z with(nolock)
	where	v.MLSNumber = z.MLSNumber
	AND		v.ListingType = z.ListingType
	)
	End Try

	Begin Catch
		Select
		@ErrorNumber     = ERROR_NUMBER()
		, @ErrorSeverity  = ERROR_SEVERITY()
		, @ErrorState     = ERROR_STATE()
		, @ErrorLine      = ERROR_LINE()
		, @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), ''-'')
		, @ErrorMessage   = N''Message: ''+ ISNULL(ERROR_MESSAGE(), '''')
		;

-- should bubble the error and log it to a batch import table
      
		RAISERROR  -- Do this so we bubble out the error.  
			( @ErrorMessage
			, @ErrorSeverity 
			, 1               
			, @ErrorNumber     -- parameter: original error number.
			, @ErrorSeverity   -- parameter: original error severity.
			, @ErrorState      -- parameter: original error state.
			, @ErrorProcedure  -- parameter: original error procedure name.
			, @ErrorLine       -- parameter: original error line number.
			);
			
			Set @Dbname = DB_Name()
			
			Insert	tblError(PropType, MLSField, MLSValue, InsertDate, InsertUser, LastUpdateDate, LastUpdateUser)
			Select	Null, @DbName, @ErrorMessage,GetDate(),dbo.fn_GetUser(),GetDate(),dbo.fn_GetUser()

			Set @varErrorNotes = ISNULL('' ErrorMessage: '' + cast(ERROR_MESSAGE() as nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorLine: '' + Isnull( cast(ERROR_LINE() as nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorNumber: '' + Isnull( cast(ERROR_NUMBER() AS nvarchar(100))	,''Null'')  
			set	@varErrorNotes = @varErrorNotes + '', ErrorSeverity: '' +  Isnull( cast(ERROR_SEVERITY() AS nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorState: '' + Isnull( cast(ERROR_STATE() AS nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorProcedure: '' + Isnull( cast(ERROR_PROCEDURE() AS nvarchar(100))	,''Null'')
			Set @VarErrorNotes = @varErrorNotes + '', DataBaseName: '' + Isnull( cast(@DBname AS nvarchar(100))	,''Null'')

	End Catch
	'
--Testing sql structure
--select @Insert AS [processing-instruction(x)] FOR XML PATH('')

exec sp_executesql @Insert,@InputParams, @VarErrorNotes = @varErrorNotesBACK;


--Deactivate manual listings when the MLS version arrives-------------------------------------------------------------------------------------------------------------------

Set @ManualListings = 
'
USE ['+@DBName+']

Declare
		 @ProcedureName	SYSNAME        
		, @ErrorMessage     NVARCHAR(4000) 
		, @ErrorNumber      INT            
		, @ErrorSeverity    INT            
		, @ErrorState       INT            
		, @ErrorLine        INT            
		, @ErrorProcedure   NVARCHAR(200)
		, @DbName			varchar(50)

Begin Try
	Declare @ManualMLSNums Table
	(
	MLSNumber INT
	)

	Insert	@ManualMLSNums
	Select	Z.MLSNumber
	From	vewZTMLS Z
	Where	ListingType = 3
	AND		ListingStatus = 1
	AND		EXISTS
	(
	Select	1
	From	vewZTMLS Z2
	Where	ListingType = 0
	AND		ListingStatus = 1
	AND		Z.MLSNumber = Z2.MLSNumber
	)

	Update	ztmls' + cast(@MLSID as varchar(50)) + '
	Set		ListingStatus = 0
	Where	ListingType = 3
	AND		ListingStatus = 1
	AND		Exists
	(
	Select	1
	From	@ManualMLSNums M
	Where	M.MLSNumber = ztmls' + cast(@MLSID as varchar(50)) + '.MLSNumber
	)
End Try

Begin Catch
				Select
			@ErrorNumber     = ERROR_NUMBER()
			, @ErrorSeverity  = ERROR_SEVERITY()
			, @ErrorState     = ERROR_STATE()
			, @ErrorLine      = ERROR_LINE()
			, @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), ''-'')
			, @ErrorMessage   = N''Message: ''+ ISNULL(ERROR_MESSAGE(), '''')
			;

-- should bubble the error and log it to a batch import table
      
		RAISERROR  -- Do this so we bubble out the error.  
			( @ErrorMessage
			, @ErrorSeverity 
			, 1               
			, @ErrorNumber     -- parameter: original error number.
			, @ErrorSeverity   -- parameter: original error severity.
			, @ErrorState      -- parameter: original error state.
			, @ErrorProcedure  -- parameter: original error procedure name.
			, @ErrorLine       -- parameter: original error line number.
			);
			
			Set @DBname = DB_Name()
			
			Set @varErrorNotes = ISNULL('' ErrorMessage: '' + cast(ERROR_MESSAGE() as nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorLine: '' + Isnull( cast(ERROR_LINE() as nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorNumber: '' + Isnull( cast(ERROR_NUMBER() AS nvarchar(100))	,''Null'')  
			set	@varErrorNotes = @varErrorNotes + '', ErrorSeverity: '' +  Isnull( cast(ERROR_SEVERITY() AS nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorState: '' + Isnull( cast(ERROR_STATE() AS nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorProcedure: '' + Isnull( cast(ERROR_PROCEDURE() AS nvarchar(100))	,''Null'')
			Set @VarErrorNotes = @varErrorNotes + '', DataBaseName: '' + Isnull( cast(@DBname AS nvarchar(100))	,''Null'')

End Catch

'
--Testing Sql Structure
--Select @ManualListings AS [processing-instruction(x)] FOR XML PATH('')

exec sp_executesql @ManualListings, @InputParams, @VarErrorNotes = @varErrorNotesBACK;

--UPDATE; FieldLockCode != 1 (Do not overwrite PublicRemarks that were maually updated-idiotic business rule...This section updates all listings with a FieldLockCode != to 8)----------------------------- 

Set @GrabUpdateColumns = 
'
select @UpdateColumns  = Isnull(@UpdateColumns,'''') +  
	''zt.'' + mls.column_name +'' = ''+ ''vew.'' + vew.column_name +'',''
	from	['+@DBName+'].INFORMATION_SCHEMA.COLUMNS mls with(nolock)
	join	['+@DBName+'].INFORMATION_SCHEMA.COLUMNS vew with(nolock)
	on		mls.column_name = vew.column_name
	and		mls.TABLE_NAME = ''ztmls'+cast(@MLSID as nvarchar(5))+'''
	and		vew.TABLE_NAME = ''vewmls''
	Join	['+@DBName+'].dbo.tblMLSField Field with(nolock)
	On		mls.Column_Name = Field.MLSFieldName
	Where	mls.COLUMN_NAME != ''MLSNumber''
	And		mls.COLUMN_NAME != ''ListingType''
	order	by MLS.Column_name

Set @UpdateColumns = LEFT(@UpdateColumns, LEN(@UpdateColumns) - 1)						

' 
exec sp_executesql @GrabUpdateColumns,@UpdateInputParam, @UpdateColumns = @UpdateColumnsBACK OUTPUT

Set @UpdateBegin = 
	'
	USE ['+@DBName+']

	Declare
		 @ProcedureName	SYSNAME        
		, @ErrorMessage     NVARCHAR(4000) 
		, @ErrorNumber      INT            
		, @ErrorSeverity    INT            
		, @ErrorState       INT            
		, @ErrorLine        INT            
		, @ErrorProcedure   NVARCHAR(200)
		, @DbName			varchar(50)
		
	
	Begin Try

	;With CTE (MLSNumber)
	as
		(
			Select	MLSNumber
			From	VewActiveListings
			Where	FieldLockCode & 1 != 1
		)

	Update zt
	Set '+@UpdateColumnsBACK+'
	'
Set @UpdateEnd = 
	'From ztmls' + cast(@MLSID as varchar(50)) + ' zt
	Join vewMLS vew
	On zt.MLSNumber = vew.MLSNumber
	And zt.ListingType = vew.ListingType
	Join CTE C
	On vew.MLSNumber = C.MLSNumber
	Where zt.LastUpdateDate < vew.PMUpdateDate

	End Try

	Begin Catch
			Select
			@ErrorNumber     = ERROR_NUMBER()
			, @ErrorSeverity  = ERROR_SEVERITY()
			, @ErrorState     = ERROR_STATE()
			, @ErrorLine      = ERROR_LINE()
			, @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), ''-'')
			, @ErrorMessage   = N''Message: ''+ ISNULL(ERROR_MESSAGE(), '''')
			;

-- should bubble the error and log it to a batch import table
      
		RAISERROR  -- Do this so we bubble out the error.  
			( @ErrorMessage
			, @ErrorSeverity 
			, 1               
			, @ErrorNumber     -- parameter: original error number.
			, @ErrorSeverity   -- parameter: original error severity.
			, @ErrorState      -- parameter: original error state.
			, @ErrorProcedure  -- parameter: original error procedure name.
			, @ErrorLine       -- parameter: original error line number.
			);
			
			Set @DBname = DB_Name()
			
			Insert	tblError(PropType, MLSField, MLSValue, InsertDate, InsertUser, LastUpdateDate, LastUpdateUser)
			Select	Null, @DbName, @ErrorMessage,GetDate(),dbo.fn_GetUser(),GetDate(),dbo.fn_GetUser()

			Set @varErrorNotes = ISNULL('' ErrorMessage: '' + cast(ERROR_MESSAGE() as nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorLine: '' + Isnull( cast(ERROR_LINE() as nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorNumber: '' + Isnull( cast(ERROR_NUMBER() AS nvarchar(100))	,''Null'')  
			set	@varErrorNotes = @varErrorNotes + '', ErrorSeverity: '' +  Isnull( cast(ERROR_SEVERITY() AS nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorState: '' + Isnull( cast(ERROR_STATE() AS nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorProcedure: '' + Isnull( cast(ERROR_PROCEDURE() AS nvarchar(100))	,''Null'')
			Set @VarErrorNotes = @varErrorNotes + '', DataBaseName: '' + Isnull( cast(@DBname AS nvarchar(100))	,''Null'')

	End Catch
	'


--select @UpdateColumnsBACK AS [processing-instruction(x)] FOR XML PATH('')

Set @UpdateComplete = @UpdateBegin + @UpdateEnd

--Testing Sql Structure
--Select @UpdateComplete AS [processing-instruction(x)] FOR XML PATH('')

exec sp_executesql @UpdateComplete,@InputParams, @VarErrorNotes = @varErrorNotesBACK;

--UPDATE; FieldLockCode = 1 (Update everything BUT Public Remarks-idiotic business rule....)------------------------------------------------------------------------------------------- 

Set @GrabUpdateColumns_FL1 = 
'
select @UpdateColumns_FL1  = Isnull(@UpdateColumns_FL1,'''') +  
	''zt.'' + mls.column_name +'' = ''+ ''vew.'' + vew.column_name +'',''
	from	['+@DBName+'].INFORMATION_SCHEMA.COLUMNS mls with(nolock)
	join	['+@DBName+'].INFORMATION_SCHEMA.COLUMNS vew with(nolock)
	on		mls.column_name = vew.column_name
	and		mls.TABLE_NAME = ''ztmls'+cast(@MLSID as nvarchar(5))+'''
	and		vew.TABLE_NAME = ''vewmls''
	Join	['+@DBName+'].dbo.tblMLSField Field with(nolock)
	On		mls.Column_Name = Field.MLSFieldName
	Where	mls.COLUMN_NAME != ''MLSNumber''
	And		mls.COLUMN_NAME != ''ListingType''
	AND		MLS.COLUMN_NAME != ''PublicRemarks''
	order	by MLS.Column_name

Set @UpdateColumns_FL1 = LEFT(@UpdateColumns_FL1, LEN(@UpdateColumns_FL1) - 1)						

' 
exec sp_executesql @GrabUpdateColumns_FL1,@UpdateInputParam_FL1, @UpdateColumns_FL1 = @UpdateColumnsBACK_FL1 OUTPUT

Set @UpdateBegin_FL1 = 
	'
	USE ['+@DBName+']

	Declare
		 @ProcedureName	SYSNAME        
		, @ErrorMessage     NVARCHAR(4000) 
		, @ErrorNumber      INT            
		, @ErrorSeverity    INT            
		, @ErrorState       INT            
		, @ErrorLine        INT            
		, @ErrorProcedure   NVARCHAR(200)
		, @DbName			varchar(50)

	Begin Try

	;With CTE (MLSNumber)
	as
		(
			Select	MLSNumber
			From	VewActiveListings
			Where	FieldLockCode & 1 = 1
		)

	Update zt
	Set '+@UpdateColumnsBACK_FL1+'
	'
Set @UpdateEnd_FL1 = 
	'From ztmls' + cast(@MLSID as varchar(50)) + ' zt
	Join vewMLS vew
	On zt.MLSNumber = vew.MLSNumber
	And zt.ListingType = vew.ListingType
	Join CTE C
	On vew.MLSNumber = C.MLSNumber
	Where zt.LastUpdateDate < vew.PMUpdateDate

	End Try

	Begin Catch
			Select
			@ErrorNumber     = ERROR_NUMBER()
			, @ErrorSeverity  = ERROR_SEVERITY()
			, @ErrorState     = ERROR_STATE()
			, @ErrorLine      = ERROR_LINE()
			, @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), ''-'')
			, @ErrorMessage   = N''Message: ''+ ISNULL(ERROR_MESSAGE(), '''')
			;

-- should bubble the error and log it to a batch import table
      
		RAISERROR  -- Do this so we bubble out the error.  
			( @ErrorMessage
			, @ErrorSeverity 
			, 1               
			, @ErrorNumber     -- parameter: original error number.
			, @ErrorSeverity   -- parameter: original error severity.
			, @ErrorState      -- parameter: original error state.
			, @ErrorProcedure  -- parameter: original error procedure name.
			, @ErrorLine       -- parameter: original error line number.
			);
			
			Set @DBname = DB_Name()
			
			Insert	tblError(PropType, MLSField, MLSValue, InsertDate, InsertUser, LastUpdateDate, LastUpdateUser)
			Select	Null, @DbName, @ErrorMessage,GetDate(),dbo.fn_GetUser(),GetDate(),dbo.fn_GetUser()

			Set @varErrorNotes = ISNULL('' ErrorMessage: '' + cast(ERROR_MESSAGE() as nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorLine: '' + Isnull( cast(ERROR_LINE() as nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorNumber: '' + Isnull( cast(ERROR_NUMBER() AS nvarchar(100))	,''Null'')  
			set	@varErrorNotes = @varErrorNotes + '', ErrorSeverity: '' +  Isnull( cast(ERROR_SEVERITY() AS nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorState: '' + Isnull( cast(ERROR_STATE() AS nvarchar(100))	,''Null'')
			set @varErrorNotes = @varErrorNotes + '', ErrorProcedure: '' + Isnull( cast(ERROR_PROCEDURE() AS nvarchar(100))	,''Null'')
			Set @VarErrorNotes = @varErrorNotes + '', DataBaseName: '' + Isnull( cast(@DBname AS nvarchar(100))	,''Null'')

	End Catch
	'


--select @UpdateColumnsBACK_FL1 AS [processing-instruction(x)] FOR XML PATH('')

Set @UpdateComplete_FL1 = @UpdateBegin_FL1 + @UpdateEnd_FL1

--Testing Sql Structure
--Select @UpdateComplete_FL1 AS [processing-instruction(x)] FOR XML PATH('')

exec sp_executesql @UpdateComplete_FL1,@InputParams, @VarErrorNotes = @varErrorNotesBACK;


END TRY

Begin Catch

	If(@varErrorNotesBACK is null)
		Begin
			SELECT
				@ErrorNumber     = ERROR_NUMBER()
				, @ErrorSeverity  = ERROR_SEVERITY()
				, @ErrorState     = ERROR_STATE()
				, @ErrorLine      = ERROR_LINE()
				, @ErrorProcedure = ISNULL(ERROR_PROCEDURE(), '-')
				, @ErrorMessage   = N'Message: '+ ISNULL(ERROR_MESSAGE(), '')
				;
      
			RAISERROR  -- Do this so we bubble out the error.  
			( @ErrorMessage
			, @ErrorSeverity 
			, 1               
			, @ErrorNumber     -- parameter: original error number.
			, @ErrorSeverity   -- parameter: original error severity.
			, @ErrorState      -- parameter: original error state.
			, @ErrorProcedure  -- parameter: original error procedure name.
			, @ErrorLine       -- parameter: original error line number.
			);
		End
		Else
			RaisError(@varErrorNotesBACK,16,-1,'stp_BetterXlat');
			


End Catch



GO


