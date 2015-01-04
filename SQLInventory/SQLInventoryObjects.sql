/**************************************
Author: Michael S. Fal (http://www.mikefal.net)
Finalized: 2012-04-16

Creates server inventory SQL objects.  Should be created in 
an administrative database ([MSFAdmin]).

***************************************/

IF NOT EXISTS (SELECT 1 from sys.databases WHERE name = 'MSFADMIN')
	CREATE DATABASE [MSFADMIN];
go

USE [MSFADMIN];
go

if exists (select * from sys.tables where name = 'MachineInventory')
 drop table [dbo].[MachineInventory];

CREATE TABLE [dbo].[MachineInventory](
	[ServerName] [varchar](200) NOT NULL,
	[Model] [varchar](100) NULL,
	[Manufacturer] [varchar](100) NULL,
	[Architechture] [varchar](10) NULL,
	[PhysicalCPUS] [int] NULL,
	[LogicalCPUS] [int] NULL,
	[MaxSpeed] [int] NULL,
	[Memory] [int] NULL,
	[OSName] [varchar](100) NULL,
	[OSVersion] [varchar](100) NULL,
	[OSEdition] [varchar](100) NULL,
	[SPVersion] [varchar](10) NULL,
	[Cluster] [varchar](100) NULL,
	[LastModified] [smalldatetime] DEFAULT GETDATE(),
	[LastModifiedUser] [sysname],
 CONSTRAINT [PK_Server] PRIMARY KEY CLUSTERED ([ServerName])
);

if exists (select * from sys.tables where name = 'InstanceInventory') 
	drop table [dbo].[InstanceInventory];

