/* Querying Coviddeaths Data Table with Ordered Output */
SELECT *
FROM Coviddeaths
ORDER BY location, date;

SELECT *
FROM Covidvaccination
ORDER BY location, date;

/* Create a New Result Set with Selected Columns and Ordered Output */
SELECT 
    location,
    date,
    total_cases,
    new_cases,
    total_deaths,
    population
FROM Coviddeaths
ORDER BY location, date;

/* Calculate Global Death Percentage */
SELECT 
    location,
    date,
    total_cases,
    total_deaths,
    (CAST(total_deaths AS FLOAT) / NULLIF(total_cases, 0)) * 100 AS DeathPercentage
FROM Coviddeaths
WHERE total_cases IS NOT NULL
ORDER BY location, date;

/* Aggregate Total Cases vs. Total Deaths for Africa */
SELECT 
    'Africa' AS Continent,
    SUM(total_cases) AS TotalCases,
    SUM(total_deaths) AS TotalDeaths,
    (SUM(total_deaths) / NULLIF(SUM(total_cases), 0)) * 100 AS DeathPercentage
FROM Coviddeaths
WHERE location = 'Africa';

/* Aggregate Total Cases vs. Population in Africa */
SELECT 
    'Africa' AS Continent,
    SUM(total_cases) AS TotalCases,
    SUM(population) AS TotalPopulation,
    (SUM(total_cases) / NULLIF(SUM(population), 0)) * 100 AS CasePercentage
FROM Coviddeaths
WHERE continent = 'Africa';

/* Identify Countries with the Highest Infection Rate Compared to Population */
SELECT 
    location,
    population,
    MAX(total_cases) AS HighestInfectionCount,
    MAX((CAST(total_cases AS FLOAT) / NULLIF(population, 0)) * 100) AS InfectionRatePercentage
FROM Coviddeaths
WHERE continent = 'Africa'
GROUP BY location, population
ORDER BY InfectionRatePercentage DESC;

/* Calculate Mortality Rate in Africa by Country */
SELECT 
    location,
    MAX(total_deaths) AS TotalDeathCount
FROM Coviddeaths
WHERE continent = 'Africa'
GROUP BY location
ORDER BY TotalDeathCount DESC;

/* Daily Death Count and New Case Aggregation for Africa */
SELECT 
    location,
    date,
    SUM(new_cases) AS TotalNewCases,
    SUM(total_deaths) AS TotalDeaths,
    CASE 
        WHEN SUM(total_cases) > 0 THEN (SUM(total_deaths) / NULLIF(SUM(total_cases), 0)) * 100 
        ELSE 0 
    END AS DeathPercentage
FROM Coviddeaths
WHERE continent = 'Africa'
GROUP BY location, date
ORDER BY location, date;

/* Total Vaccinations by Population in Africa */
SELECT 
    cd.location,
    cd.date,
    SUM(cd.new_cases) AS TotalCases,
    SUM(cd.total_deaths) AS TotalDeaths,
    CASE 
        WHEN SUM(cd.total_cases) > 0 THEN (SUM(cd.total_deaths) / NULLIF(SUM(cd.total_cases), 0)) * 100 
        ELSE 0 
    END AS DeathPercentage,
    SUM(CAST(cv.total_vaccinations AS INT)) AS TotalVaccinations
FROM Coviddeaths cd
JOIN Covidvaccination cv ON cd.location = cv.location AND cd.date = cv.date
WHERE cd.continent = 'Africa'
GROUP BY cd.location, cd.date
ORDER BY cd.location, cd.date;

/* Calculate New Vaccinations Per Day Using CTE and LAG Function */
WITH DailyVaccinations AS (
    SELECT 
        date,
        SUM(CAST(total_vaccinations AS INT)) AS TotalVaccinationsPerDay 
    FROM Covidvaccination
    GROUP BY date
)
SELECT 
    date,
    TotalVaccinationsPerDay - COALESCE(LAG(TotalVaccinationsPerDay) OVER (ORDER BY date), 0) AS NewVaccinationPerDay
FROM DailyVaccinations
ORDER BY date;

-- Create view with comprehensive data for visualization
CREATE VIEW CovidAfricaSummary AS
WITH DailyVaccinations AS (
    -- Calculate total vaccinations per day
    SELECT 
        date,
        SUM(CAST(total_vaccinations AS INT)) AS TotalVaccinationsPerDay 
    FROM Covidvaccination
    GROUP BY date
),
VaccinationData AS (
    -- Calculate new vaccinations per day
    SELECT 
        date,
        TotalVaccinationsPerDay,
        TotalVaccinationsPerDay - COALESCE(LAG(TotalVaccinationsPerDay) OVER (ORDER BY date), 0) AS NewVaccinationPerDay
    FROM DailyVaccinations
),
CovidData AS (
    -- Aggregate COVID-19 data by location and date for Africa
    SELECT 
        cd.location,
        cd.date,
        SUM(cd.total_cases) AS TotalCases,
        SUM(cd.new_cases) AS NewCases,
        SUM(cd.total_deaths) AS TotalDeaths,
        SUM(cd.population) AS Population,
        CASE 
            WHEN SUM(cd.total_cases) > 0 THEN (SUM(cd.total_deaths) / NULLIF(SUM(cd.total_cases), 0)) * 100 
            ELSE 0 
        END AS DeathPercentage
    FROM Coviddeaths cd
    WHERE cd.continent = 'Africa'
    GROUP BY cd.location, cd.date
)
-- Join CovidData with VaccinationData on date for daily summary
SELECT 
    cd.location,
    cd.date,
    cd.TotalCases,
    cd.NewCases,
    cd.TotalDeaths,
    cd.Population,
    cd.DeathPercentage,
    vd.TotalVaccinationsPerDay,
    vd.NewVaccinationPerDay
FROM CovidData cd
LEFT JOIN VaccinationData vd ON cd.date = vd.date
ORDER BY cd.location, cd.date;


SELECT * FROM CovidAfricaSummary;
