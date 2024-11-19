---
title: Can you make money with Hurricanes?
---

<Details title='How to edit this page'>

  This page can be found in your project at `/pages/index.md`. Make a change to the markdown file and save it to see the change take effect in your browser.
</Details>

```sql categories
  select
      category
  from needful_things.orders
  group by category
```

<Dropdown data={categories} name=category value=category>
    <DropdownOption value="%" valueLabel="All Categories"/>
</Dropdown>

<Dropdown name=year>
    <DropdownOption value=% valueLabel="All Years"/>
    <DropdownOption value=2019/>
    <DropdownOption value=2020/>
    <DropdownOption value=2021/>
</Dropdown>

## Story so far?
- Visualize stock price trends for last 10 years
- Evaluate simple trading strategy where you would buy asset for June 1st and sell Nov 30
- Learned that HD outperformed SPY between June 1st and Nov 30
- Goal: Can we do better than this by leveraging hurricane data?
- Constraint: HD stock only, sell only on Nov 30
- Parameter: What day should I buy? 
- Brought in hurricane characteristics which include year, region, severity, start and end period  (333 rows)    
- Learned the hurricane pattern
- Tried to time investment based on cat 1/cat 2 hurricane timing. results aren't good
- Noticed cat 0 is happening earlier than june 1st (by 2-5 days)
- Adjusting buy based on cat 0 is close to baseline strategy
- What if we create a trading strategy based on cat 0. use last 3 years of history and buy based on the delta
- Pick a buy date
- Evaluate result

```sql orders_by_category
  select 
      date_trunc('month', order_datetime) as month,
      sum(sales) as sales_usd,
      category
  from needful_things.orders
  where category like '${inputs.category.value}'
  and date_part('year', order_datetime) like '${inputs.year.value}'
  group by all
  order by sales_usd desc
```

<BarChart
    data={orders_by_category}
    title="Sales by Month, {inputs.category.label}"
    x=month
    y=sales_usd
    series=category
/>

```sql stock_prices_all
  select
      *
  from analytics_marts.stock_prices
```

<LineChart
    data={stock_prices_all}
    title="Stock prices from 2014-2023"
    x=trading_date
    y={['adj_close_hd','adj_close_low','adj_close_spyx']} 
/>

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

```sql hurricane_start_analysis
  Select
    *
  FROM analytics_marts.hurricane_start_analysis
```

<DataTable data={hurricane_start_analysis}/>

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

## Findings
Our initial strategy is based on the assumption that hurricane season in the Atlantic region starts June 1st and ends Nov 30th and this aligns with category 0 hurricanes first appearing beginning end of May/early June. The first category 1 hurricanes occur on average 42 days after the start of hurricane season whereas category 2 hurricanes and higher first appear 81 days after the start of hurricane season.

## New Strategy: Would investing 40 days later or 80 days later to align with the first appearances of category 1 or 2 hurricanes increase our return? 

Strategy 1: Invest 40 days into hurricane season (July 14)

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
)

SELECT 
  year,
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_hd END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 7 THEN adj_close_hd END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 7 THEN adj_close_hd END) * 100 AS hd_percentage_change,
  
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_low END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 7 THEN adj_close_low END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 7 THEN adj_close_low END) * 100  AS low_percentage_change,
  
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_spyx END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 7 THEN adj_close_spyx END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 7 THEN adj_close_spyx END) * 100  AS spyx_percentage_change
FROM stock_prices
where year between 2014 and 2023
GROUP BY year
ORDER BY year desc
```

<DataTable data={stock_prices_hurricane_annual_returns_july_14}/>

Strategy 2: Invest 80 days into hurricane season (August 20)

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
)

SELECT 
  year,
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_hd END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 8 THEN adj_close_hd END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 8 THEN adj_close_hd END) * 100 AS hd_percentage_change,
  
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_low END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 8 THEN adj_close_low END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 8 THEN adj_close_low END) * 100  AS low_percentage_change,
  
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_spyx END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 8 THEN adj_close_spyx END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 8 THEN adj_close_spyx END) * 100  AS spyx_percentage_change
FROM stock_prices
where year between 2014 and 2023
GROUP BY year
ORDER BY year desc
```

<DataTable data={stock_prices_hurricane_annual_returns_aug_20}/>

Strategy 3: Invest 5 days earlier into hurricane season (May 27)

```sql stock_prices_hurricane_annual_returns_may_27
  WITH stock_prices AS (
  SELECT 
    trading_date,
    EXTRACT(YEAR FROM trading_date) AS year,
    adj_close_hd,
    adj_close_low,
    adj_close_spyx
  FROM analytics_marts.stock_prices
  WHERE (EXTRACT(MONTH FROM trading_date) = 5 AND EXTRACT(DAY FROM trading_date) = 27)
     OR (EXTRACT(MONTH FROM trading_date) = 11 AND EXTRACT(DAY FROM trading_date) = 30)
)

SELECT 
  year,
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_hd END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 5 THEN adj_close_hd END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 5 THEN adj_close_hd END) * 100 AS hd_percentage_change,
  
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_low END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 5 THEN adj_close_low END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 5 THEN adj_close_low END) * 100  AS low_percentage_change,
  
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_spyx END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 5 THEN adj_close_spyx END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 5 THEN adj_close_spyx END) * 100  AS spyx_percentage_change
FROM stock_prices
where year between 2014 and 2023
GROUP BY year
ORDER BY year desc
```

<DataTable data={stock_prices_hurricane_annual_returns_may_27}/>


```sql stock_prices_hurricane_annual_returns_may_1
  WITH stock_prices AS (
  SELECT 
    trading_date,
    EXTRACT(YEAR FROM trading_date) AS year,
    adj_close_hd,
    adj_close_low,
    adj_close_spyx
  FROM analytics_marts.stock_prices
  WHERE (EXTRACT(MONTH FROM trading_date) = 5 AND EXTRACT(DAY FROM trading_date) = 1)
     OR (EXTRACT(MONTH FROM trading_date) = 11 AND EXTRACT(DAY FROM trading_date) = 30)
)

SELECT 
  year,
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_hd END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 5 THEN adj_close_hd END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 5 THEN adj_close_hd END) * 100 AS hd_percentage_change,
  
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_low END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 5 THEN adj_close_low END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 5 THEN adj_close_low END) * 100  AS low_percentage_change,
  
  (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_spyx END) 
   - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 5 THEN adj_close_spyx END)) 
   / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 5 THEN adj_close_spyx END) * 100  AS spyx_percentage_change
FROM stock_prices
where year between 2014 and 2023
GROUP BY year
ORDER BY year desc
```

<DataTable data={stock_prices_hurricane_annual_returns_may_1}/>



## What's Next?
- [Connect your data sources](settings)
- Edit/add markdown files in the `pages` folder
- Deploy your project with [Evidence Cloud](https://evidence.dev/cloud)

## Get Support
- Message us on [Slack](https://slack.evidence.dev/)
- Read the [Docs](https://docs.evidence.dev/)
- Open an issue on [Github](https://github.com/evidence-dev/evidence)
