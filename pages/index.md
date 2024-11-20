---
title: Storming the Market - How Hurricane Patterns Supercharged Our HD Trading Strategy
---

## TL;DR
- We looked at price trends for Home Improvement stocks (Home Depot, Lowes) during Hurricane Season (June 1 - Nov 30) for the last 10 years
- A naive buy and sell strategy for HD outperformed SPY in the last 10 hurricane seasons 
- Leveraging hurricane data and adjusting the buy time based on a 3 year rolling average of category 0 hurricanes outperforms this baseline

## Story So Far
- Constraint: HD stock only, sell only on Nov 30
- Parameter: What day should I buy? 
- Brought in hurricane characteristics which include year, region, severity, start and end period  (333 rows)    
- Learned the hurricane pattern
- Our initial strategy is based on the assumption that hurricane season in the Atlantic region starts June 1st and ends Nov 30th and this aligns with category 0 hurricanes first appearing beginning end of May/early June. The first category 1 hurricanes occur on average 42 days after the start of hurricane season whereas category 2 hurricanes and higher first appear 81 days after the start of hurricane season.
- New Strategy: Would investing 40 days later or 80 days later to align with the first appearances of category 1 or 2 hurricanes increase our return? 
- Tried to time investment based on cat 1/cat 2 hurricane timing. results were not better than baseline
- Noticed cat 0 is happening earlier than june 1st (by 2-5 days)
- What if we adjust the buy period based on the first appearance of category 0 hurricanes?
- use last 3 years of history and buy based on the delta. Call this 3 year rolling avg hurricane start
- Using the new hurricane_start dates, evaluate the performance of the model against baseline
- Using the rolling_avg returns better results than baseline based on 7 years of data across all metrics (average return, median return, std deviation, sharpe ratio)

## Intro

Over the past decade (2014-2023), we analyzed stock price trends for Home Depot (HD) and evaluated a baseline trading strategy: buying HD stock on June 1st and selling on November 30th to align with Atlantic hurricane season. This approach consistently outperformed the S&P 500 (SPY) in the same period. 

```sql stock_prices_hurricane
  select
      *
  from analytics_marts.stock_prices
  WHERE EXTRACT(MONTH FROM trading_date) BETWEEN 6 AND 11
```

<LineChart
    data={stock_prices_hurricane}
    title="Stock prices during Hurricane Season 2014-2023"
    x=trading_date
    y={['adj_close_hd','adj_close_low','adj_close_spyx']} 
/>

```sql stock_prices_hurricane_annual_returns
  WITH stock_prices AS (
  SELECT 
    trading_date,
    EXTRACT(YEAR FROM trading_date) AS year,
    adj_close_hd,
    adj_close_low,
    adj_close_spyx
  FROM analytics_marts.stock_prices
  WHERE (EXTRACT(MONTH FROM trading_date) = 6 AND EXTRACT(DAY FROM trading_date) = 1)
     OR (EXTRACT(MONTH FROM trading_date) = 11 AND EXTRACT(DAY FROM trading_date) = 30)
)

SELECT 
  year,
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_hd END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 6 THEN adj_close_hd END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 6 THEN adj_close_hd END) * 100 AS hd_percentage_change,
  
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_low END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 6 THEN adj_close_low END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 6 THEN adj_close_low END) * 100  AS low_percentage_change,
  
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_spyx END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 6 THEN adj_close_spyx END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 6 THEN adj_close_spyx END) * 100  AS spyx_percentage_change
FROM stock_prices
where year between 2014 and 2023
GROUP BY year
ORDER BY year desc
```
<DataTable data={stock_prices_hurricane_annual_returns}/>

```sql baseline_compounded_return

Select *
FROM analytics_marts.baseline_compounded_return

```
<DataTable data={baseline_compounded_return}/>

Motivated by this, we investigated whether incorporating hurricane telemetry (hurricane severity and occurrences)—could enhance returns further. The goal was to determine an optimal buy time for HD stock while maintaining the constraint of selling only on November 30th. 

## Cyclone Stats

We analyzed 333 hurricanes between 2014-2023. 2020 had the most hurricane with 47 events, 30 of which were category 0 which represent tropical storms. Hurricanes typically last between 8-9 days while tropical storms last for less than 5 days.

```sql hurricanes_by_year
  Select
    hurricane_year,
    max_severity,
    count(*) as hurricane_counts
  FROM analytics_marts.hurricane_attributes
  group by hurricane_year,max_severity
  
```

<BarChart
    data={hurricanes_by_year}
    x=hurricane_year
    y=hurricane_counts
    series=max_severity
/>

```sql average_hurricane_duration_by_severity
  Select
    max_severity,
     AVG(EXTRACT(EPOCH FROM (hurricane_enddtg - hurricane_startdtg)) / 3600) / 24 AS avg_duration
  FROM analytics_marts.hurricane_attributes
  group by max_severity
  order by max_severity asc
  
```

<BarChart
    data={average_hurricane_duration_by_severity}
    x=max_severity
    y=avg_duration
    series=max_severity
/>

## Modelling A Hurricane Season

With an idea of how often and how long hurricanes occur in a season, we wanted to understand the timing of different hurricane severity within a season.

```sql hurricane_start_analysis
  Select
    *
  FROM analytics_marts.hurricane_start_analysis
```

```sql hurricane_start_aggregate
  Select
    max_severity,
    count(difference_in_days) as total_count,
    avg(difference_in_days) as avg_difference
  FROM ${hurricane_start_analysis}
  group by max_severity
```

