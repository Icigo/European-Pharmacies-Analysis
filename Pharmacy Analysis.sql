
SELECT * from dim_date;
SELECT * FROM dim_pharmacy;
SELECT * FROM dim_product;
SELECT * FROM fact_Sales;

-- 1. How do revenue, units sold, and margin change over time, and are there clear seasonal patterns?

WITH cte AS (
SELECT d.MonthNumber, d.MonthName, d.Year, SUM(s.RevenueEUR) AS total_revenue, SUM(s.UnitsSold) AS total_unit_sold, SUM(s.MarginEUR) AS total_margin,
CASE 
	WHEN d.MonthNumber IN (12, 1, 2) THEN 'Winter'
	WHEN d.MonthNumber IN (3, 4, 5) THEN 'Spring'
	WHEN d.MonthNumber IN (6, 7, 8) THEN 'Summer'
	WHEN d.MonthNumber IN (9, 10, 11) THEN 'Fall'
END AS season, ROW_NUMBER() OVER(PARTITION BY d.Year ORDER BY d.MonthNumber) AS rn
FROM fact_Sales s
JOIN dim_date d ON s.DateKey = d.DateKey
GROUP BY d.MonthNumber, d.MonthName, d.Year
)
SELECT season, SUM(total_revenue) AS revenue, SUM(total_unit_sold) AS units_sold, SUM(total_margin) AS margin
FROM cte
GROUP BY season;


-- 2. Which countries and regions contribute the most to total revenue and margin?

SELECT p.Country, p.Region, SUM(s.RevenueEUR) AS total_revenue, SUM(s.MarginEUR) AS total_margin
FROM fact_Sales s
JOIN dim_pharmacy p ON s.PharmacyID = p.PharmacyID
GROUP BY p.Country, p.Region
ORDER BY 1;


-- 3. How does performance vary when drilling down from country → region → pharmacy?

SELECT p.Country, p.Region, p.PharmacyName, 
SUM(s.RevenueEUR) AS total_revenue, SUM(s.UnitsSold) AS total_units_sold, SUM(s.MarginEUR) AS total_margin
FROM fact_Sales s
JOIN dim_pharmacy p ON s.PharmacyID = p.PharmacyID
GROUP BY p.Country, p.Region, p.PharmacyName;


-- 4. Which pharmacies outperform or underperform compared to others in the same region?

SELECT p.Region, p.PharmacyName, 
SUM(s.RevenueEUR) AS total_revenue, ROW_NUMBER() OVER(PARTITION BY p.Region ORDER BY SUM(s.RevenueEUR) DESC) AS revenue_rank,
SUM(s.UnitsSold) AS total_units_sold, ROW_NUMBER() OVER(PARTITION BY p.Region ORDER BY SUM(s.UnitsSold) DESC) AS unit_sold_rank,
SUM(s.MarginEUR) AS total_margin, ROW_NUMBER() OVER(PARTITION BY p.Region ORDER BY SUM(s.MarginEUR) DESC) AS margin_rank
FROM fact_Sales s
JOIN dim_pharmacy p ON s.PharmacyID = p.PharmacyID
GROUP BY p.Region, p.PharmacyName;


-- 5. How do Urban, Suburban, and Rural pharmacies differ in sales volume and profitability?

SELECT p.PharmacyType, SUM(s.UnitsSold) AS sales_volume, SUM(s.MarginEUR) AS profitability
FROM fact_Sales s
JOIN dim_pharmacy p ON s.PharmacyID = p.PharmacyID
GROUP BY p.PharmacyType;


-- 6. Which product categories and brands generate the most revenue, and which generate the most margin?

SELECT Category, Brand, total_revenue, total_margin
FROM (
	SELECT p.Category, p.Brand, 
	SUM(s.RevenueEUR) AS total_revenue, ROW_NUMBER() OVER(PARTITION BY p.Category ORDER BY SUM(s.RevenueEUR) DESC) AS revenue_rank,
	SUM(s.MarginEUR) AS total_margin, ROW_NUMBER() OVER(PARTITION BY p.Category ORDER BY SUM(s.MarginEUR) DESC) AS margin_rank 
	FROM fact_Sales s
	JOIN dim_product p ON s.ProductID = p.ProductID
	GROUP BY p.Category, p.Brand
) U
WHERE revenue_rank = 1 AND margin_rank = 1;


-- 7. Are there products with high volume but low margin, or low volume but high margin?

SELECT *
FROM (
	SELECT p.ProductName, SUM(s.UnitsSold) AS total_volume, ROW_NUMBER() OVER(ORDER BY SUM(s.UnitsSold) DESC) AS volume_rank,
	SUM(s.MarginEUR) AS total_margin, ROW_NUMBER() OVER(ORDER BY SUM(s.MarginEUR) DESC) AS margin_rank
	FROM fact_Sales s
	JOIN dim_product p ON s.ProductID = p.ProductID
	GROUP BY p.ProductName
) T
WHERE volume_rank = 1 OR margin_rank = 1;


-- 8. How do promoted sales compare to non-promoted sales in terms of volume and margin?

SELECT CASE WHEN PromoFlag = 1 THEN 'Promoted' ELSE 'Non-Promoted' END AS promotion_sales, 
SUM(UnitsSold) AS total_volume, SUM(MarginEUR) AS total_margin
FROM fact_Sales
GROUP BY CASE WHEN PromoFlag = 1 THEN 'Promoted' ELSE 'Non-Promoted' END;


-- 9. How does regional performance contribute to overall business results?

SELECT p.Region, SUM(s.RevenueEUR) AS total_revenue, SUM(s.UnitsSold) AS total_units_sold, SUM(s.MarginEUR) AS total_margin
FROM fact_Sales s
JOIN dim_pharmacy p ON s.PharmacyID = p.PharmacyID
GROUP BY p.Region;


-- 10. Are there visible geographic patterns in sales or profitability ?

SELECT p.Country, SUM(s.RevenueEUR) AS total_sales, SUM(s.MarginEUR) AS profitability
FROM fact_Sales s
JOIN dim_pharmacy p ON s.PharmacyID = p.PharmacyID
GROUP BY p.Country
ORDER BY 2 DESC;

-- 11. Which products are more likely to be sold with a promotion?

SELECT p.ProductName, SUM(s.UnitsSold) AS total_unit_sold
FROM fact_Sales s
JOIN dim_product p ON s.ProductID = p.ProductID AND s.PromoFlag = 1
GROUP BY p.ProductName
ORDER BY 2 DESC;


-- 12. Which pharmacy runs the most promotions?

SELECT p.PharmacyName, SUM(CASE WHEN PromoFlag = 1 THEN 1 END) AS promoted_sales_count,
SUM(CASE WHEN PromoFlag = 0 THEN 1 END) AS non_promoted_sales_count
FROM fact_Sales s
JOIN dim_pharmacy p ON s.PharmacyID = p.PharmacyID
GROUP BY p.PharmacyName;
