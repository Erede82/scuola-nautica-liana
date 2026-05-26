create or replace function public.is_school_staff()
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists (
    select 1
    from public.school_user_roles sur
    where sur.user_id = auth.uid()
      and sur.role in ('admin', 'staff', 'school_admin')
  );
$function$;
