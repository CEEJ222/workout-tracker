-- Theme preference. Three states, not two: 'system' is the default and defers to
-- prefers-color-scheme; 'light' and 'dark' are explicit overrides. A two-state
-- boolean cannot express "follow the device", which is what most users want and
-- what the app should do before anyone touches a toggle.

create type public.theme_preference as enum ('system', 'light', 'dark');

alter table public.user_settings
  add column theme public.theme_preference not null default 'system';

comment on column public.user_settings.theme is
  'Theme preference. ''system'' (default) defers to prefers-color-scheme; '
  '''light''/''dark'' are explicit user overrides that win over the device setting.';
