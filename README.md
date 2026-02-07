# Jaffle Beans: dbt Demo Project

A demo dbt project for a fictional coffee shop chain, built on BigQuery. Designed for testing and showcasing Claude skills for dbt.

## Prerequisites

- [uv](https://docs.astral.sh/uv/)
- [Task](https://taskfile.dev/)
- [gcloud CLI](https://cloud.google.com/sdk/docs/install)
- A GCP project with BigQuery enabled

## Getting Started

```bash
task setup          # installs deps, creates .env from .env.example
# edit .env with your GCP_PROJECT_ID and DEV_SCHEMA
task bootstrap      # seeds raw data + builds all models + runs tests
```

## Using with Claude Code

Before launching Claude Code, load the `.env` variables into your shell so they are available to the agent:

```bash
set -a && source .env && set +a
claude
```

> **Note:** In the context of AI tool use, refrain from storing actual secrets (API tokens, passwords) in `.env`. Agent tools could read file contents and command output, sending them to the API. The values in this project's `.env` (`GCP_PROJECT_ID`, `DEV_SCHEMA`) are non-sensitive configuration, not secrets.

## Available Tasks

| Command          | Description                        |
|------------------|------------------------------------|
| `task setup`     | Install deps and prepare `.env`    |
| `task auth`      | Authenticate to GCP via OAuth      |
| `task bootstrap` | Setup + auth + seed + build        |
| `task seed`      | Load seed CSVs into BigQuery       |
| `task build`     | Build all models and run tests     |
| `task run`       | Run all models (no tests)          |
| `task test`      | Run all tests                      |
| `task clean`     | Clean dbt artifacts                |
