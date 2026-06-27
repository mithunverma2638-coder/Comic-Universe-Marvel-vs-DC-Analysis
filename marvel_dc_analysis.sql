-- ============================================================
--  MARVEL & DC COMIC CHARACTERS — SQL ANALYSIS
--  Dataset: 23,272 characters | Source: Fivethirtyeight
--  Compatible with: PostgreSQL, MySQL 8+, SQLite, SQL Server
-- ============================================================

-- ============================================================
-- 0. TABLE SETUP (if importing from CSV)
-- ============================================================
CREATE TABLE IF NOT EXISTS comic_characters (
    page_id          INTEGER,
    name             VARCHAR(300),
    urlslug          VARCHAR(400),
    id_type          VARCHAR(100),       -- renamed from ID (reserved keyword)
    alignment        VARCHAR(100),       -- renamed from ALIGN
    eye_color        VARCHAR(100),       -- renamed from EYE
    hair_color       VARCHAR(100),       -- renamed from HAIR
    sex              VARCHAR(100),       -- renamed from SEX
    gsm              VARCHAR(100),
    alive_status     VARCHAR(100),       -- renamed from ALIVE
    appearances      INTEGER,
    first_appearance VARCHAR(20),
    year_introduced  INTEGER,            -- renamed from Year
    publisher        VARCHAR(50),
    year_alt         INTEGER             -- renamed from YEAR
);

-- ============================================================
-- 1. OVERVIEW — PUBLISHER BREAKDOWN
-- ============================================================
-- Total characters by publisher
SELECT
    publisher,
    COUNT(*)                                       AS total_characters,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_share
FROM comic_characters
GROUP BY publisher
ORDER BY total_characters DESC;

-- ============================================================
-- 2. ALIGNMENT ANALYSIS
-- ============================================================
-- Good vs Bad vs Neutral — overall
SELECT
    alignment,
    COUNT(*) AS character_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM comic_characters
WHERE alignment IS NOT NULL
GROUP BY alignment
ORDER BY character_count DESC;

-- Alignment breakdown by publisher
SELECT
    publisher,
    alignment,
    COUNT(*)  AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY publisher), 1) AS pct_within_publisher
FROM comic_characters
WHERE alignment IS NOT NULL
GROUP BY publisher, alignment
ORDER BY publisher, count DESC;

-- ============================================================
-- 3. GENDER & DIVERSITY
-- ============================================================
-- Gender distribution
SELECT
    sex,
    COUNT(*) AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM comic_characters
WHERE sex IS NOT NULL
GROUP BY sex
ORDER BY count DESC;

-- Male vs Female ratio per publisher
SELECT
    publisher,
    SUM(CASE WHEN sex = 'Male Characters'   THEN 1 ELSE 0 END) AS male_count,
    SUM(CASE WHEN sex = 'Female Characters' THEN 1 ELSE 0 END) AS female_count,
    ROUND(
        SUM(CASE WHEN sex = 'Female Characters' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(SUM(CASE WHEN sex IN ('Male Characters','Female Characters') THEN 1 ELSE 0 END), 0), 1
    ) AS female_pct
FROM comic_characters
GROUP BY publisher;

-- Gender × Alignment cross-tab
SELECT
    sex,
    alignment,
    COUNT(*) AS count
FROM comic_characters
WHERE sex IN ('Male Characters','Female Characters')
  AND alignment IS NOT NULL
GROUP BY sex, alignment
ORDER BY sex, count DESC;

-- ============================================================
-- 4. MORTALITY / SURVIVAL STATUS
-- ============================================================
SELECT
    alive_status,
    publisher,
    COUNT(*) AS count
FROM comic_characters
WHERE alive_status IS NOT NULL
GROUP BY alive_status, publisher
ORDER BY alive_status, count DESC;

-- Survival rate comparison by alignment
SELECT
    alignment,
    SUM(CASE WHEN alive_status = 'Living Characters'   THEN 1 ELSE 0 END) AS living,
    SUM(CASE WHEN alive_status = 'Deceased Characters' THEN 1 ELSE 0 END) AS deceased,
    ROUND(
        SUM(CASE WHEN alive_status = 'Living Characters' THEN 1 ELSE 0 END) * 100.0
        / NULLIF(COUNT(*), 0), 1
    ) AS survival_rate_pct
FROM comic_characters
WHERE alignment IS NOT NULL AND alive_status IS NOT NULL
GROUP BY alignment
ORDER BY survival_rate_pct DESC;

-- ============================================================
-- 5. APPEARANCES — POPULARITY METRICS
-- ============================================================
-- Top 25 most-appearing characters
SELECT
    name,
    publisher,
    alignment,
    year_introduced,
    appearances
FROM comic_characters
WHERE appearances IS NOT NULL AND appearances > 0
ORDER BY appearances DESC
LIMIT 25;

-- Average appearances by publisher and alignment
SELECT
    publisher,
    alignment,
    COUNT(*)                           AS character_count,
    ROUND(AVG(appearances), 1)         AS avg_appearances,
    MAX(appearances)                   AS max_appearances,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY appearances) AS median_appearances
