-- ROAD BUSINESS : témoignages publics et coordonnées privées.
-- À exécuter une seule fois dans Supabase > SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.testimonials (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (char_length(trim(full_name)) between 2 and 80),
  location text not null check (char_length(trim(location)) between 2 and 80),
  phone text not null check (char_length(trim(phone)) between 5 and 40),
  email text check (email is null or char_length(email) <= 120),
  rating smallint not null check (rating between 1 and 5),
  message text not null check (char_length(trim(message)) between 10 and 600),
  photo_url text,
  consent boolean not null default false,
  is_published boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.testimonials enable row level security;
revoke all on public.testimonials from anon, authenticated;
grant insert on public.testimonials to anon;

drop policy if exists "Public can submit consented testimonials" on public.testimonials;
create policy "Public can submit consented testimonials"
on public.testimonials for insert to anon
with check (consent = true and is_published = true);

-- La vue ne contient volontairement aucun téléphone ni e-mail.
create or replace view public.public_testimonials
with (security_invoker = false) as
select id, full_name, location, rating, message, photo_url, created_at
from public.testimonials
where is_published = true and consent = true;

revoke all on public.public_testimonials from public;
grant select on public.public_testimonials to anon;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('testimonial-photos', 'testimonial-photos', true, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 3145728,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

grant insert on storage.objects to anon;

drop policy if exists "Public can upload testimonial photos" on storage.objects;
create policy "Public can upload testimonial photos"
on storage.objects for insert to anon
with check (bucket_id = 'testimonial-photos');
