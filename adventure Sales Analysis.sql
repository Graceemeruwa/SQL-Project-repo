-- Creating a fact table for sales transactions

CREATE VIEW FactSales AS
SELECT 
    soh.SalesOrderID,
    soh.OrderDate,
    soh.CustomerID,
    soh.TotalDue AS OrderTotal,
    sd.ProductID,
    sd.OrderQty,
    sd.UnitPrice,
    sd.LineTotal AS Revenue
FROM Sales.SalesOrderHeader AS soh
JOIN Sales.SalesOrderDetail AS sd 
    ON soh.SalesOrderID = sd.SalesOrderID;

	-- Creating a dimension for products
go
CREATE VIEW DimProduct AS
SELECT 
    p.ProductID,
    p.Name AS ProductName,
    ps.Name AS SubcategoryName,
    pc.Name AS CategoryName
FROM Production.Product AS p
JOIN Production.ProductSubcategory AS ps 
    ON p.ProductSubcategoryID = ps.ProductSubcategoryID
JOIN Production.ProductCategory AS pc 
    ON ps.ProductCategoryID = pc.ProductCategoryID;


	-- Creating a dimension for customers
go
CREATE VIEW DimCustomerssss AS
SELECT 
    c.CustomerID,
    COALESCE(pp.FirstName, '') + ' ' + COALESCE(pp.LastName, '') AS FullName,
    CASE 
        WHEN DATEDIFF(YEAR, he.BirthDate, GETDATE()) < 25 THEN 'Under 25'
        WHEN DATEDIFF(YEAR, he.BirthDate, GETDATE()) BETWEEN 25 AND 34 THEN '25-34'
        WHEN DATEDIFF(YEAR, he.BirthDate, GETDATE()) BETWEEN 35 AND 44 THEN '35-44'
        WHEN DATEDIFF(YEAR, he.BirthDate, GETDATE()) BETWEEN 45 AND 54 THEN '45-54'
        ELSE '55+'
    END AS AgeGroup,
    sp.Name,
    sp.StateProvinceCode AS StateCode,
    sp.CountryRegionCode AS CountryCode
FROM Sales.Customer AS c
LEFT JOIN HumanResources.Employee AS he 
    ON c.PersonID = he.BusinessEntityID
LEFT JOIN Person.StateProvince AS sp 
    ON c.TerritoryID = sp.TerritoryID
left join Person.Person AS pp 
    ON pp.BusinessEntityID = he.BusinessEntityID;

select * from DimCustomerssss
-- Creating a date dimension from the FactSales table
go
CREATE VIEW DimDate AS
SELECT DISTINCT
    CAST(OrderDate AS DATE) AS OrderDate,
    YEAR(OrderDate) AS OrderYear,
    MONTH(OrderDate) AS OrderMonth,
    DATENAME(MONTH, OrderDate) AS MonthName
FROM FactSales;


-- Monthly sales revenue by product category
SELECT 
    d.OrderYear,
    d.OrderMonth,
    dp.CategoryName,
    SUM(fs.Revenue) AS MonthlyRevenue
FROM FactSales AS fs
JOIN DimDate AS d ON fs.OrderDate = d.OrderDate
JOIN DimProduct AS dp ON fs.ProductID = dp.ProductID
GROUP BY 
    d.OrderYear,
    d.OrderMonth,
    dp.CategoryName
ORDER BY 
    d.OrderYear,
    d.OrderMonth,
    MonthlyRevenue DESC;


-- Customer demographics by product category
SELECT 
    dp.CategoryName,
    dc.AgeGroup,
    COUNT(DISTINCT fs.CustomerID) AS CustomerCount
FROM FactSales AS fs
JOIN DimProduct AS dp ON fs.ProductID = dp.ProductID
JOIN DimCustomer AS dc ON fs.CustomerID = dc.CustomerID
GROUP BY 
    dp.CategoryName,
    dc.AgeGroup
ORDER BY 
    dp.CategoryName,
    dc.AgeGroup;


-- Monthly growth in sales revenue by product category
WITH MonthlyRevenue AS (
    SELECT 
        d.OrderYear,
        d.OrderMonth,
        dp.CategoryName,
        SUM(fs.Revenue) AS MonthlyRevenue
    FROM FactSales AS fs
    JOIN DimDate AS d ON fs.OrderDate = d.OrderDate
    JOIN DimProduct AS dp ON fs.ProductID = dp.ProductID
    GROUP BY 
        d.OrderYear,
        d.OrderMonth,
        dp.CategoryName
)

SELECT 
    CategoryName,
    OrderYear,
    OrderMonth,
    MonthlyRevenue,
    LAG(MonthlyRevenue) OVER (PARTITION BY CategoryName ORDER BY OrderYear, OrderMonth) AS PreviousMonthRevenue,
    CASE 
        WHEN LAG(MonthlyRevenue) OVER (PARTITION BY CategoryName ORDER BY OrderYear, OrderMonth) IS NULL THEN 0
        ELSE (MonthlyRevenue - LAG(MonthlyRevenue) OVER (PARTITION BY CategoryName ORDER BY OrderYear, OrderMonth)) / 
             LAG(MonthlyRevenue) OVER (PARTITION BY CategoryName ORDER BY OrderYear, OrderMonth) * 100
    END AS GrowthPercentage
FROM MonthlyRevenue
ORDER BY CategoryName, OrderYear, OrderMonth;
