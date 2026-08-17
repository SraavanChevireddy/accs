# Zinnov Director Operations Dashboard

A single-file dashboard for monthly client operations — expenses, payments,
escalations, actions and vendor performance. Hosted as a static page on GitHub
Pages, with records stored in a shared Supabase (Postgres) database so everyone
with the link reads and writes the same data, live.

Mirrors `Zinnov_Director_Operations_Monthly_Dashboard_Template.xlsx` column for
column.

```
index.html            the whole dashboard (HTML + CSS + JS, no build step)
supabase/schema.sql    run once in Supabase to create the five tables
test/                  local mock-Supabase harness for testing without a project
```

---

## Deploy — about 10 minutes

### 1. Create the database

1. Go to [supabase.com](https://supabase.com) → **New project**. Any name, any
   region close to India (Mumbai `ap-south-1` is best). Free tier is fine.
2. Wait for it to finish provisioning (~2 min).
3. Open **SQL Editor** → **New query**, paste the whole of
   [`supabase/schema.sql`](supabase/schema.sql), click **Run**.
   You should see `Success. No rows returned`.

That creates five tables — `monthly_input`, `payment_tracker`, `escalations`,
`action_tracker`, `vendor_performance` — plus open access policies, an
`updated_at` trigger, and realtime broadcasting.

### 2. Wire the page to it

1. In Supabase: **Project Settings → Data API**. Copy the **Project URL** and
   the **anon / public** key.
2. Open `index.html`, find this block near the top of the `<script>` (around
   line 100) and paste both values in:

   ```js
   const SUPABASE_URL      = 'https://xxxxxxxxxxxx.supabase.co';
   const SUPABASE_ANON_KEY  = 'eyJhbGciOi...';
   ```

Open `index.html` in a browser to check. A green banner reading
*"Connected to the shared database"* means you're done. A red or amber banner
tells you what's wrong.

### 3. Publish on GitHub Pages

```bash
cd zinnov-ops-dashboard
git init
git add .
git commit -m "Director Operations dashboard on shared Supabase"
git branch -M main
git remote add origin https://github.com/<you>/<repo>.git
git push -u origin main
```

Then on GitHub: **Settings → Pages → Source: Deploy from a branch**, branch
`main`, folder `/ (root)`, **Save**. After a minute the dashboard is live at
`https://<you>.github.io/<repo>/`. Share that link with the team.

---

## How it behaves

- **Everyone shares one dataset.** Add, edit or delete a record and it is
  written straight to Postgres.
- **Live for other people.** Open tabs subscribe to database changes and
  refresh themselves within a fraction of a second, so two people working at
  once see each other's rows without reloading.
- **Row-level editing.** Two people editing different records never overwrite
  each other. Editing the *same* record is last-write-wins; if someone deleted
  the row from under you, the save fails with a clear message rather than
  silently resurrecting it.
- **Degrades instead of breaking.** If the keys are missing, the Supabase
  library is blocked, or the network is down, the page says so in a banner and
  falls back to browser-only storage so it stays usable.
- **The Operations Team Entry tab** still auto-assigns the SPOC from the client
  and stamps the entering team member onto the record (`updated_by`).

## Data model

Five tables, one per input sheet of the Excel template. Excel headers map to
snake_case columns via the `COLMAP` object in `index.html`
(`Invoice Value ex GST (₹)` → `invoice_value_ex_gst`).

Twelve columns are **not stored** — `Total Amount (₹)`,
`Variance vs Budget (₹)`, `Variance %`, `MoM Variance (₹)`, `MoM Variance %`,
`Ageing Days`, `Ageing Bucket`, `RAG Status`, `Outstanding Amount (₹)`,
`Days Open`, `Days Overdue`, `Overall Rating`. These are formulas in the
workbook and are computed by `enrich()` at render time, so the numbers can
never drift from their inputs, and day-counters like `Days Open` stay correct
without anyone re-saving a row.

Percentages are stored as fractions (`0.95` = 95%), matching what the existing
form code already produced. Money is `numeric(14,2)`; dates are real `date`
columns with blanks stored as `NULL`.

## Security — read this before real client data goes in

Access is deliberately open: the anon key sits in the published HTML, and the
RLS policies allow anyone holding it to read, insert, update and delete every
row. Anyone who finds the GitHub Pages URL has full access to the data. That is
the accepted tradeoff for the MVP.

Two ways to tighten it later without touching the data model:

- **A shared passcode.** Turn on Supabase email/password auth, create one team
  login, and change each policy from `to anon, authenticated` to
  `to authenticated`.
- **Real accounts.** Enable Google auth and restrict policies to an
  allow-listed set of addresses or a `@zinnov.com` domain check.

## Testing locally without Supabase

`test/mock-supabase.js` is a small in-memory stand-in for the Supabase client,
so the online read/write path can be driven with no project and no network:

```bash
./test/build-harness.sh
python3 -m http.server 8765
# open http://localhost:8765/test/index.html
```

`test/index.html` is generated and git-ignored — edit `index.html` and re-run
the script. The script also syntax-checks the page script with `node --check`.

Verified this way: boot and connect, insert from both the Operations Team Entry
form and the Add/Edit modal, update without duplicating the row, delete,
blank-to-`NULL` coercion on dates and numbers, percentage fractions, integer
counts, KPI and ageing derivation from stored inputs, and the offline fallback
banner.