<DataTable data={hurricane_start_aggregate}/>

```sql use_weighted_approach

WITH hurricane_data AS (
  SELECT
    hurricane_year,
    max_severity,
    difference_in_days,
    EXTRACT(YEAR FROM hurricane_year) AS year_numeric
  FROM ${hurricane_start_analysis}
),
weighted_data AS (
  SELECT
    max_severity,
    difference_in_days,
    year_numeric,
    1.0 / (EXTRACT(YEAR FROM CURRENT_DATE) - year_numeric + 1) AS weight -- Example weight calculation
  FROM hurricane_data
)
SELECT
  max_severity,
  SUM(difference_in_days * weight) / SUM(weight) AS weighted_avg_difference_in_days
FROM weighted_data
GROUP BY max_severity
ORDER BY max_severity ASC


```

Our initial strategy is based on the assumption that hurricane season in the Atlantic region starts June 1st and ends Nov 30th and this aligns with category 0 hurricanes first appearing beginning end of May/early June. The first category 1 hurricanes occur on average 42 days after the start of hurricane season whereas category 2 hurricanes and higher first appear 81 days after the start of hurricane season.

## Hypothesis 1: Would investing 40 days later or 80 days later to align with the first appearances of category 1 or 2 hurricanes increase our return? 

### Strategy 1: Invest 40 days into hurricane season (July 14)

```sql stock_prices_hurricane_annual_returns_july_14
  WITH stock_prices AS (
  SELECT 
    trading_date,
    EXTRACT(YEAR FROM trading_date) AS year,
    adj_close_hd,
    adj_close_low,
    adj_close_spyx
  FROM analytics_marts.stock_prices
  WHERE (EXTRACT(MONTH FROM trading_date) = 7 AND EXTRACT(DAY FROM trading_date) = 14)
     OR (EXTRACT(MONTH FROM trading_date) = 11 AND EXTRACT(DAY FROM trading_date) = 30)
),
yearly_returns AS (
  SELECT 
    year,
    -- Calculate yearly return for adj_close_hd
    (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_hd END) 
     - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 7 THEN adj_close_hd END)) 
     / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 7 THEN adj_close_hd END) AS hd_yearly_return,
    
    -- Calculate yearly return for adj_close_low
    (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_low END) 
     - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 7 THEN adj_close_low END)) 
     / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 7 THEN adj_close_low END) AS low_yearly_return,
    
    -- Calculate yearly return for adj_close_spyx
    (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_spyx END) 
     - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 7 THEN adj_close_spyx END)) 
     / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 7 THEN adj_close_spyx END) AS spyx_yearly_return
  FROM stock_prices
  GROUP BY year
)
SELECT
  -- Cumulative returns with reinvestment logic
  EXP(SUM(LOG(1 + hd_yearly_return))) - 1 AS hd_cumulative_return,
  EXP(SUM(LOG(1 + low_yearly_return))) - 1 AS low_cumulative_return,
  EXP(SUM(LOG(1 + spyx_yearly_return))) - 1 AS spyx_cumulative_return
FROM yearly_returns

```

<DataTable data={stock_prices_hurricane_annual_returns_july_14}/>

### Strategy 2: Invest 80 days into hurricane season (August 20)

```sql stock_prices_hurricane_annual_returns_aug_20
  WITH stock_prices AS (
  SELECT 
    trading_date,
    EXTRACT(YEAR FROM trading_date) AS year,
    adj_close_hd,
    adj_close_low,
    adj_close_spyx
  FROM analytics_marts.stock_prices
  WHERE (EXTRACT(MONTH FROM trading_date) = 8 AND EXTRACT(DAY FROM trading_date) = 20)
     OR (EXTRACT(MONTH FROM trading_date) = 11 AND EXTRACT(DAY FROM trading_date) = 30)
),
yearly_returns AS (
  SELECT 
    year,
    -- Calculate yearly return for adj_close_hd
    (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_hd END) 
     - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 8 THEN adj_close_hd END)) 
     / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 8 THEN adj_close_hd END) AS hd_yearly_return,
    
    -- Calculate yearly return for adj_close_low
    (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_low END) 
     - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 8 THEN adj_close_low END)) 
     / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 8 THEN adj_close_low END) AS low_yearly_return,
    
    -- Calculate yearly return for adj_close_spyx
    (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_spyx END) 
     - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 8 THEN adj_close_spyx END)) 
     / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 8 THEN adj_close_spyx END) AS spyx_yearly_return
  FROM stock_prices
  GROUP BY year
)
SELECT
  -- Cumulative returns with reinvestment logic
  EXP(SUM(LOG(1 + hd_yearly_return))) - 1 AS hd_cumulative_return,
  EXP(SUM(LOG(1 + low_yearly_return))) - 1 AS low_cumulative_return,
  EXP(SUM(LOG(1 + spyx_yearly_return))) - 1 AS spyx_cumulative_return
FROM yearly_returns
```

<DataTable data={stock_prices_hurricane_annual_returns_aug_20}/>

Based on the results, this approach is not yielding a good return. 


## What's Next?
- [Connect your data sources](settings)
- Edit/add markdown files in the `pages` folder
- Deploy your project with [Evidence Cloud](https://evidence.dev/cloud)

## Get Support
- Message us on [Slack](https://slack.evidence.dev/)
- Read the [Docs](https://docs.evidence.dev/)
- Open an issue on [Github](https://github.com/evidence-dev/evidence)