CREATE TABLE [dbo].[InstanceInventory](
	[ServerName] [varchar](200) NOT NULL,
	[InstanceName] [varchar](200) NOT NULL,
	[SQLName]  AS (case when [InstanceName] IS NULL then [ServerName] else ([ServerName]+'\')+[InstanceName] end),
	[SQLVersion] [varchar](20) NULL,
	[SQLVersionDesc] [varchar](20) NULL,
	[SQLEdition] [varchar](50) NULL,
	[IP] [varchar](20) NULL,
	[Port] [int] NULL,
	[MemoryMinMB] [int] NULL,
	[MemoryMaxMB] [int] NULL,
	[MAXDOPVal] [int] NULL,
	[LastModified] [smalldatetime] NULL DEFAULT GETDATE(),
	[LastModifiedUser] [sysname] NOT NULL DEFAULT SYSTEM_USER,
 CONSTRAINT [PK_Instance] PRIMARY KEY CLUSTERED ([ServerName],[InstanceName])
);
go

--	create schema dataload;
go

if exists (select * from sys.tables where name = 'MachineLoad')
 drop table [dataload].[MachineLoad];

CREATE TABLE [dataload].[MachineLoad](
	[ServerName] [varchar](200) NOT NULL,
	[Model] [varchar](100) NULL,
	[Manufacturer] [varchar](100) NULL,
	[Architechture] [varchar](10) NULL,
	[PhysicalCPUS] [int] NULL,
	[LogicalCPUS] [int] NULL,
	[MaxSpeed] [int] NULL,
	[Memory] [int] NULL,
	[OSName] [varchar](100) NULL,
	[OSVersion] [varchar](100) NULL,
	[SPVersion] [varchar](10) NULL,
	[Cluster] [varchar](20) NULL
);

if exists (select * from sys.tables where name = 'InstanceLoad')
 drop table [dataload].[InstanceLoad];

CREATE TABLE [dataload].[InstanceLoad](
	[ServerName] [varchar](200) NOT NULL,
	[InstanceName] [varchar](200) NOT NULL,
	[SQLVersion] [varchar](20) NULL,
	[SQLVersionDesc] [varchar](20) NULL,
	[SQLEdition] [varchar](50) NULL,
	[IP] [varchar](20) NULL,
	[Port] [varchar](100) NULL,
	[MemoryMinMB] [varchar](100) NULL,
	[MemoryMaxMB] [varchar](100) NULL,
	[MAXDOPVal] [varchar](100) NULL,
	[PhysicalHost] [varchar](100) NULL
);

GO

if exists (select * from sys.procedures where name = 'dbasp_ProcessInventory')
 drop procedure dbasp_ProcessInventory;
go

create procedure dbasp_ProcessInventory
as
begin
/**************************************
Author: Michael S. Fal (http://www.mikefal.net)
Finalized: 2012-04-16

Pulls data from inventory staging tables and loads it
into live reporting tables.  Instance inventory is 
updated, machine inventory is deleted and reloaded.

***************************************/

MERGE INTO [dbo].[InstanceInventory] as [Target]
USING  [dataload].[InstanceLoad] as [Source]
ON [Target].[ServerName] = [Source].[ServerName] 
	and [Target].[InstanceName] = [Source].[InstanceName]
WHEN MATCHED THEN
UPDATE
set
	SQLVersion = [Source].SQlVersion
	,SQLVersionDesc = CASE WHEN [Source].SQLVersion like '12%' then 'SQL 2014 '
						WHEN [Source].SQLVersion like '11%' then 'SQL 2012 '
						WHEN [Source].SQLVersion like '10.50%' then 'SQL 2008 R2 '
						WHEN [Source].SQLVersion like '10.0%' then 'SQL 2008 '
						WHEN [Source].SQLVersion like '9%' then 'SQL 2005 '
						WHEN [Source].SQLVersion like '8%' then 'SQL 2000 ' END + [Source].SQLVersionDesc
	,SQLEdition = [Source].SQLEdition
	,IP = [Source].IP
	,Port = [Source].Port
	,MemoryMinMB = [Source].MemoryMinMB
	,MemoryMaxMB = [Source].MemoryMaxMB
	,MAXDOPVal = [Source].MAXDOPVal
	,LastModified = GETDATE()
	,LastModifiedUser = SYSTEM_USER
WHEN NOT MATCHED BY TARGET THEN
INSERT ([ServerName] 
	,[InstanceName]
	,[SQLVersion]
	,[SQLVersionDesc]
	,[SQLEdition]
	,[IP]
	,[Port]
	,[MemoryMinMB]
	,[MemoryMaxMB]
	,[MAXDOPVal])
VALUES([Source].[ServerName]
	,[Source].[InstanceName]
	,[Source].SQlVersion
	,CASE WHEN [Source].SQLVersion like '12%' then 'SQL 2014 '
		WHEN [Source].SQLVersion like '11%' then 'SQL 2012 '
		WHEN [Source].SQLVersion like '10.50%' then 'SQL 2008 R2 '
		WHEN [Source].SQLVersion like '10.0%' then 'SQL 2008 '
		WHEN [Source].SQLVersion like '9%' then 'SQL 2005 '
		WHEN [Source].SQLVersion like '8%' then 'SQL 2000 ' END + [Source].SQLVersionDesc
	,[Source].SQLEdition
	,[Source].IP
	,[Source].Port
	,[Source].MemoryMinMB
	,[Source].MemoryMaxMB
	,[Source].MAXDOPVal);


delete from MachineInventory
where ServerName in (select ServerName from dataload.MachineLoad)

insert into MachineInventory(ServerName,
					Model,
					Manufacturer,
					Architechture,
					PhysicalCPUS,
					LogicalCPUS,
					MaxSpeed,
					Memory,
					OSName,
					OSVersion,
					OSEdition,
					SPVersion,
					Cluster,
					LastModified,
					LastModifiedUser)
select
	Upper(ServerName),
	Model,
	Manufacturer,
	Architechture,
	PhysicalCPUS,
	case when LogicalCPUS = 0 then PhysicalCPUs else LogicalCPUS end,
	MaxSpeed,
	Memory,
	OSName,
	OSVersion,
	OSName,
	SPVersion,
	Cluster,
	getdate(),
	SYSTEM_USER
from
	dataload.MachineLoad
end; --dbasp_ProcessInventory