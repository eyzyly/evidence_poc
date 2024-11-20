WITH stock_prices AS (
  SELECT 
    trading_date,
    EXTRACT(YEAR FROM trading_date) AS year,
    adj_close_hd,
    adj_close_low,
    adj_close_spyx
  FROM `cse-6242-fa24-lz.analytics_marts.fct_stock_prices`
  WHERE (EXTRACT(MONTH FROM trading_date) = 6 AND EXTRACT(DAY FROM trading_date) = 1)
     OR (EXTRACT(MONTH FROM trading_date) = 11 AND EXTRACT(DAY FROM trading_date) = 30)
),
yearly_returns AS (
  SELECT 
    year,
    -- Calculate yearly return for adj_close_hd
    (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_hd END) 
     - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 6 THEN adj_close_hd END)) 
     / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 6 THEN adj_close_hd END) AS hd_yearly_return,
    
    -- Calculate yearly return for adj_close_low
    (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_low END) 
     - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 6 THEN adj_close_low END)) 
     / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 6 THEN adj_close_low END) AS low_yearly_return,
    
    -- Calculate yearly return for adj_close_spyx
    (MAX(CASE WHEN EXTRACT(MONTH FROM trading_date) = 11 THEN adj_close_spyx END) 
     - MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 6 THEN adj_close_spyx END)) 
     / MIN(CASE WHEN EXTRACT(MONTH FROM trading_date) = 6 THEN adj_close_spyx END) AS spyx_yearly_return
  FROM stock_prices
  GROUP BY year
)
SELECT
  -- Cumulative returns with reinvestment logic
  EXP(SUM(LOG(1 + hd_yearly_return))) - 1 AS hd_cumulative_return,
  EXP(SUM(LOG(1 + low_yearly_return))) - 1 AS low_cumulative_return,
  EXP(SUM(LOG(1 + spyx_yearly_return))) - 1 AS spyx_cumulative_return
FROM yearly_returns;
