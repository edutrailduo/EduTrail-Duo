-- EduTrail Duo: private Work & Salary Tracker storage
create table if not exists public.work_shifts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  work_date date not null,
  start_time text not null,
  end_time text not null,
  break_minutes integer not null default 0 check (break_minutes >= 0),
  hours numeric(8,2) not null check (hours > 0 and hours <= 24),
  hourly_wage numeric(12,2) not null check (hourly_wage >= 0),
  note text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists work_shifts_user_date_idx
  on public.work_shifts (user_id, work_date desc);

alter table public.work_shifts enable row level security;

drop policy if exists "Users can view their own work shifts" on public.work_shifts;
create policy "Users can view their own work shifts"
  on public.work_shifts for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can add their own work shifts" on public.work_shifts;
create policy "Users can add their own work shifts"
  on public.work_shifts for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can delete their own work shifts" on public.work_shifts;
create policy "Users can delete their own work shifts"
  on public.work_shifts for delete to authenticated
  using ((select auth.uid()) = user_id);

-- Daily automatic cleanup: retain only the most recent 60 days.
create extension if not exists pg_cron with schema extensions;
select cron.unschedule(jobid)
from cron.job
where jobname = 'edutrail-delete-work-shifts-older-than-60-days';

select cron.schedule(
  'edutrail-delete-work-shifts-older-than-60-days',
  '15 3 * * *',
  $$delete from public.work_shifts where work_date < current_date - 60;$$
);
