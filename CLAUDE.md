# CLAUDE.md

## Project Overview

Jaffle Beans: a demo dbt project for a fictional coffee shop chain, built on BigQuery.

## Tech Stack

- **dbt** (dbt-bigquery) for data transformations
- **uv** as the Python package manager and runner
- **Taskfile** for project task automation
- **BigQuery** as the data warehouse

## Running dbt Commands

This project uses `uv` to manage Python dependencies. All dbt commands must be run from the `jaffle_beans/` directory with the profiles directory flag.

**First** `cd` into the project directory once, **then** run dbt commands without `cd`:

```bash
# Do this once at the start of a session:
cd jaffle_beans

# Then run dbt commands directly (no cd prefix):
uv run dbt <command> --profiles-dir .
```
## Project Structure

- `jaffle_beans/` - the dbt project directory
  - `models/staging/` - staging views (schema: `staging`)
  - `models/intermediate/` - intermediate views (schema: `intermediate`)
  - `models/marts/` - mart tables (schema: `marts`)
  - `models/unit_tests/` - unit test YAML files (one per model layer)
  - `seeds/` - seed CSV files (schema: `raw`)
- `Taskfile.yml` - task runner definitions
- `pyproject.toml` - Python project config (uv)

## Unit Tests

Unit tests live in **`models/unit_tests/`**, NOT inline in model schema YAML files (e.g., `_intermediate.yml`, `_marts.yml`). Each model layer gets its own unit test file:

- `models/unit_tests/_intermediate_unit_tests.yml` - unit tests for intermediate models
- `models/unit_tests/_marts_unit_tests.yml` - unit tests for mart models

When adding a new unit test, create or append to the appropriate file in `models/unit_tests/`. Never add `unit_tests:` blocks to the model schema YAML files.

## Debugging Failures

When debugging a failing build, always use `--fail-fast` to stop at the first error instead of running the entire DAG:

```bash
uv run dbt build --fail-fast --profiles-dir .
```

This avoids wasting time on downstream models that will be skipped anyway and surfaces the root cause faster.

## New Model Workflow

When building a new model, always follow this order:

1. **Write** the SQL model file and YAML documentation/tests.
2. **Build** the model with `dbt build --select new_model` to materialize it and run tests.
3. **Validate** with `dbt show` after the model is materialized.

Do NOT run `dbt show --inline` with `ref('new_model')` before step 2 - the underlying table/view won't exist yet and the query will fail. Use `dbt show --select new_model` to preview an unmaterialized model without needing a `ref()`.

## Common dbt show Pitfalls

- **NEVER use a SQL `LIMIT` clause in `dbt show` queries - this WILL cause a BigQuery syntax error.** dbt appends its own `LIMIT`, so adding one in SQL produces `LIMIT 5 LIMIT 10` which is invalid. Always use the `--limit` flag instead. This applies to both `--select` and `--inline` queries.
- **Avoid `!=` and other special characters in `--inline` SQL strings.** The shell interprets backslash-like sequences (e.g. `!=` can become `\!`), causing syntax errors. Use the positive form (e.g. `column = 'value'`) or write the SQL in a file instead.
- **Do NOT use `ref()` in `dbt show --inline` for models that haven't been materialized yet.** If you just created a new model SQL file but haven't run `dbt run` or `dbt build` on it, `ref('new_model')` in an inline query will fail because the underlying table/view doesn't exist in the warehouse. Instead, use `dbt show --select new_model` to preview unmaterialized models, or write the join logic directly in the `--inline` query using `ref()` to the model's upstream dependencies.
- **Always use table aliases in `dbt show --inline` joins to avoid ambiguous column errors.** When joining multiple tables in an inline query, columns like `customer_id` that exist in more than one table will cause BigQuery's `Column name X is ambiguous` error. Always qualify every column reference with a table alias (e.g. `o.customer_id`, `c.first_name`).

## dbt Skills

IMPORTANT: ALWAYS invoke the matching dbt skill BEFORE starting any dbt-related task. This is mandatory, not optional. Use the Skill tool with the skill name below that best matches the task.

**Skill selection rules:**

1. **dbt:troubleshooting-dbt-job-errors** - use when a dbt job/build/run is **failing**, **broken**, or producing **errors**. Trigger phrases: "job is failing", "build failed", "debug errors", "tests are failing", "help me fix", "what went wrong".
2. **dbt:answering-natural-language-questions-with-dbt** - use when the user asks a **business question** that requires querying data (e.g., "What were total sales?", "Which store has the most revenue?"). NOT for building or fixing models.
3. **dbt:adding-dbt-unit-test** - use when the task is specifically about **adding or modifying unit tests** for dbt models, or doing TDD.
4. **dbt:building-dbt-semantic-layer** - use when creating or modifying **semantic models, metrics, or dimensions** (MetricFlow).
5. **dbt:fetching-dbt-docs** - use when the user wants to **look up dbt documentation** or learn about a dbt feature.
6. **dbt:running-dbt-commands** - use when unsure which dbt executable to use or how to format a specific dbt CLI command.
7. **dbt:using-dbt-for-analytics-engineering** - the general-purpose skill for **building new models**, modifying model logic, refactoring, exploring data sources, and other development work. Use this only when none of the more specific skills above apply.