FROM comic_characters
WHERE appearances IS NOT NULL AND appearances > 0
  AND alignment IS NOT NULL
GROUP BY publisher, alignment
ORDER BY publisher, avg_appearances DESC;

-- Distribution buckets
SELECT
    CASE
        WHEN appearances >= 1000 THEN 'Legend (1000+)'
        WHEN appearances >= 500  THEN 'Icon (500-999)'
        WHEN appearances >= 100  THEN 'Major (100-499)'
        WHEN appearances >= 25   THEN 'Regular (25-99)'
        WHEN appearances >= 5    THEN 'Minor (5-24)'
        ELSE 'Cameo (1-4)'
    END AS tier,
    COUNT(*) AS count
FROM comic_characters
WHERE appearances IS NOT NULL AND appearances > 0
GROUP BY 1
ORDER BY count DESC;

-- ============================================================
-- 6. CHRONOLOGICAL ANALYSIS — CHARACTER INTRODUCTION TRENDS
-- ============================================================
-- Characters introduced per decade
SELECT
    (year_introduced / 10) * 10 AS decade,
    publisher,
    COUNT(*)                     AS new_characters
FROM comic_characters
WHERE year_introduced > 0 AND year_introduced IS NOT NULL
GROUP BY decade, publisher
ORDER BY decade, publisher;

-- Cumulative characters over time (Marvel vs DC race)
SELECT
    year_introduced AS year,
    publisher,
    COUNT(*)                             AS new_in_year,
    SUM(COUNT(*)) OVER (
        PARTITION BY publisher
        ORDER BY year_introduced
        ROWS UNBOUNDED PRECEDING
    )                                    AS cumulative_total
FROM comic_characters
WHERE year_introduced > 0 AND year_introduced IS NOT NULL
GROUP BY year_introduced, publisher
ORDER BY year_introduced, publisher;

-- Golden/Silver/Bronze/Modern Age breakdown
SELECT
    publisher,
    CASE
        WHEN year_introduced BETWEEN 1938 AND 1956 THEN 'Golden Age (1938-1956)'
        WHEN year_introduced BETWEEN 1956 AND 1970 THEN 'Silver Age (1956-1970)'
        WHEN year_introduced BETWEEN 1970 AND 1985 THEN 'Bronze Age (1970-1985)'
        WHEN year_introduced BETWEEN 1985 AND 1999 THEN 'Dark/Modern Age (1985-1999)'
        WHEN year_introduced >= 2000              THEN 'Contemporary (2000+)'
        ELSE 'Unknown'
    END AS comic_age,
    COUNT(*) AS count
FROM comic_characters
WHERE year_introduced > 0
GROUP BY publisher, comic_age
ORDER BY publisher, count DESC;

