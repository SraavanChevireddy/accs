-- ============================================================================
--  Zinnov Director Operations Dashboard — Supabase schema
--  Run this once in Supabase Studio → SQL Editor → New query → Run.
--
--  Five tables, one per input sheet of the Excel template.
--  Calculated columns (Total Amount, Variance, Ageing Days, RAG Status,
--  Outstanding Amount, Days Open, Days Overdue, Overall Rating) are NOT
--  stored — the dashboard derives them at render time, exactly like the
--  Excel formulas do.
--
--  NOTE: access is intentionally OPEN (anyone with the anon key can read and
--  write). This is an MVP choice. See README before putting real data in.
-- ============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- Monthly Input
create table if not exists public.monthly_input (
  id                     uuid primary key default gen_random_uuid(),
  reporting_month        text,            -- 'YYYY-MM'
  client                 text,
  location               text,
  operations_owner       text,
  expense_head           text,
  vendor                 text,
  invoice_no             text,
  invoice_date           date,
  service_period         text,
  po_no                  text,
  po_value               numeric(14,2),
  invoice_value_ex_gst   numeric(14,2),
  gst_tax                numeric(14,2),
  monthly_budget         numeric(14,2),
  previous_month_actual  numeric(14,2),
  invoice_received       text,
  payment_status         text,
  payment_due_date       date,
  payment_date           date,
  variance_delay_remarks text,
  updated_at             timestamptz not null default now(),
  updated_by             text
);

-- -------------------------------------------------------------- Payment Tracker
create table if not exists public.payment_tracker (
  id                       uuid primary key default gen_random_uuid(),
  reporting_month          text,
  client                   text,
  vendor                   text,
  expense_head             text,
  invoice_no               text,
  invoice_date             date,
  invoice_amount           numeric(14,2),
  submission_date          date,
  due_date                 date,
  payment_status           text,
  payment_date             date,
  delay_reason             text,
  current_owner            text,
  expected_resolution_date date,
  business_vendor_impact   text,
  updated_at               timestamptz not null default now(),
  updated_by               text
);

-- ------------------------------------------------------------------ Escalations
create table if not exists public.escalations (
  id                  uuid primary key default gen_random_uuid(),
  reporting_month     text,
  date_raised         date,
  client              text,
  category            text,
  issue_summary       text,
  severity            text,
  raised_by           text,
  owner               text,
  immediate_action    text,
  root_cause          text,
  corrective_action   text,
  target_closure_date date,
  current_status      text,
  closure_date        date,
  leadership_remarks  text,
  updated_at          timestamptz not null default now(),
  updated_by          text
);

-- --------------------------------------------------------------- Action Tracker
create table if not exists public.action_tracker (
  id                         uuid primary key default gen_random_uuid(),
  reporting_month            text,
  client                     text,
  issue_risk                 text,
  impact                     text,
  priority                   text,
  action_required            text,
  owner                      text,
  start_date                 date,
  due_date                   date,
  status                     text,
  latest_update              text,
  leadership_decision_support text,
  updated_at                 timestamptz not null default now(),
  updated_by                 text
);

-- ----------------------------------------------------------- Vendor Performance
create table if not exists public.vendor_performance (
  id                       uuid primary key default gen_random_uuid(),
  reporting_month          text,
  client                   text,
  vendor                   text,
  service_category         text,
  sla_adherence_pct        numeric(6,4),   -- stored as a fraction, 0.95 = 95%
  manpower_deployment_pct  numeric(6,4),
  response_time_rating     text,
  invoice_accuracy_pct     numeric(6,4),
  compliance_docs_complete text,
  incident_count           integer,
  client_feedback          text,
  corrective_actions_open  text,
  management_remarks       text,
  renewal_commercial_risk  text,
  updated_at               timestamptz not null default now(),
  updated_by               text
);

-- ============================================================================
--  updated_at is owned by the database, never by the browser's clock
-- ============================================================================
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $fn$
begin
  new.updated_at := now();
  return new;
end
$fn$;

-- ============================================================================
--  Triggers, indexes, open access policies, realtime — all five tables
-- ============================================================================
do $$
declare
  t text;
  tables text[] := array[
    'monthly_input','payment_tracker','escalations',
    'action_tracker','vendor_performance'
  ];
begin
  foreach t in array tables loop

    execute format('drop trigger if exists set_updated_at on public.%I', t);
    execute format(
      'create trigger set_updated_at before insert or update on public.%I
         for each row execute function public.touch_updated_at()', t);

    -- the global month / client filter hits these two columns constantly
    execute format(
      'create index if not exists %I on public.%I (reporting_month, client)',
      t || '_month_client_idx', t);

    -- open read/write for the anon key (MVP: no auth)
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists public_read_write on public.%I', t);
    execute format(
      'create policy public_read_write on public.%I for all to anon, authenticated using (true) with check (true)',
      t);

    -- push changes to every open browser tab
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception
      when duplicate_object then null;
    end;

  end loop;
end
$$;
