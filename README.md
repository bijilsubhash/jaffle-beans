# Jaffle Beans — dbt Demo Project

A demo dbt project for a fictional coffee shop chain, built on **BigQuery**. Designed for testing and showcasing Claude skills for dbt.

## Prerequisites

- [uv](https://docs.astral.sh/uv/)
- [Task](https://taskfile.dev/)
- A GCP project with BigQuery enabled
- `gcloud auth application-default login`

## Getting Started

```bash
task setup          # installs deps, creates .env from .env.example
# edit .env with your GCP_PROJECT_ID and DEV_SCHEMA
task bootstrap      # seeds raw data + builds all models + runs tests
```

## Available Tasks

| Command          | Description                        |
|------------------|------------------------------------|
| `task setup`     | Install deps and prepare `.env`    |
| `task bootstrap` | Setup + seed + build               |
| `task seed`      | Load seed CSVs into BigQuery       |
| `task build`     | Build all models and run tests     |
| `task run`       | Run all models (no tests)          |
| `task test`      | Run all tests                      |
| `task clean`     | Clean dbt artifacts                |
