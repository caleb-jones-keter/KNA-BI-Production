CREATE TABLE [dbo].[DIM USA CA Zips] (

	[POSTAL_CODE] varchar(8000) NULL, 
	[REGION] varchar(8000) NULL, 
	[LATITUDE] float NULL, 
	[LONGITUDE] float NULL, 
	[Postal Code Clean] varchar(8000) NULL, 
	[City List] varchar(8000) NULL, 
	[Distance from DHL] bigint NULL, 
	[Distance from SpreeTail Vegas] bigint NULL, 
	[Distance from SpreeTail Nanticoke] bigint NULL
);