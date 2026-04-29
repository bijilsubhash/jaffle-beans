---
name: create-mart
description: Use when a stakeholder asks for a new business-facing dataset, dashboard input, or "can you put X in the warehouse" — turns a natural-language ask into a properly-built mart in the jaffle-beans dbt project. Composes the explore-warehouse skill (for data discovery via BigQuery MCP) and the dbt:using-dbt-for-analytics-engineering skill (for SQL/YAML scaffolding) while enforcing jaffle-beans-specific conventions. Trigger on phrases like "build a mart for...", "wire up X for Looker", "the [team] wants a table that...", or any stakeholder request that ends in a new mart.
user-invocable: true
argument-hint: "[stakeholder ask in plain English]"
---

# Create Mart

You are turning a stakeholder ask into a new mart in the **jaffle-beans** dbt project. The user's request is: $ARGUMENTS

The goal is a single mart (`mrt_<noun>`) that answers the ask, with schema docs, at least one unit test, and a build that passes — not just a SQL file. Treat this like a small project, not a one-shot script.

You will compose three things in this skill:

1. The **`explore-warehouse`** skill — to validate the data exists and learn its shape via the BigQuery MCP server before writing any SQL.
2. The **`dbt:using-dbt-for-analytics-engineering`** skill — for the actual SQL and YAML scaffolding, since it knows dbt patterns better than you do from scratch.
3. The **jaffle-beans conventions** below — naming, materialization layout, where unit tests live, the build/verify loop. These are not negotiable for this repo and override generic dbt advice when they conflict.

The reason the skill is structured this way: stakeholders ask vague questions, the warehouse has surprises, and the repo has its own rules. Rushing past any of those steps produces a mart that either doesn't answer the ask or doesn't fit the repo. Doing them in order is what makes the result usable.

---

## Layer Architecture (jaffle-beans)

| Layer | Materialization | Schema | Naming | Purpose |
|---|---|---|---|---|
| Staging | view | `staging` | `stg_<source>` | Lightly cleaned source data |
| Intermediate | view | `intermediate` | `int_<noun>_<modifier>` | Joins / reshapes / business logic that's reused |
| Marts | table | `marts` | `mrt_<noun>` | Final business-facing models — what stakeholders consume |

Materializations are set globally in `dbt_project.yml` — **do NOT add `{{ config(materialized=...) }}` to model files** unless you're deviating from the layer default (you almost never should).

This skill always ends in a **mart** (`mrt_*`). If the join/aggregation logic is non-trivial and reusable, also produce an **intermediate** (`int_*`) along the way so the mart stays readable.

---

## Step 1: Capture and Clarify the Ask

Parse `$ARGUMENTS` for the three things that determine the shape of the mart:

1. **Grain** — one row per what? (customer, order, store, product, store-day, ...) Stakeholders rarely say this explicitly; infer it from the question.
2. **Time scope** — is this a current snapshot, a rolling window (last 30/90 days), or full history?
3. **Slicing dimensions** — what does the stakeholder want to break the numbers down by?

If any of these is genuinely unclear from the ask, ask **one targeted question at a time** to fill the real gap. Do not present a checklist — that turns the user off and stalls the work. If the ask is concrete enough to start (e.g. "per-store revenue last 90 days"), just start; you can clarify later as discoveries surface them.

A useful sanity check before moving on: can you write the first sentence of the mart description? ("One row per `<grain>` showing `<measures>` for `<scope>`.") If you can't, you don't have enough yet.

---

## Step 2: Explore the Warehouse (delegate to `explore-warehouse`)

Before writing any SQL, invoke the **`explore-warehouse`** skill to validate the data. This is non-optional for two reasons:

- The BigQuery MCP server gives you ground-truth column names, types, and row counts — guessing wastes time.
- Stakeholders frequently ask for things the data can't actually answer (e.g. "lifetime value" when the warehouse only has the last year of payments). Catching that here is cheap; catching it after building the mart is expensive.

Use the skill to:

- List tables in `raw`, `staging`, and existing `marts` to see what's already available.
- Describe the staging tables you plan to use, so you know real column names before writing `select` clauses.
- Run small targeted queries to validate cardinality (`COUNT(*)`, `COUNT(DISTINCT <key>)`), null rates, and date coverage on the columns you'll filter on.
- Check if a similar mart already exists (e.g. `mrt_customers`) — if so, the answer might be "extend the existing mart" rather than build a new one. Surface this to the user before continuing.

When the exploration returns, you should be able to fill in:

- Which staging models / sources the mart will read from.
- The exact join keys.
- Any data-quality caveats worth mentioning in the mart description.

---

## Step 3: Plan the Model

Before writing files, state the plan back in 5–8 lines so the user can correct it cheaply:

