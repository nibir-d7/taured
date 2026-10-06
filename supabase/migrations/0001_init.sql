create table categories (
  id text primary key,
  name text not null,
  icon text
);

create table apps (
  id text primary key,
  name text not null,
  description text,
  category text references categories(id),
  icon text,
  verified boolean default false,
  win_winget text, win_choco text,
  linux_apt text, linux_dnf text, linux_pacman text, linux_flatpak text, linux_snap text,
  homepage text,
  created_at timestamptz default now()
);

create table templates (
  id text primary key,
  name text not null,
  description text,
  app_ids text[] not null,
  tweak_ids text[] default '{}'
);

create table packs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  description text,
  tags text[] default '{}',
  cover_url text,
  count int default 0,
  resolution text,
  license text default 'CC0',
  zip_url text,
  created_at timestamptz default now()
);

create table wallpapers (
  id uuid primary key default gen_random_uuid(),
  pack_id uuid references packs(id) on delete cascade,
  image_url text not null,
  width int, height int,
  size_kb int,
  created_at timestamptz default now()
);

alter table categories enable row level security;
alter table apps enable row level security;
alter table templates enable row level security;
alter table packs enable row level security;
alter table wallpapers enable row level security;

create policy "public read" on categories for select using (true);
create policy "public read" on apps for select using (true);
create policy "public read" on templates for select using (true);
create policy "public read" on packs for select using (true);
create policy "public read" on wallpapers for select using (true);

-- Replace with your admin email. Only that user (logged in via Supabase Auth) can write.
create policy "admin write" on categories for all using ((auth.jwt() ->> 'email') = 'admin@example.com') with check ((auth.jwt() ->> 'email') = 'admin@example.com');
create policy "admin write" on apps for all using ((auth.jwt() ->> 'email') = 'admin@example.com') with check ((auth.jwt() ->> 'email') = 'admin@example.com');
create policy "admin write" on templates for all using ((auth.jwt() ->> 'email') = 'admin@example.com') with check ((auth.jwt() ->> 'email') = 'admin@example.com');
create policy "admin write" on packs for all using ((auth.jwt() ->> 'email') = 'admin@example.com') with check ((auth.jwt() ->> 'email') = 'admin@example.com');
create policy "admin write" on wallpapers for all using ((auth.jwt() ->> 'email') = 'admin@example.com') with check ((auth.jwt() ->> 'email') = 'admin@example.com');

insert into storage.buckets (id, name, public) values ('wallpapers', 'wallpapers', true) on conflict do nothing;

create table admin_audit_log (
  id bigint generated always as identity primary key,
  table_name text,
  action text,
  record_id text,
  changed_by text default (auth.jwt() ->> 'email'),
  changed_at timestamptz default now()
);
alter table admin_audit_log enable row level security;
create policy "admin read audit" on admin_audit_log for select using ((auth.jwt() ->> 'email') = 'admin@example.com');

create or replace function audit_write() returns trigger language plpgsql security definer as $$
begin
  insert into admin_audit_log (table_name, action, record_id)
  values (TG_TABLE_NAME, TG_OP, coalesce(NEW.id::text, OLD.id::text));
  return coalesce(NEW, OLD);
end $$;

create trigger audit_apps after insert or update or delete on apps for each row execute function audit_write();
create trigger audit_packs after insert or update or delete on packs for each row execute function audit_write();
create trigger audit_wallpapers after insert or update or delete on wallpapers for each row execute function audit_write();
create trigger audit_templates after insert or update or delete on templates for each row execute function audit_write();

create policy "public read wallpapers bucket" on storage.objects for select using (bucket_id = 'wallpapers');
create policy "admin write wallpapers bucket" on storage.objects for all using (bucket_id = 'wallpapers' and (auth.jwt() ->> 'email') = 'admin@example.com') with check (bucket_id = 'wallpapers' and (auth.jwt() ->> 'email') = 'admin@example.com');
