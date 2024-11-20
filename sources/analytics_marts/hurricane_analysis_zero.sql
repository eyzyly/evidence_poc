With base_data as (
  SELECT 
        hurricane_year,
        max_severity,
        min(hurricane_startdtg) as first_appearance 
  FROM `cse-6242-fa24-lz.analytics_marts.dim_hurricane_attributes` 
  WHERE basin in ('AL') and max_severity=0
  GROUP by hurricane_year,max_severity
  order by hurricane_year desc, max_severity asc
),

create_hurricane_start as (
  SELECT
    *,
    DATE(EXTRACT(YEAR FROM hurricane_year), 6, 1) AS hurricane_year_start
  FROM base_data
),

calculate_days_since_start as (
  SELECT
    *,
    DATE_DIFF(DATE(first_appearance), hurricane_year_start, DAY) AS difference_in_days
  FROM create_hurricane_start
)

Select *
from calculate_days_since_start
order by max_severity asc