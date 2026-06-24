-- Pin search_path on the trigger function (Supabase security lint 0011).
-- An empty search_path prevents a malicious schema from shadowing built-ins.
create or replace function set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
