CREATE TABLE [dbo].[FedEx Ground Surcharges Domestic] (

	[Zone] bigint NULL, 
	[AHS_Dim] decimal(38,6) NULL, 
	[AHS_Dim_Disc] decimal(38,6) NULL, 
	[AHS_Weight] decimal(38,6) NULL, 
	[AHS_Weight_Disc] decimal(38,6) NULL, 
	[AHS_Packaging] decimal(38,6) NULL, 
	[AHS_Packaging_Disc] decimal(38,6) NULL, 
	[Oversize] decimal(38,6) NULL, 
	[Oversize_Disc] decimal(38,6) NULL
);