-- ============================================================
-- 7. IDENTITY TYPE ANALYSIS
-- ============================================================
SELECT
    id_type,
    COUNT(*)                                       AS count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM comic_characters
WHERE id_type IS NOT NULL
GROUP BY id_type
ORDER BY count DESC;

-- Secret vs Public identity by publisher
SELECT
    publisher,
    id_type,
    COUNT(*) AS count
FROM comic_characters
WHERE id_type IN ('Secret Identity','Public Identity')
GROUP BY publisher, id_type
ORDER BY publisher, count DESC;

-- ============================================================
-- 8. PHYSICAL TRAITS
-- ============================================================
-- Top eye colors
SELECT
    eye_color,
    publisher,
    COUNT(*) AS count
FROM comic_characters
WHERE eye_color IS NOT NULL
GROUP BY eye_color, publisher
ORDER BY count DESC
LIMIT 30;

-- Top hair colors
SELECT
    hair_color,
    publisher,
    COUNT(*) AS count
FROM comic_characters
WHERE hair_color IS NOT NULL
GROUP BY hair_color, publisher
ORDER BY count DESC
LIMIT 30;

-- ============================================================
-- 9. COMPOUND ANALYSIS — VILLAIN PROFILES
-- ============================================================
-- Most prolific villains (bad characters, high appearances)
SELECT
    name,
    publisher,
    sex,
    eye_color,
    hair_color,
    year_introduced,
    appearances
FROM comic_characters
WHERE alignment = 'Bad Characters'
  AND appearances IS NOT NULL
ORDER BY appearances DESC
LIMIT 20;

-- Female hero leaders by publisher
SELECT
    name,
    publisher,
    alignment,
    year_introduced,
    appearances
FROM comic_characters
WHERE sex = 'Female Characters'
  AND alignment = 'Good Characters'
  AND appearances IS NOT NULL
ORDER BY appearances DESC
LIMIT 20;

-- ============================================================
-- 10. KEY PERFORMANCE INDICATORS (KPI SUMMARY VIEW)
-- ============================================================
SELECT
    'Total Characters'       AS metric, CAST(COUNT(*) AS VARCHAR) AS value FROM comic_characters
UNION ALL
SELECT 'Marvel Characters',   CAST(SUM(CASE WHEN publisher='Marvel' THEN 1 ELSE 0 END) AS VARCHAR) FROM comic_characters
UNION ALL
SELECT 'DC Characters',       CAST(SUM(CASE WHEN publisher='DC' THEN 1 ELSE 0 END) AS VARCHAR) FROM comic_characters
UNION ALL
SELECT 'Good Characters',     CAST(SUM(CASE WHEN alignment='Good Characters' THEN 1 ELSE 0 END) AS VARCHAR) FROM comic_characters
UNION ALL
SELECT 'Bad Characters',      CAST(SUM(CASE WHEN alignment='Bad Characters' THEN 1 ELSE 0 END) AS VARCHAR) FROM comic_characters
UNION ALL
SELECT 'Living Characters',   CAST(SUM(CASE WHEN alive_status='Living Characters' THEN 1 ELSE 0 END) AS VARCHAR) FROM comic_characters
UNION ALL
SELECT 'Female Characters',   CAST(SUM(CASE WHEN sex='Female Characters' THEN 1 ELSE 0 END) AS VARCHAR) FROM comic_characters
UNION ALL
SELECT 'Avg Appearances',     CAST(ROUND(AVG(NULLIF(appearances,0)), 1) AS VARCHAR) FROM comic_characters
UNION ALL
SELECT 'Highest Appearances', CAST(MAX(appearances) AS VARCHAR) FROM comic_characters
UNION ALL
SELECT 'Year Span',           CONCAT(CAST(MIN(NULLIF(year_introduced,0)) AS VARCHAR),' - ',CAST(MAX(year_introduced) AS VARCHAR)) FROM comic_characters;
