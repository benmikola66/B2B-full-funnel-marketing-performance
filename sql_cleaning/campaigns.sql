SELECT * FROM dbo.abm_accounts;


--create staging table--
SELECT *
INTO campaigns_stg
FROM dbo.campaigns;


SELECT * FROM dbo.campaigns_stg;