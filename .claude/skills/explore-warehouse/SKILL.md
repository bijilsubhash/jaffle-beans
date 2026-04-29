---
name: explore-warehouse
description: Use when exploring data in BigQuery to answer questions, sanity-check tables, or learn the shape of the warehouse before doing anything else with it. Drives an incremental loop - list tables, inspect schemas, run targeted queries, summarize findings. Use this skill whenever the user asks "what's in...", "how many...", "show me data from...", "what does X look like", or wants to poke around the warehouse, even if they don't say "BigQuery" or "explore" explicitly.
user-invocable: true
argument-hint: "[describe what you want to explore or answer]"
---

# Explore Warehouse

You are guiding a data exploration session against BigQuery using the BigQuery MCP server. The user wants: $ARGUMENTS

The goal is to answer the user's question or build their mental model of the data — not to write dbt code. If the exploration leads somewhere that needs a dbt model or fix, hand back to the user with findings rather than building it inside this skill.

---

## Step 1: Validate Environment

Before querying, confirm the BQ MCP server is reachable. The simplest check is to call `mcp__bigquery__list-tables` against a dataset you expect to exist (e.g. `raw`, `staging`, or one the user named). If that returns results, you're good. If it errors with auth or project issues, tell the user to check `direnv` is loaded and that they've run `gcloud auth application-default login` — don't try to debug it yourself, and don't echo env var values.

---

## Step 2: Capture the Goal

Parse the user's input for three things:

1. **End-state** — what should they have when this is done? (an answer, a row count, a sample, a sanity check)
2. **Known data sources** — which datasets, tables, or columns did they mention?
3. **Known constraints** — filters, date ranges, business rules they already know

Ask **one clarifying question at a time** to fill real gaps. Don't present a checklist. If the question is concrete enough to start ("how many orders did we get last month?"), just start — you can ask follow-ups as discoveries surface them.

---

## Step 3: Explore via BQ MCP

Use the BigQuery MCP tools to learn the data incrementally. Don't try to answer everything in one giant query — small steps surface surprises early.

### Available tools

| Tool | Use for |
|---|---|
| `mcp__bigquery__list-tables` | Discover what tables exist in a dataset |
| `mcp__bigquery__describe-table` | See columns, types, descriptions for a specific table |
| `mcp__bigquery__execute-query` | Run a read-only SELECT against the warehouse |

### Discovery sequence

1. **Find the tables** — `list-tables` on the datasets the user mentioned, or on `raw` / `staging` / `intermediate` / `marts` if they didn't name one.
2. **Understand the schema** — `describe-table` on candidates so you know what columns and types you're working with before querying.
3. **Validate assumptions with targeted queries** — pick the ones that match the user's question:
   - Cardinality of a join key: `SELECT COUNT(*), COUNT(DISTINCT key) FROM table`
   - Null rates: `SELECT COUNTIF(col IS NULL) / COUNT(*) FROM table`
   - Date coverage: `SELECT MIN(date_col), MAX(date_col) FROM table`
   - Sample rows: `SELECT * FROM table LIMIT 10`
   - Distribution of a categorical column: `SELECT col, COUNT(*) FROM table GROUP BY col ORDER BY 2 DESC LIMIT 20`

### Query rules

- **Always cap results.** Use `LIMIT 20` by default; raise it deliberately when you need more.
- **Don't `SELECT *` on wide tables** unless you also have a small `LIMIT` for sampling — pick the columns you actually need.
- **Fully qualify tables** as `` `project.dataset.table` ``. The MCP server is configured with `GCP_PROJECT_ID` already, so unqualified `dataset.table` references usually work, but qualifying avoids ambiguity in queries that hit multiple datasets.
- **Read-only.** The MCP server doesn't support DDL/DML, but don't try anyway — if a question needs to mutate state, surface that and stop.

### Schema map (jaffle_beans)

| Dataset | Layer | Notes |
|---|---|---|
| `raw` | Seeds (CSVs from `jaffle_beans/seeds/`) | Source-of-truth for this demo project |
| `staging` | dbt staging models (views) | Lightly cleaned versions of raw |
| `intermediate` | dbt intermediate models (views) | Joined / reshaped staging models |
| `marts` | dbt mart models (tables) | Final business-facing models |
| `${DEV_SCHEMA}` | Dev outputs | If the user is iterating on a model and wants to check their dev build |

When the user is vague about which layer to look in, prefer the layer closest to their question: business questions → `marts`, source-data questions → `raw`, "what's in the warehouse" → list across datasets.

### Present findings as you go

Don't batch everything until the end. After each query, briefly say what you learned and what you're checking next. The user should feel like a collaborator, not someone watching a black box. One sentence per step is plenty.

---

## Step 4: Summarize Findings

When you've answered the question (or hit a dead end), present a structured summary:

- **Answer** — the direct response to what they asked, with the supporting numbers
- **How you got there** — the tables and key queries (one line each, not a transcript)
- **Caveats** — data quality issues, gaps, or assumptions that affect confidence in the answer
- **Suggested next step** (only if useful) — e.g. "this would make sense as a mart model", "the gap in 2024-Q1 looks like a source issue worth flagging" — but stop there. Don't start building.

---

## Step 5: Wrap Up

- If the user wants to go deeper, loop back to Step 3 with the new question.
- If the exploration revealed something that should become a dbt model, a test, or a fix, hand back the findings and let the user decide whether to start that work in a fresh turn — that's outside the scope of this skill.

---

## Boundaries

- **Read-only.** All warehouse access goes through the BQ MCP server, which is read-only by design. Don't try to mutate state.
- **No dbt build/debug.** This skill is for exploration only. If exploration uncovers something that needs a dbt change, surface the finding and stop — let the user kick off that work separately.
- **No env-var dumping.** If something is misconfigured, surface the failure rather than echoing `GCP_PROJECT_ID` or other env values into the chat.
- **Use `dbt show` for previewing dbt models.** BQ MCP is for raw warehouse exploration. If the user wants to preview what an unmaterialized dbt model would return, that's `dbt show --select <model>` territory, not this skill.
