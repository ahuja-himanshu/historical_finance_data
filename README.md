# Seasonal Desk — Historical Asset Performance

Rails application that answers seasonal and multi-year performance questions for major assets:

**How has BTC usually performed in August over the past 10 years?**

Returns are shown as **signed relative percentages** (`+12.30%` / `-4.15%`) with both a **table** and a **bar chart** of the same series.

## Supported assets

| Key        | Name       | Category      |
|------------|------------|---------------|
| `btc`      | Bitcoin    | Crypto        |
| `eth`      | Ethereum   | Crypto        |
| `dji`      | Dow Jones  | Equity index  |
| `spx`      | S&P 500    | Equity index  |
| `nifty`    | Nifty 50   | Equity index  |
| `banknifty`| Bank Nifty | Equity index  |
| `gold`     | Gold       | Commodity     |
| `silver`   | Silver     | Commodity     |

## Features

- **Month-wise view** — for a chosen calendar month, multi-year returns using  
  `(month-end close ÷ prior month-end close) − 1`.
- **Year-wise view** — calendar-year returns using  
  `(Dec close ÷ prior Dec close) − 1`. Incomplete current year is labeled **YTD**.
- **Current-year rules** — a month in the current year is included only after that month has fully completed relative to the as-of date; incomplete months are omitted.
- **Summary stats** — average, median, hit rate, best/worst year.
- **UI** — minimal dark “trading desk” theme, IBM Plex typography, smooth chart animation, responsive layout.

## Live site (GitHub Pages)

**https://ahuja-himanshu.github.io/historical_finance_data/**

Static build under `docs/` (HTML/CSS/JS + `data/prices.json`). Same relative-return math and period rules as the Rails app; no server required at request time.

Rebuild exported prices after data changes:

```bash
bin/rails static_site:export
```

## Quick start (Rails, local)

```bash
bundle install
bin/rails db:prepare
bin/rails tailwindcss:build   # or use bin/dev which watches CSS
bin/rails server              # http://127.0.0.1:3000
```

For CSS live rebuild + server:

```bash
bin/dev
```

## Query parameters

| Param      | Description                          | Default        |
|------------|--------------------------------------|----------------|
| `asset`    | Asset key (see table)                | `btc`          |
| `mode`     | `month` or `year`                    | `month`        |
| `month`    | Calendar month 1–12 (month mode)     | current month  |
| `lookback` | Years of history (3–20)              | `10`           |
| `as_of`    | Optional ISO date for period rules   | today          |

Example:

```
/?asset=btc&mode=month&month=8&lookback=10
/?asset=gold&mode=year&lookback=10
```

## Architecture

| Layer | Role |
|-------|------|
| `Asset` | Catalog of the eight supported instruments |
| `PriceRepository` | Loads month-end closes from `lib/data/prices/*.yml` |
| `PerformanceCalculator` | Pure relative-return math + period-completion rules |
| `MonthPerformanceQuery` / `YearPerformanceQuery` | Multi-year series + summary for the UI |
| `PerformanceController` | Root UI, param sanitization |
| Stimulus `performance-chart` | Chart.js bar chart from the same JSON as the table |

Performance math is isolated from HTTP so tests can pin `as_of` and assert against the shipped calculation path.

## Data

Month-end closes live under `lib/data/prices/`. Series are seeded from public year-end market reference levels with interpolated monthly paths and seasonal overlays for offline reliability (Nifty / Bank Nifty and free APIs are often incomplete). Percentages are always computed from those price levels — never hard-coded as one-off answers.

## Tests

```bash
bin/rails test
```

Coverage includes:

- signed % math and complete/incomplete period rules
- month-wise crypto / equity / commodity paths
- year-wise YTD labeling
- controller/UI smoke tests for all eight assets, chart payload, and tables

## Disclaimer

Past performance is not indicative of future results. This tool is for research and education only — not investment advice.
