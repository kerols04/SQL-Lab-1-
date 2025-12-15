USE [everyloop];



/* =========================
   Uppgift 1
   ========================= */
IF OBJECT_ID('dbo.SuccessfulMissions', 'U') IS NOT NULL
    DROP TABLE dbo.SuccessfulMissions;

SELECT
    [Spacecraft],
    [Launch date],
    [Carrier rocket],
    [Operator],
    [Mission type]
INTO dbo.SuccessfulMissions
FROM dbo.MoonMissions
WHERE [Outcome] LIKE 'Successful%';

GO



/* =========================
   Uppgift 2
   ========================= */
UPDATE dbo.SuccessfulMissions
SET [Operator] = LTRIM(RTRIM([Operator]));

GO



/* =========================
   Uppgift 3
   ========================= */
SELECT
    [Operator],
    [Mission type],
    COUNT(*) AS [Mission count]
FROM dbo.SuccessfulMissions
GROUP BY
    [Operator],
    [Mission type]
HAVING COUNT(*) > 1
ORDER BY
    [Operator],
    [Mission type];

GO



/* =========================
   Uppgift 4 (VG)
   Ta bort parentes + innehåll: "Pioneer 0 (Able I)" -> "Pioneer 0"
   ========================= */
UPDATE dbo.SuccessfulMissions
SET [Spacecraft] =
    CASE
        WHEN CHARINDEX('(', [Spacecraft]) > 0
            THEN RTRIM(LEFT([Spacecraft], CHARINDEX('(', [Spacecraft]) - 1))
        ELSE [Spacecraft]
    END;

GO



/* =========================
   Uppgift 5
   NewUsers: alla kolumner (förutom att FirstName+LastName blir Name)
   + Gender baserat på näst sista siffran i personnumret
   ========================= */
IF OBJECT_ID('dbo.NewUsers', 'U') IS NOT NULL
    DROP TABLE dbo.NewUsers;

SELECT
    u.[ID],
    CAST(u.[UserName] AS nvarchar(8)) AS [UserName],
    u.[Password],
    u.[Email],
    u.[Phone],
    CONCAT(u.[FirstName], ' ', u.[LastName]) AS [Name],
    CASE
        WHEN TRY_CONVERT(int,
             SUBSTRING(
                REPLACE(REPLACE(u.[ID], '-', ''), '+', ''),
                LEN(REPLACE(REPLACE(u.[ID], '-', ''), '+', '')) - 1,
                1
             )
        ) % 2 = 0 THEN 'Female'
        ELSE 'Male'
    END AS [Gender]
INTO dbo.NewUsers
FROM dbo.[Users] AS u;

GO



/* =========================
   Uppgift 6
   UserName som inte är unika + antal dubbletter
   ========================= */
SELECT
    [UserName],
    COUNT(*) AS [DuplicateCount]
FROM dbo.NewUsers
GROUP BY [UserName]
HAVING COUNT(*) > 1
ORDER BY [DuplicateCount] DESC, [UserName];

GO



/* =========================
   Uppgift 7
   Gör alla UserName unika (utan att överskrida nvarchar(8))
   Vi behåller första, och för duplicates sätter vi:
   LEFT(UserName,3) + sista 3 siffror från personnumret (ID) -> 8 tecken
   ========================= */
;WITH d AS
(
    SELECT
        nu.[ID],
        nu.[UserName],
        ROW_NUMBER() OVER (PARTITION BY nu.[UserName] ORDER BY nu.[ID]) AS rn
    FROM dbo.NewUsers AS nu
)
UPDATE d
SET [UserName] =
    CONCAT(
        LEFT([UserName], 3),
        RIGHT(REPLACE(REPLACE([ID], '-', ''), '+', ''), 3)
    )
WHERE rn > 1;

GO



/* =========================
   Uppgift 8
   Ta bort alla kvinnor födda före 1970
   ========================= */
