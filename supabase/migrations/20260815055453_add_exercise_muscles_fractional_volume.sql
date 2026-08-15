-- Fractional volume crediting.
--
-- exercises.primary_muscle credits one prime mover per set, which understates
-- reality: a hip thrust does train hamstrings, an RDL does train glutes.
-- This table lets a set credit multiple muscles at weighted values.
--
-- CONVENTION: contribution is 1.0 (direct) or 0.5 (indirect). Nothing else.
-- This is the "fractional" quantification method from Pelland et al. 2025
-- (Sports Medicine), which found distinguishing direct from indirect sets
-- essential for predicting adaptation, and had stronger evidence than either
-- counting indirect sets fully or ignoring them. Finer gradations imply a
-- precision the evidence does not support.
--
-- exercises.primary_muscle is retained as the denormalized prime mover for
-- simple grouping. Every exercise with a primary_muscle has a matching 1.0 row
-- here; the trigger below keeps them from drifting apart.

-- Correct a misclassification: trap-bar deadlift is conventionally glute/ham
-- dominant, not erector-dominant. Erectors become a secondary contributor.
update public.exercises set primary_muscle = 'glute_max'
where id = '862af51d-64d7-4616-9e76-7186a110c7c1';

create table public.exercise_muscles (
  exercise_id uuid not null references public.exercises(id) on delete cascade,
  muscle public.muscle_group not null,
  contribution numeric(2,1) not null,
  primary key (exercise_id, muscle),
  constraint exercise_muscles_contribution_check
    check (contribution in (0.5, 1.0))
);

comment on table public.exercise_muscles is
  'Fractional volume credit per muscle. 1.0 = direct, 0.5 = indirect '
  '(fractional method, Pelland et al. 2025). Every exercise with a '
  'primary_muscle has a 1.0 row for that muscle.';

alter table public.exercise_muscles enable row level security;
create policy exercise_muscles_select on public.exercise_muscles
  for select to authenticated using (true);

create index exercise_muscles_muscle_idx on public.exercise_muscles (muscle);

-- 1. Every primary_muscle becomes a direct (1.0) credit.
insert into public.exercise_muscles (exercise_id, muscle, contribution)
select id, primary_muscle, 1.0
from public.exercises
where primary_muscle is not null;

