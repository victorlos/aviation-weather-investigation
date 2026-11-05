# Aviation Weather Investigation

![Pipeline](https://img.shields.io/badge/pipeline-dbt-FF694B?logo=dbt&logoColor=white)
![Warehouse](https://img.shields.io/badge/warehouse-Snowflake-29B5E8?logo=snowflake&logoColor=white)
![Architecture](https://img.shields.io/badge/architecture-ELT-6E40C9)
![CD](https://github.com/victorlos/aviation-weather-investigation/actions/workflows/dbt_run_on_merge.yml/badge.svg?branch=main)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**How much does weather really delay U.S. flights?**
> An end-to-end analytics engineering project that combines U.S. flight performance data (BTS) with daily weather observations (NOAA) to measure how rain, wind, thunderstorms, fog and freezing conditions affect delays and cancellations at U.S. airports.

Built with **dbt** running natively on **Snowflake** (dbt Projects on Snowflake), with Python ingestion scripts, a tested, layered data model, and a daily incremental weather refresh orchestrated with **Snowflake Tasks**.

---

## 📌 Business Questions
 
1. Do days with heavy rain, strong wind or thunderstorms have higher delay and cancellation rates?
2. Which airports are most sensitive to bad weather, and which recover fastest?
3. How much of the weather impact is hidden in the **NAS delay** category instead of the official **Weather delay** category?
4. Which airlines handle bad-weather days best?

## 🏗️ Architecture
 
### Data flow
 
```mermaid
flowchart LR
    subgraph SRC["Data sources"]
        BTS["BTS On-Time Performance<br/>monthly zip files"]
        LK["BTS carrier lookup"]
        MC["BTS Master Coordinate<br/>airport lat/lon"]
        NOAA["NOAA GHCN-Daily<br/>public S3 bucket"]
    end
 
    subgraph LOCAL["Local machine - Jupyter notebooks"]
        NB2["02_download_aviation_data<br/>requests + Selenium"]
        NB3["03_create_raw_tables<br/>runs setup SQL scripts"]
    end
 
    subgraph SF["Snowflake - AVIATION_WEATHER_PROJECT"]
        ST1[("BTS_FLIGHTS<br/>internal stage")]
        ST2[("WEATHER_DATA<br/>external stage")]
        RAW[("RAW_DATA<br/>raw tables")]
        STG["dbt staging<br/>views"]
        MART["dbt marts<br/>facts + dimensions"]
        AN["dbt analyses"]
        T1["Task: refresh weather<br/>daily MERGE, 02:00 UTC"]
        T2["Task: build weather models<br/>incremental dbt build"]
    end
 
    BTS --> NB2
    LK --> NB2
    MC --> NB2
    NB2 -->|PUT| ST1
    NOAA -.->|read in place| ST2
    ST1 -->|COPY INTO| RAW
    ST2 -->|COPY INTO| RAW
    NB3 -.->|runs| RAW
    RAW -->|source| STG
    RAW -->|source| MART
    STG -->|ref| MART
    MART --> AN
    ST2 -->|last 30 days| T1
    T1 -->|MERGE| RAW
    T1 -->|then| T2
    T2 -.->|builds| MART
```
 
### CI/CD
 
```mermaid
flowchart LR
    PR["Pull request to main"] --> LINT["Lint Python<br/>ruff"]
    LINT --> DEP1["snow dbt deploy<br/>tester project object"]
    DEP1 --> BUILD["dbt build<br/>target ci - schema CI"]
    MERGE["Merge / push to main"] --> DEP2["snow dbt deploy<br/>project object - target prod"]
```
**Key design decisions**
 
- **EL is separated from T.** Ingestion (downloads, stages, `COPY INTO`) lives in Python and SQL scripts outside dbt. dbt only transforms data that is already in Snowflake, declared as `sources`.
- **Airports are matched to weather stations by location, not by name.** Station and airport names never match reliably, so the project computes the distance between every airport and nearby NOAA stations with Snowflake's `HAVERSINE` function and keeps the closest station within 20 km.
- **dbt runs inside Snowflake.** GitHub Actions deploys the project as a Snowflake object (dbt Projects on Snowflake) with the Snowflake CLI, and it runs there with `EXECUTE DBT PROJECT`, with no external dbt server.
- **Weather data is refreshed incrementally.** NOAA rewrites its current-year file every day, so instead of reloading it, a daily task `MERGE`s only the last 30 days into `RAW_WEATHER`: new readings are inserted, corrected readings are updated, and nothing is duplicated.
- **`fact_weather` is an incremental model.** Each run recomputes only the last 30 days and merges them by station and date, since NOAA keeps adding late readings for recent days.


## 📊 Data Sources
 
| Source | Description | Grain | Access |
|---|---|---|---|
| [BTS On-Time Performance](https://www.transtats.bts.gov/Tables.asp?QO_VQ=EFD) | Every U.S. domestic flight with scheduled/actual times, delays and delay causes | One row per flight | Monthly zip files |
| [BTS Master Coordinate](https://www.transtats.bts.gov/DL_SelectFields.aspx?gnoyr_VQ=FLL&QO_fu146_anzr=N8vn6v10%20f722146%20gnoyr5) | Airport IDs, codes, latitude, longitude and UTC offset | One row per airport version | Web form (automated with Selenium) |
| [NOAA GHCN-Daily](https://registry.opendata.aws/noaa-ghcn/) | Daily weather observations: precipitation, temperature, wind and weather-type flags | One row per station, day and element | Public AWS S3 bucket |
 
**Period covered:** flights from January 2025 to July 2026; weather from January 2025, refreshed daily.
 
---

## 🔄 Daily Weather Refresh (Incremental Load)

Weather data keeps updating after the initial load, through two Snowflake Tasks created by `dbt-aviation-weather/setup/create_task_refresh_weather_data.sql`:

| Task | When | What it does |
|---|---|---|
| `RAW_DATA.TASK_REFRESH_WEATHER_DATA` | Every day at 02:00 UTC | Reads the current-year NOAA file from S3 and `MERGE`s the last 30 days of airport-station readings into `RAW_WEATHER` |
| `RAW_DATA.BUILD_FACT_WEATHER` | Right after the refresh | Runs `dbt build --select +fact_weather+` on the production dbt project object |

`fact_weather` is materialized as **incremental** (`unique_key = ['STATION_ID', 'DATE']`):

- The **first run** builds the whole table.
- **Later runs** recompute only the last 30 days before the most recent date already in the table, then merge them in. Days that changed are replaced, and new days are added.
- After changing the model's logic, rebuild it once from scratch: `dbt build --select fact_weather --full-refresh`.

Monitoring and maintenance:

```sql
-- Recent runs, with errors if any
SELECT name, state, scheduled_time, error_message
FROM TABLE(AVIATION_WEATHER_PROJECT.INFORMATION_SCHEMA.TASK_HISTORY())
ORDER BY scheduled_time DESC;

-- Run the refresh now instead of waiting for the schedule
EXECUTE TASK AVIATION_WEATHER_PROJECT.RAW_DATA.TASK_REFRESH_WEATHER_DATA;

-- Pause both tasks to stop spending credits
ALTER TASK AVIATION_WEATHER_PROJECT.RAW_DATA.TASK_REFRESH_WEATHER_DATA SUSPEND;
ALTER TASK AVIATION_WEATHER_PROJECT.RAW_DATA.BUILD_FACT_WEATHER SUSPEND;
```

> **Every January:** the refresh reads `csv/by_year/<year>.csv`, so update the year in the task script (for example, 2026 → 2027) and run it again.

## 🚀 How to Run
 
### Prerequisites
 
- A Snowflake account (a 30-day trial works) with access to the `ACCOUNTADMIN` role
- Python 3.12 and Git
- Google Chrome (used by Selenium for the airport coordinates download)
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli/index), only to run the dbt project inside Snowflake from your machine
### 1. Clone the repo and install dependencies
 
```bash
git clone https://github.com/victorlos/aviation-weather-investigation.git
cd aviation-weather-investigation
 
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt jupyter
```
 
### 2. Configure your credentials
 
```bash
cp .env.example .env
```
 
Fill in `.env` with your Snowflake account, user and password. Use `SNOWFLAKE_ROLE=ACCOUNTADMIN` for the setup steps, and set `GITHUB_PAT` to a GitHub token with read access to this repo (used to connect Snowflake to the repository). The `.env` file is ignored by Git and must never be committed.
 
### 3. Create the Snowflake infrastructure
 
Run **`notebooks/01_infrastructure_creation_snowflake.ipynb`**. It executes `notebooks/00_infrastructure_commands.sql`, which creates:
 
- the `AVIATION_WEATHER_WAREHOUSE` warehouse (X-Small, auto-suspend after 60 seconds);
- the `AVIATION_WEATHER_PROJECT` database and the `RAW_DATA` schema;
- the stages `BTS_FLIGHTS` (internal, for BTS files) and `WEATHER_DATA` (external, pointing to NOAA's public S3 bucket);
- the Git integration, and the service user and role used by GitHub Actions.
> Run the notebooks from inside the `notebooks/` folder, since they use relative paths.
 
### 4. Download the data and upload it to Snowflake
 
```bash
mkdir -p data/bts/_downloads
```
 
Then run **`notebooks/02_download_aviation_data.ipynb`**. It downloads the BTS monthly files (January 2025 – July 2026), the carrier lookup and the airport coordinates (with Selenium), and uploads them to the `BTS_FLIGHTS` stage with `PUT`. NOAA data doesn't need downloading, since Snowflake reads it directly from S3.
 
### 5. Create and load the raw tables
 
Run **`notebooks/03_create_raw_tables.ipynb`**. It executes the scripts in `dbt-aviation-weather/setup/` in alphabetical order: the `create_raw_*` scripts create the five raw tables in `RAW_DATA` and load them with `COPY INTO`, and `create_task_refresh_weather_data.sql` creates and starts the two daily tasks described in [Daily Weather Refresh](#-daily-weather-refresh-incremental-load). The first run takes a few minutes, mostly to load two years of global weather data.

> The build task runs the production dbt project object deployed by the CD workflow (step 8). Until that object exists, the refresh task still updates `RAW_WEATHER`, but the build task fails.
 
### 6. Build the dbt models
 
**Option A: locally with dbt Core** (builds into the `DEV` schema)
 
```bash
cd dbt-aviation-weather
set -a; source ../.env; set +a     # dbt reads credentials from environment variables
dbt debug                          # checks the connection
dbt build                          # builds every model and runs all tests
```
 
**Option B: inside Snowflake with the Snowflake CLI**
 
```bash
set -a; source .env; set +a
export SNOWFLAKE_CLI_FEATURES_ENABLE_DBT=true
 
snow dbt deploy aviation_weather --source ./dbt-aviation-weather -x \
  --database AVIATION_WEATHER_PROJECT --schema CICD
snow dbt execute aviation_weather build -x \
  --database AVIATION_WEATHER_PROJECT --schema CICD
```
 
### 7. Run the analyses
 
dbt compiles analyses into plain SQL without executing them:
 
```bash
cd dbt-aviation-weather
dbt compile --select airport_most_delays
```
 
Then run the SQL from `target/compiled/aviation_weather/analysis/airport_most_delays.sql` in a Snowflake worksheet.
 
### 8. (Optional) Set up CI/CD in your own fork
 
1. **Create a programmatic access token (PAT)** for the CI user in Snowsight: *Governance & security → Users & roles → `GITHUB_ACTIONS_SERVICE_USER` → Programmatic access tokens*. Set the role restriction to `GITHUB_ACTIONS_ROLE` and choose an expiry date. Snowflake may require a network policy before it lets a service user create or use a PAT.
2. **Add GitHub secrets** (*Settings → Secrets and variables → Actions*): `SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER` (`GITHUB_ACTIONS_SERVICE_USER`) and `SNOWFLAKE_PAT`.
3. **Add GitHub variables:** `SNOWFLAKE_DATABASE` = `AVIATION_WEATHER_PROJECT` and `SNOWFLAKE_SCHEMA` = `CICD`.
From then on:
 
- **`incoming_pr.yml`** runs on every pull request to `main`: it lints the Python code with ruff, deploys a tester dbt project object and runs `dbt build` against the `ci` target (schema `CI`).
- **`dbt_run_on_merge.yml`** runs on every push to `main`: it deploys the project object `aviation_weather_dbt_object_gh_action` with the `prod` target. To build production, execute it:
```sql
EXECUTE DBT PROJECT AVIATION_WEATHER_PROJECT.CICD.AVIATION_WEATHER_DBT_OBJECT_GH_ACTION
  ARGS = 'build';
```
 
---
 
## 🗂️ Repository Structure
 
```
├── .github/workflows/
│   ├── incoming_pr.yml          CI: lint + dbt build on pull requests
│   └── dbt_run_on_merge.yml     CD: deploy the dbt project on merge to main
├── notebooks/
│   ├── 00_infrastructure_commands.sql
│   ├── 01_infrastructure_creation_snowflake.ipynb
│   ├── 02_download_aviation_data.ipynb
│   └── 03_create_raw_tables.ipynb
├── dbt-aviation-weather/
│   ├── setup/                   SQL that creates and loads the raw tables, and the daily refresh tasks
│   ├── models/
│   │   ├── staging/
│   │   ├── marts/
│   │   ├── sources.yml
│   │   └── test.yml
│   ├── analysis/
│   ├── tests/
│   ├── dbt_project.yml
│   └── profiles.yml             targets dev, ci and prod (no secrets)
├── .env.example
├── LICENSE
└── requirements.txt
```