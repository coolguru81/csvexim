--sales from Rest of world
select 
SOH.OrderDate,
SOH.SalesOrderNumber,
SOH.PurchaseOrderNumber,
SOH.AccountNumber,
SOH.TotalDue
from AdventureWorks.Sales.SalesOrderHeader SOH
inner join AdventureWorks.Sales.SalesTerritory ST
on SOH.TerritoryID = ST.TerritoryID
inner join AdventureWorks.Person.CountryRegion CR
on ST.CountryRegionCode = CR.CountryRegionCode
where CR.[Name] <> 'United States'
and SOH.PurchaseOrderNumber is not null