-- 2. Indirect (0.5) contributions.
insert into public.exercise_muscles (exercise_id, muscle, contribution)
select v.id::uuid, v.m::public.muscle_group, 0.5
from (values
  -- Hip thrusts: hamstrings assist hip extension
  ('b001d7b2-03d8-4bac-a710-17a8ef9f78b7','hamstrings'),
  ('8c810452-ea9a-4654-9acf-3a5edfabfd88','hamstrings'),
  ('5f8cfd9e-6b2b-4a5a-9206-82919b27843b','hamstrings'),
  ('bbfef5ef-12c8-4e32-83e3-434ca3e98517','hamstrings'),
  ('bbfef5ef-12c8-4e32-83e3-434ca3e98517','glute_med'),
  -- Back extension
  ('009f5351-9d4d-43b7-b65e-f4d1231e3122','hamstrings'),
  ('009f5351-9d4d-43b7-b65e-f4d1231e3122','erectors'),
  -- Leg press glute bias
  ('271e539e-7b7d-4571-bbc0-1bd33b6f3c25','quads'),
  ('271e539e-7b7d-4571-bbc0-1bd33b6f3c25','adductors'),
  -- RDLs: glutes + erectors
  ('a97f31c5-cfb4-4a4b-aca9-aff7087456de','glute_max'),
  ('a97f31c5-cfb4-4a4b-aca9-aff7087456de','erectors'),
  ('88513369-c1a3-4565-9ebe-b7dd3a5a2a4d','glute_max'),
  ('88513369-c1a3-4565-9ebe-b7dd3a5a2a4d','erectors'),
  ('4f187d24-b0fa-4fe6-b58c-12f41bee80f2','glute_max'),
  ('4f187d24-b0fa-4fe6-b58c-12f41bee80f2','erectors'),
  -- Single-leg RDLs add frontal-plane stabilization
  ('6e3220e1-92da-4688-9486-532951eb7dbd','glute_max'),
  ('6e3220e1-92da-4688-9486-532951eb7dbd','erectors'),
  ('6e3220e1-92da-4688-9486-532951eb7dbd','glute_med'),
  ('1063ef1c-7ce1-40b4-851d-386087d818b9','glute_max'),
  ('1063ef1c-7ce1-40b4-851d-386087d818b9','erectors'),
  ('1063ef1c-7ce1-40b4-851d-386087d818b9','glute_med'),
  ('3a022b2d-4d2e-4658-aa9d-73441152fde9','glute_max'),
  ('3a022b2d-4d2e-4658-aa9d-73441152fde9','glute_med'),
  ('095dd98d-0f5d-407d-bf91-8d14a684760d','glute_max'),
  ('095dd98d-0f5d-407d-bf91-8d14a684760d','glute_med'),
  -- Trap-bar deadlift: broadest compound in the library
  ('862af51d-64d7-4616-9e76-7186a110c7c1','hamstrings'),
  ('862af51d-64d7-4616-9e76-7186a110c7c1','quads'),
  ('862af51d-64d7-4616-9e76-7186a110c7c1','erectors'),
  -- Squats
  ('8f354967-8152-49ef-96a8-d52cec2027bf','glute_max'),
  ('8f354967-8152-49ef-96a8-d52cec2027bf','adductors'),
  ('f6e838ec-fcd5-4a68-8bf0-99dce91e4aba','glute_max'),
  ('082dccbe-c9a0-4ad8-8bd4-6cb869387a32','glute_max'),
  ('082dccbe-c9a0-4ad8-8bd4-6cb869387a32','adductors'),
  ('082dccbe-c9a0-4ad8-8bd4-6cb869387a32','core'),
  -- Lunges / split squats
  ('66b17d52-35ae-4bf1-8a8e-a9037d3e8f7c','glute_max'),
  ('66b17d52-35ae-4bf1-8a8e-a9037d3e8f7c','glute_med'),
  ('ee7c493e-c03a-418b-b2c1-edbb8f82f80a','glute_max'),
  ('ee7c493e-c03a-418b-b2c1-edbb8f82f80a','glute_med'),
  ('5fd79726-53a3-47d4-b074-5a6d57948b98','glute_max'),
  ('5fd79726-53a3-47d4-b074-5a6d57948b98','glute_med'),
  ('03e946ae-d6dc-480d-b857-af955939161a','glute_max'),
  ('03e946ae-d6dc-480d-b857-af955939161a','glute_med'),
  ('534bea7d-cd9e-46ff-bda8-81aac097476d','quads'),
  ('534bea7d-cd9e-46ff-bda8-81aac097476d','glute_med'),
  -- Abduction: leaned-forward and standing bias upper glute max
  ('27029387-e3d2-4687-a940-256c9b728fdf','glute_max'),
  ('6467a792-434b-497f-a17d-b66e74529615','glute_max'),
  -- Horizontal press
  ('cfb27746-56c3-4197-a488-ebf92fe42c69','triceps'),
  ('cfb27746-56c3-4197-a488-ebf92fe42c69','front_delt'),
  ('23854acb-b1dd-4e44-8565-2bbf41210f46','triceps'),
  ('23854acb-b1dd-4e44-8565-2bbf41210f46','front_delt'),
  ('3d164e4f-eef3-4e3d-95bb-e194a2b6f1f6','triceps'),
  ('3d164e4f-eef3-4e3d-95bb-e194a2b6f1f6','front_delt'),
  ('b58864f0-f8e5-4a31-989d-234c2a17ee43','triceps'),
  ('b58864f0-f8e5-4a31-989d-234c2a17ee43','front_delt'),
  ('b58864f0-f8e5-4a31-989d-234c2a17ee43','core'),
  -- Vertical press
  ('4ca03254-32d4-472f-9d68-ca19140ae41b','triceps'),
  ('4ca03254-32d4-472f-9d68-ca19140ae41b','side_delt'),
  ('4c3af91b-50fa-4c73-9702-74a5ad8f4cc3','triceps'),
  ('4c3af91b-50fa-4c73-9702-74a5ad8f4cc3','side_delt'),
  ('2f31e275-037e-488f-9bda-c1c8230a0174','triceps'),
  ('2f31e275-037e-488f-9bda-c1c8230a0174','core'),
  ('21982966-89f0-4d85-a102-989b59283aca','triceps'),
  ('21982966-89f0-4d85-a102-989b59283aca','core'),
  -- Vertical pull
  ('c05d28f5-4832-4933-a650-da951018754a','biceps'),
  ('c05d28f5-4832-4933-a650-da951018754a','upper_back'),
  ('1d0fa119-5970-46b9-aae7-8a74843a1c22','biceps'),
  ('1d0fa119-5970-46b9-aae7-8a74843a1c22','upper_back'),
  ('70172133-ebe0-46bd-86fe-0366b8cb9968','biceps'),
  ('70172133-ebe0-46bd-86fe-0366b8cb9968','upper_back'),
  ('79ccd8c6-8bcb-42f4-b422-7b40bd568e1e','biceps'),
  ('79ccd8c6-8bcb-42f4-b422-7b40bd568e1e','upper_back'),
  ('b1c1fafe-b2d1-4361-b512-ef866997d176','biceps'),
  ('b1c1fafe-b2d1-4361-b512-ef866997d176','upper_back'),
  -- Horizontal pull
  ('14ad2960-dab1-4617-a0de-ae3f255f4d1a','biceps'),
  ('14ad2960-dab1-4617-a0de-ae3f255f4d1a','rear_delt'),
  ('3c9392f7-2920-43a7-abdc-5c00eb49769e','biceps'),
  ('3c9392f7-2920-43a7-abdc-5c00eb49769e','rear_delt'),
  ('3c9392f7-2920-43a7-abdc-5c00eb49769e','lats'),
  ('a06a62a7-a56e-4483-b9ed-886b05da6bd9','biceps'),
  ('a06a62a7-a56e-4483-b9ed-886b05da6bd9','rear_delt'),
  ('a06a62a7-a56e-4483-b9ed-886b05da6bd9','lats'),
  ('9d548fdb-2f31-4542-a9cf-a79498ee7111','biceps'),
  ('9d548fdb-2f31-4542-a9cf-a79498ee7111','rear_delt'),
  ('9d548fdb-2f31-4542-a9cf-a79498ee7111','lats'),
  ('6f9de57d-138f-4bab-afc0-b3a70c0979dd','biceps'),
  ('6f9de57d-138f-4bab-afc0-b3a70c0979dd','lats'),
  ('9f96a86d-6a99-428e-9be4-a5c8218519b8','biceps'),
  ('9f96a86d-6a99-428e-9be4-a5c8218519b8','rear_delt'),
  ('6753098f-43d0-40fc-9c96-278458ae02db','biceps'),
  ('6753098f-43d0-40fc-9c96-278458ae02db','lats'),
  ('c41ab282-0e2e-4afe-9a1e-8b14c7d8f404','biceps'),
  ('c41ab282-0e2e-4afe-9a1e-8b14c7d8f404','lats'),
  ('440db5a9-f0de-4651-8b08-e88bfcf2a73f','biceps'),
  ('440db5a9-f0de-4651-8b08-e88bfcf2a73f','lats'),
  ('440db5a9-f0de-4651-8b08-e88bfcf2a73f','core'),
  -- Rear delt work also hits mid-back
  ('45fad97f-856d-4946-809b-39d6e389b2bc','upper_back'),
  ('ba854cbe-e91b-46cf-b8e5-7e52657676b9','upper_back'),
  ('ba854cbe-e91b-46cf-b8e5-7e52657676b9','rotator_cuff'),
  ('03f9d2cd-c273-4783-8c6b-782363831c42','upper_back'),
  ('acdee471-650e-472f-83e7-5268c6a90751','upper_back'),
  ('acdee471-650e-472f-83e7-5268c6a90751','rotator_cuff'),
  -- Scaption
  ('7f5ea840-a4e2-4d5a-95e7-9d4b48d8fba8','rotator_cuff'),
  -- Carry
  ('e29b3187-9e9c-4908-91d6-2f03a08264b4','upper_back')
) as v(id, m);

-- Keep primary_muscle and the 1.0 row from drifting apart.
create or replace function public.sync_primary_muscle_credit()
returns trigger
language plpgsql
set search_path to ''
as $function$
begin
  if new.primary_muscle is distinct from old.primary_muscle then
    if old.primary_muscle is not null then
      delete from public.exercise_muscles
      where exercise_id = new.id and muscle = old.primary_muscle
        and contribution = 1.0;
    end if;
    if new.primary_muscle is not null then
      insert into public.exercise_muscles (exercise_id, muscle, contribution)
      values (new.id, new.primary_muscle, 1.0)
      on conflict (exercise_id, muscle)
        do update set contribution = 1.0;
    end if;
  end if;
  return new;
end;
$function$;

create trigger exercises_sync_primary_muscle_credit
  after update on public.exercises
  for each row
  execute function public.sync_primary_muscle_credit();