- **Mart name** (`mrt_<noun>`)
- **Grain** (one row per ___)
- **Upstream models** (which `stg_*` / `int_*` you'll `ref()`)
- **Whether you're also creating an `int_*` model**, and why
- **Key columns** (a short list — full schema comes later)
- **Anything you discovered in exploration that affects scope** (date gaps, missing FKs, etc.)

Wait for a thumbs-up before writing files. This step is cheap and prevents thrashing.

---

## Step 4: Build via `dbt:using-dbt-for-analytics-engineering`

Now invoke the **`dbt:using-dbt-for-analytics-engineering`** skill to write the SQL and schema YAML. That skill knows dbt idioms — your job is to feed it the plan from Step 3 and enforce the jaffle-beans rules below on its output.

### Files to produce

| File | Purpose |
|---|---|
| `jaffle_beans/models/marts/mrt_<noun>.sql` | The mart model |
| `jaffle_beans/models/marts/_marts.yml` (append) | Schema docs + tests for the mart |
| `jaffle_beans/models/intermediate/int_<noun>_<modifier>.sql` (optional) | Intermediate model if join logic is reused or non-trivial |
| `jaffle_beans/models/intermediate/_intermediate.yml` (append, if intermediate created) | Schema docs for the intermediate |
| `jaffle_beans/models/unit_tests/_marts_unit_tests.yml` (append, create dir+file if missing) | At least one unit test for the mart |

### jaffle-beans rules (override generic dbt advice)

These exist because the repo enforces them and the build will break or look wrong if you don't follow them:

- **No `{{ config() }}` block** unless deviating from the layer default. Materialization is set in `dbt_project.yml`.
- **Always `{{ ref() }}` and `{{ source() }}`** — never hardcode `project.dataset.table`.
- **Always alias every table in joins.** BigQuery throws `Column name X is ambiguous` for unqualified columns when multiple tables share a column name. This is the single most common bug in this repo's `dbt show --inline` queries.
- **Match the existing CTE style** in `mrt_customers.sql` and `int_orders_enriched.sql` — `with foo as ( select * from {{ ref('...') }} )` at the top, then derived CTEs, then a final `select`. Don't invent a new pattern.
- **Schema YAML format** matches `_marts.yml` and `_intermediate.yml`: `version: 2`, `models:`, then `- name`, `description` (use a `>` block scalar for multi-line), and `columns:` with `tests:` for the primary key (`unique`, `not_null`).
- **Unit tests live in `models/unit_tests/`**, NEVER inline in the schema YAML. Create the directory and the `_marts_unit_tests.yml` file if they don't exist yet.

### Unit test (mandatory — at least one)

Write at least one unit test for the mart. The point isn't exhaustive coverage; it's making the model's intent executable. A good first unit test exercises the most surprising branch of the logic — e.g. a `case when status = 'completed' then ... else 0`, a `coalesce` for missing joins, a date filter. Pick the line that would silently break things if it regressed, and write the test for that.

Format (append to `models/unit_tests/_marts_unit_tests.yml`):

```yaml
version: 2

unit_tests:
  - name: test_<mart_name>_<what_it_validates>
    description: <one-line plain-English description>
    model: <mart_name>
    given:
      - input: ref('<upstream_model>')
        rows:
          - {col: value, ...}
      # one input block per ref() the mart uses
    expect:
      rows:
        - {col: expected_value, ...}
```

If `_marts_unit_tests.yml` already exists, append a new `- name:` entry under the existing `unit_tests:` list — do not duplicate the `version: 2` or `unit_tests:` keys.

---

## Step 5: Build and Verify

Run from the `jaffle_beans/` directory. `cd` into it once, then run dbt commands without a `cd` prefix:

```bash
cd jaffle_beans

# 1. Build the new mart and its upstream chain. --fail-fast stops at the first error
#    instead of running the rest of the DAG, which is what you want when iterating.
uv run dbt build --select +mrt_<noun> --fail-fast --profiles-dir .

# 2. Preview the output. Always use --limit, never a SQL LIMIT clause —
#    dbt appends its own LIMIT and `LIMIT 5 LIMIT 10` is a BigQuery syntax error.
uv run dbt show --select mrt_<noun> --limit 10 --profiles-dir .
```

If the build fails, fix the SQL and rerun — do not `dbt show --inline` with `ref('mrt_<noun>')` before the model has been materialized, because the underlying table won't exist yet. Use `dbt show --select mrt_<noun>` to preview an unmaterialized model.

---

## Step 6: Summary

When the build is green, give the stakeholder-friendly summary:

- **Answer** — one sentence connecting the mart to the original ask. ("`mrt_store_performance` answers your question — one row per store with revenue, order count, and refund rate over the last 90 days.")
- **What was built** — the file(s), the grain, and the key columns.
- **How to verify** — the `dbt show` command they can run themselves.
- **Caveats** — anything from exploration that affects how to read the numbers (date gaps, sample size, etc.).
- **Next steps** (optional) — if the exploration revealed something that should be a separate mart, a fix to a staging model, or a question for the stakeholder, surface it here. Don't start building it.

---

## Checklist

Before declaring done:

- [ ] Mart file at `jaffle_beans/models/marts/mrt_<noun>.sql`, named `mrt_<noun>`
- [ ] No `{{ config() }}` block (unless deviating from the `marts` layer default)
- [ ] All upstream references use `{{ ref() }}` or `{{ source() }}`
- [ ] Every table in every join is aliased
- [ ] Schema YAML appended to `_marts.yml` with description + primary-key tests (`unique`, `not_null`)
- [ ] At least one unit test in `models/unit_tests/_marts_unit_tests.yml` (NOT inline in `_marts.yml`)
- [ ] `uv run dbt build --select +mrt_<noun> --fail-fast --profiles-dir .` passes
- [ ] `uv run dbt show --select mrt_<noun> --limit 10 --profiles-dir .` returns rows that look right
- [ ] Summary delivered to user with answer, files, verification command, and caveats
