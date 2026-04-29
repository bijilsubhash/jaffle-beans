# CLAUDE.md - Agent Instructions for jaffle-beans

<!-- Keep this file concise. Every line is loaded into every agent session.
     Move verbose reference material to .claude/skills/ (loaded on demand). -->

## Project Overview

**Jaffle Beans** — a demo dbt project for a fictional coffee shop chain, built on BigQuery.

- **jaffle_beans/** — dbt project with staging/intermediate/marts layers
- **uv** — Python package manager and runner
- **Taskfile** — project task automation
- **BigQuery** — the data warehouse

---

## dbt Skills (CRITICAL)

**Use dbt skills for ALL dbt-related work** — models, tests, YAML, CLI commands, documentation lookups, and troubleshooting. ALWAYS invoke the matching skill BEFORE starting the task.

| Skill | Use When... |
|---|---|
| **dbt:using-dbt-for-analytics-engineering** | Building or modifying dbt models, sources, tests, refactoring, exploring data sources. The go-to skill for day-to-day dbt work. |
| **dbt:running-dbt-commands** | Executing any dbt CLI command (`build`, `run`, `test`, `show`, `list`). Use when unsure which executable or how to format flags. |
| **dbt:adding-dbt-unit-test** | Creating or modifying unit tests for dbt models, or doing TDD. |
| **dbt:building-dbt-semantic-layer** | Creating or modifying semantic models, metrics, or dimensions (MetricFlow). |
| **dbt:answering-natural-language-questions-with-dbt** | When a user asks a business/data question (e.g., "What were total sales last month?"). NOT for building or fixing models. |
| **dbt:fetching-dbt-docs** | Looking up dbt documentation or learning about a dbt feature. |
| **dbt:troubleshooting-dbt-job-errors** | A dbt job/build/run is **failing**, **broken**, or producing **errors**. Trigger phrases: "build failed", "tests are failing", "help me fix", "what went wrong". |
| **dbt:configuring-dbt-mcp-server** | Setting up or modifying the dbt MCP server integration. |
| **dbt:migrating-dbt-core-to-fusion** | Migrating this project from dbt Core to the Fusion engine. |

### dbt Skill Rules

1. **Always check skills first** — Before writing any dbt SQL, YAML, or running dbt commands, identify which skill applies.
2. **Combine skills when needed** — A task like "add a new mart model with tests" uses both `dbt:using-dbt-for-analytics-engineering` and `dbt:adding-dbt-unit-test`.
3. **Follow skill principles** — e.g., always preview data with `dbt show`, never modify a test just to make it pass without understanding why it failed.

---

## Project Skills

| Skill | Use When... |
|---|---|
| **explore-warehouse** | Exploring data in BigQuery, sanity-checking tables, or learning the shape of the warehouse. Drives an incremental loop via the BQ MCP server. Trigger phrases: "what's in...", "how many...", "show me data from...", "what does X look like". |

---

## Project Structure

```
jaffle_beans/             # dbt project
├── models/
│   ├── staging/          # Views — schema: staging
│   ├── intermediate/     # Views — schema: intermediate
│   ├── marts/            # Tables — schema: marts
│   └── unit_tests/       # Unit test YAML files (one per model layer)
├── seeds/                # Seed CSVs — schema: raw
Taskfile.yml              # Task runner definitions
pyproject.toml            # Python project config (uv)
```

## Key Conventions

- **Materialization**: staging = view, intermediate = view, marts = table
- **Schema mapping**: each layer writes to its own schema (`staging`, `intermediate`, `marts`, `raw` for seeds)
- **References**: always use `{{ ref() }}` and `{{ source() }}` — never hardcode table names
- **Unit tests location**: live in `models/unit_tests/`, NOT inline in model schema YAML files. Each layer gets its own file (e.g., `_intermediate_unit_tests.yml`, `_marts_unit_tests.yml`). Never add `unit_tests:` blocks to schema YAML files.
- **DAG design**: follow the existing staging → intermediate → marts layered architecture.

## Commands

All dbt commands run from `jaffle_beans/` with the `--profiles-dir .` flag. `cd` into it once at the start of a session, then run dbt commands without a `cd` prefix:

```bash
# Once per session
cd jaffle_beans

# Then
uv run dbt build --select <model> --profiles-dir .
uv run dbt show --select <model> --limit 10 --profiles-dir .
uv run dbt test --select <model> --profiles-dir .

# Debugging a failing build — always use --fail-fast
uv run dbt build --fail-fast --profiles-dir .
```

## New Model Workflow

When building a new model, always follow this order:

1. **Write** the SQL model file and YAML documentation/tests.
2. **Build** the model with `dbt build --select new_model` to materialize it and run tests.
3. **Validate** with `dbt show` after the model is materialized.

Do NOT run `dbt show --inline` with `ref('new_model')` before step 2 — the underlying table/view won't exist yet. Use `dbt show --select new_model` to preview an unmaterialized model without needing a `ref()`.

## Common dbt show Pitfalls

- **NEVER use a SQL `LIMIT` clause in `dbt show` queries — this WILL cause a BigQuery syntax error.** dbt appends its own `LIMIT`, so adding one in SQL produces `LIMIT 5 LIMIT 10` which is invalid. Always use the `--limit` flag instead. Applies to both `--select` and `--inline`.
- **Avoid `!=` and other special characters in `--inline` SQL strings.** The shell interprets backslash-like sequences (e.g. `!=` can become `\!`), causing syntax errors. Use the positive form (e.g. `column = 'value'`) or write the SQL in a file instead.
- **Do NOT use `ref()` in `dbt show --inline` for unmaterialized models.** Use `dbt show --select new_model` to preview unmaterialized models, or write the join logic directly in the `--inline` query using `ref()` to upstream dependencies.
- **Always use table aliases in `dbt show --inline` joins.** Columns like `customer_id` that exist in multiple tables will trigger `Column name X is ambiguous` in BigQuery. Qualify every column with a table alias (e.g. `o.customer_id`, `c.first_name`).

## Environment Variables

Assume all required env vars (`GCP_PROJECT_ID`, `GCP_REGION`, `DEV_SCHEMA`, etc.) are already set via `direnv` from `.envrc`. Do NOT print, echo, or otherwise dump environment variable values into the terminal — including for debugging or "checking" purposes. If a command fails due to a missing var, surface the failure rather than inspecting the environment.

## BigQuery MCP Server

The `.mcp.json` configures `mcp-server-bigquery` (LucasHild) run via `uvx` (no install — uvx fetches and caches it). The server takes `--project` and `--location` from `GCP_PROJECT_ID` and `GCP_REGION`. Auth uses GCP application-default credentials — run `gcloud auth application-default login` once.

**Available tools:** `mcp__bigquery__list-tables`, `mcp__bigquery__describe-table`, `mcp__bigquery__execute-query`

**Usage:** Use the `explore-warehouse` skill for guided workflows, or use the BQ MCP tools directly for quick ad-hoc queries. Use `dbt show` (with `--select` or `--inline`) for previewing **dbt models** specifically — use the BQ MCP tools for everything else that hits the warehouse directly.
