---
title: Storming the Market - How Atlantic Hurricane Season Impacts Home Improvement Stocks
---

## TL;DR
- We looked at price trends for Home Improvement stocks (Home Depot, Lowes) during Hurricane Season (June 1 - Nov 30) for the last 10 years
- A naive buy and sell strategy for HD outperformed SPY in the last 10 hurricane seasons 
- Leveraging hurricane data and adjusting the buy time based on a 3 year rolling average of category 0 hurricanes outperforms this baseline

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

```sql baseline_return

Select *
FROM hurricane_returns.baseline_return_table

```
<DataTable data={baseline_return}/>

Key Takeaways:
- Home Depot: The best-performing stock overall, with strong average/median returns, controlled downside risk, and the highest Sharpe Ratio.
- Lowe’s: Offers higher potential upside but comes with significantly more volatility, making it less appealing for risk-averse investors.
- S&P 500: The safest option with low volatility but also much lower average and median returns compared to HD and Lowe’s.

Motivated by this, we investigated whether incorporating hurricane telemetry (hurricane severity and occurrences)—could enhance returns further. The goal was to determine an optimal buy time for HD stock while maintaining the constraint of selling only on November 30th. 

## Cyclone Stats

Between 2014 and 2023, we analyzed 333 hurricanes. The year 2020 experienced the highest activity, with 47 events, 30 of which were Category 0, representing tropical storms. Hurricanes generally last 8–9 days, while tropical storms tend to persist for less than 5 days.

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

With an idea of how often and how long hurricanes occur in a season, we wanted to understand the timing of different hurricane severity within a season. This query helps model the timing of hurricanes by analyzing how many days after the start of the Atlantic hurricane season (June 1) each severity level first appears. By understanding these patterns, we can build models to predict hurricane behavior and its potential impact on stocks or other variables of interest.

```sql hurricane_start_analysis
  Select
    *
  FROM analytics_marts.hurricane_start_analysis
```

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

Our baseline strategy was based on the assumption that hurricane season in the Atlantic region starts June 1st and ends Nov 30th and this aligns with category 0 hurricanes first appearing beginning end of May/early June. The first category 1 hurricanes occur on average 42 days after the start of hurricane season whereas category 2 hurricanes and higher first appear 81 days after the start of hurricane season. Since category 1 hurricanes occur 6 weeks into hurricane season, we believed that a better return could be gained by investing later in the season

### Initial Strategy: Invest 40 days into hurricane season (July 14)

```sql stock_prices_hurricane_annual_returns_july_14
  Select * 
  from hurricane_returns.strategy_1_july14


```

<DataTable data={stock_prices_hurricane_annual_returns_july_14}/>

The results indicate that investing later in the season does not yield better returns compared to the baseline strategy. In fact, the average returns for all stocks were lower than the baseline. This outcome may be attributed to the efficient market hypothesis, which suggests that the market has already factored in the impact of hurricanes on these assets, eliminating any additional opportunities for profit.

### Revised Strategy: Dynamic Adjusting for Category 0 Hurricanes (Tropical Storms)
Analysis showed that Category 0 hurricanes frequently occurred 2–5 days before the official season start date of June 1. This suggested that shifting seasonal patterns, potentially influenced by climate change, could impact stock performance. To explore this, we calculated a rolling average start date based on the first occurrence of Category 0 hurricanes over the past three years and adjusted the buy timing accordingly.

The pseudocode is:
  - For each year
    - Calculate the average difference_in_days from the previous 3 years
    - Return avg_difference_in_days result for each year

```sql final_result_return
  Select *
  FROM hurricane_returns.final_result

```

<DataTable data={final_result_return}/>

Using dynamic adjusting, we are able to obtain better results compared to baseline. The new strategy improved average return by 1% and displayed an improving sharpe ratio indicating better risk-adjusted return.

## Conclusion

Our analysis highlights the impact of Atlantic hurricane season on Home Depot's stock performance and demonstrates the potential for leveraging hurricane data to optimize investment strategies. The baseline strategy of buying HD stock on June 1 and selling on November 30 consistently outperformed the S&P 500 over the last 10 hurricane seasons. However, deeper insights into hurricane telemetry enabled the development of a dynamic strategy that further enhanced returns.

By adjusting the buy timing based on a 3-year rolling average of Category 0 hurricanes' start dates, the revised approach achieved:

- Higher Returns: A 1% improvement in average returns compared to the baseline.
- Reduced Risk: Lower variance and standard deviation, reflecting a more stable performance.
- Better Risk-Adjusted Returns: A Sharpe ratio increase from 1.4 to 1.6.

