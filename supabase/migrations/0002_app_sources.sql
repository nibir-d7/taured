alter table apps add column if not exists source_url text;
alter table apps add column if not exists source_updated_at timestamptz;
create index if not exists apps_source_updated_at_idx on apps (source_updated_at desc);
