create extension if not exists pgcrypto;
create type public.account_role as enum ('customer','owner');
create type public.topup_status as enum ('pending','approved','rejected');
create type public.order_status as enum ('pending','processing','completed','failed','refunded');
create type public.money_currency as enum ('THB','MMK');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  role public.account_role not null default 'customer',
  created_at timestamptz not null default now()
);
create table public.wallets (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  balance_coins bigint not null default 0 check (balance_coins >= 0),
  updated_at timestamptz not null default now()
);

-- Owner-editable MMK/THB rate. Example: 1 THB = 100 MMK.
-- Keep the rate configurable; do not assume this example is the live market rate.
create table public.shop_settings (
  id boolean primary key default true check (id),
  mmk_per_thb numeric(14,4) not null default 100 check (mmk_per_thb > 0),
  updated_at timestamptz not null default now()
);
insert into public.shop_settings (id, mmk_per_thb) values (true, 100)
on conflict (id) do nothing;

create table public.wallet_topups (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  currency public.money_currency not null,
  amount_local numeric(14,2) not null check (amount_local > 0),
  mmk_per_thb_snapshot numeric(14,4) not null check (mmk_per_thb_snapshot > 0),
  coin_credit bigint check (coin_credit is null or coin_credit > 0),
  receipt_path text,
  transfer_reference text,
  status public.topup_status not null default 'pending',
  owner_note text,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  check ((status = 'pending' and reviewed_at is null and reviewed_by is null)
      or status <> 'pending')
);
create table public.wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  amount_coins bigint not null check (amount_coins <> 0),
  entry_type text not null check (entry_type in ('topup_credit','purchase_debit','refund_credit','manual_adjustment')),
  reference_id uuid,
  note text,
  created_at timestamptz not null default now()
);
create table public.diamond_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id),
  mlbb_user_id text not null,
  mlbb_zone_id text not null,
  diamond_amount integer not null check (diamond_amount > 0),
  price_coins bigint not null check (price_coins > 0),
  supplier_cost_thb numeric(12,2),
  status public.order_status not null default 'pending',
  supplier_order_id text,
  failure_reason text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

alter table public.profiles enable row level security;
alter table public.wallets enable row level security;
alter table public.shop_settings enable row level security;
alter table public.wallet_topups enable row level security;
alter table public.wallet_ledger enable row level security;
alter table public.diamond_orders enable row level security;

create or replace function public.is_owner()
returns boolean language sql stable security definer set search_path = public
as $$ select exists (select 1 from public.profiles where id = auth.uid() and role = 'owner'); $$;

create policy "profile self or owner read" on public.profiles
  for select using (id = auth.uid() or public.is_owner());
create policy "wallet self or owner read" on public.wallets
  for select using (user_id = auth.uid() or public.is_owner());
create policy "settings visible to customers" on public.shop_settings
  for select using (auth.uid() is not null);
create policy "owner updates settings" on public.shop_settings
  for update using (public.is_owner()) with check (public.is_owner());
create policy "customer reads own topups" on public.wallet_topups
  for select using (user_id = auth.uid() or public.is_owner());
create policy "customer creates own pending topups" on public.wallet_topups
  for insert with check (user_id = auth.uid() and status = 'pending' and reviewed_by is null and reviewed_at is null);
create policy "owner reviews topups" on public.wallet_topups
  for update using (public.is_owner()) with check (public.is_owner());
create policy "customer reads own ledger" on public.wallet_ledger
  for select using (user_id = auth.uid() or public.is_owner());
create policy "customer reads own orders" on public.diamond_orders
  for select using (user_id = auth.uid() or public.is_owner());

-- SECURITY REQUIREMENT before launch:
-- Implement approval as a server-side database transaction / RPC:
-- 1) lock the top-up row and require status='pending';
-- 2) verify payment manually and calculate coins using the stored rate snapshot;
-- 3) update wallet, set status='approved', reviewed_by/reviewed_at, and insert one ledger row atomically;
-- 4) reject repeated approvals. Never allow browser clients to write wallet balances/ledger.
-- Add storage policies for private receipt uploads and server-side order debit/supplier API integration.
