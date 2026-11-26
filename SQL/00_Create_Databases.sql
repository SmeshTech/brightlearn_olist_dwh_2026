-- BrightLearn Olist Data Warehouse 2026
-- Create the project databases when missing.
-- Run on a new SQL Server instance before the schema-only scripts.
USE [master];
GO

IF DB_ID(N'Olist_Staging') IS NULL
BEGIN
    CREATE DATABASE [Olist_Staging];
END;
GO

IF DB_ID(N'Olist_DWH') IS NULL
BEGIN
    CREATE DATABASE [Olist_DWH];
END;
GO

PRINT N'Olist databases exist (created if missing).';
GO