;WITH p AS
(
    SELECT
        nu.[ID],
        nu.[Gender],
        REPLACE(REPLACE(nu.[ID], '-', ''), '+', '') AS CleanID,
        CASE WHEN nu.[ID] LIKE '%+%' THEN 1 ELSE 0 END AS HasPlus
    FROM dbo.NewUsers AS nu
),
y AS
(
    SELECT
        p.*,
        TRY_CONVERT(int, SUBSTRING(p.CleanID, 1, 2)) AS YY
    FROM p
),
birthyear AS
(
    SELECT
        y.[ID],
        y.[Gender],
        CASE
            WHEN y.YY IS NULL THEN NULL
            WHEN y.HasPlus = 1 THEN 1900 + y.YY
            WHEN y.YY > (YEAR(GETDATE()) % 100) THEN 1900 + y.YY
            ELSE 2000 + y.YY
        END AS BirthYear
    FROM y
)
DELETE nu
FROM dbo.NewUsers AS nu
JOIN birthyear AS b
  ON b.[ID] = nu.[ID]
WHERE b.[Gender] = 'Female'
  AND b.BirthYear IS NOT NULL
  AND b.BirthYear < 1970;

GO



/* =========================
   Uppgift 9
   Lägg till en ny användare i NewUsers
   (välj ett UserName som är 8 tecken och inte krockar)
   ========================= */
INSERT INTO dbo.NewUsers
(
    [ID],
    [UserName],
    [Password],
    [Email],
    [Phone],
    [Name],
    [Gender]
)
VALUES
(
    '990101-1234',
    'Kerols04',
    'password',
    'Kerols04@example.com',
    '0700000000',
    'Kerols Abdalla',
    CASE
        WHEN (TRY_CONVERT(int, SUBSTRING('9901011234', LEN('9901011234') - 1, 1)) % 2) = 0 THEN 'Female'
        ELSE 'Male'
    END
);

GO



/* =========================
   Uppgift 10 (VG)
   Returnera: gender + average age (2 rader)
   ========================= */
;WITH p AS
(
    SELECT
        nu.[Gender],
        REPLACE(REPLACE(nu.[ID], '-', ''), '+', '') AS CleanID,
        CASE WHEN nu.[ID] LIKE '%+%' THEN 1 ELSE 0 END AS HasPlus
    FROM dbo.NewUsers AS nu
),
d AS
(
    SELECT
        p.[Gender],
        TRY_CONVERT(int, SUBSTRING(p.CleanID, 1, 2)) AS YY,
        TRY_CONVERT(int, SUBSTRING(p.CleanID, 3, 2)) AS MM,
        TRY_CONVERT(int, SUBSTRING(p.CleanID, 5, 2)) AS DD,
        p.HasPlus
    FROM p
),
birth AS
(
    SELECT
        d.[Gender],
        CASE
            WHEN d.YY IS NULL OR d.MM IS NULL OR d.DD IS NULL THEN NULL
            ELSE DATEFROMPARTS(
                CASE
                    WHEN d.HasPlus = 1 THEN 1900 + d.YY
                    WHEN d.YY > (YEAR(GETDATE()) % 100) THEN 1900 + d.YY
                    ELSE 2000 + d.YY
                END,
                d.MM,
                d.DD
            )
        END AS BirthDate
    FROM d
),
ages AS
(
    SELECT
        [Gender],
        CASE
            WHEN BirthDate IS NULL THEN NULL
            ELSE
                DATEDIFF(YEAR, BirthDate, GETDATE())
                - CASE
                    WHEN DATEADD(YEAR, DATEDIFF(YEAR, BirthDate, GETDATE()), BirthDate) > GETDATE()
                        THEN 1
                    ELSE 0
                  END
        END AS AgeYears
    FROM birth
)
SELECT
    [Gender] AS [gender],
    AVG(CAST(AgeYears AS float)) AS [average age]
FROM ages
WHERE AgeYears IS NOT NULL
GROUP BY [Gender]
ORDER BY [gender];

GO
