-- Prerequisite: store the project's server-side Secret Key in Supabase Vault
-- with the name `cleanup_user_audio_secret_key`. Never put the key in this file.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

do $$
declare
  existing_job_id bigint;
begin
  for existing_job_id in
    select jobid
      from cron.job
     where jobname = 'cleanup-user-audio-hourly'
  loop
    perform cron.unschedule(existing_job_id);
  end loop;

  perform cron.schedule(
    'cleanup-user-audio-hourly',
    '17 * * * *',
    $cron$
      select net.http_post(
        url := 'https://vbnswvtycixwhvbwuoxz.supabase.co/functions/v1/cleanup-user-audio',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'apikey', (
            select decrypted_secret
              from vault.decrypted_secrets
             where name = 'cleanup_user_audio_secret_key'
             limit 1
          )
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 30000
      ) as request_id;
    $cron$
  );
end
$$;
