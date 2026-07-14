-- 20260526170000_initial_schema.sql
-- Baseline for schema "public" — backfilled 2026-07-14 via a direct pg_dump of
-- live project ryswtwcgzhmkmgzcklyx (supabase db dump --linked --schema public).
-- Reproduces the live public schema so `supabase db reset` can rebuild it.
-- The four intermediate migrations (coach_tables, the two RLS fixes, phase7 infra)
-- are subsumed here and emptied; 20260714000001_drop_duplicate_coach_rls.sql then
-- drops the duplicate coach policies to reach the live end state (one ALL policy
-- per coach table). See docs/phase7-remediation-plan.md item 2.




SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE OR REPLACE FUNCTION "public"."handle_auth_user_created"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  insert into public.users (id, email)
  values (new.id, new.email)
  on conflict (id) do update set email = excluded.email;

  return new;
end;
$$;


ALTER FUNCTION "public"."handle_auth_user_created"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."requesting_user_id"() RETURNS "text"
    LANGUAGE "sql" STABLE
    AS $$
  select nullif(current_setting('request.jwt.claims', true)::json->>'sub', '')::text
$$;


ALTER FUNCTION "public"."requesting_user_id"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."coach_conversations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "text" NOT NULL,
    "session_id" "uuid",
    "started_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."coach_conversations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."coach_messages" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "conversation_id" "uuid" NOT NULL,
    "user_id" "text" NOT NULL,
    "role" "text" NOT NULL,
    "content" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "coach_messages_role_check" CHECK (("role" = ANY (ARRAY['user'::"text", 'assistant'::"text"])))
);


ALTER TABLE "public"."coach_messages" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."integrations" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "provider" "text" NOT NULL,
    "access_token" "text",
    "refresh_token" "text",
    "token_expires_at" timestamp with time zone,
    "connected_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "provider_user_id" "text"
);


ALTER TABLE "public"."integrations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."macro_targets" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "target_date" "date" NOT NULL,
    "session_id" "uuid",
    "calories_kcal" integer,
    "carbs_g" integer,
    "protein_g" integer,
    "fat_g" integer,
    "target_type" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."macro_targets" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."meals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "text" NOT NULL,
    "meal_name" "text" NOT NULL,
    "meal_time" "text" NOT NULL,
    "estimated_macros" "jsonb",
    "portion_baseline" numeric DEFAULT 1,
    "is_active" boolean DEFAULT true,
    "sort_order" integer DEFAULT 0,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "meals_meal_time_check" CHECK (("meal_time" = ANY (ARRAY['breakfast'::"text", 'lunch'::"text", 'dinner'::"text", 'snack'::"text"])))
);


ALTER TABLE "public"."meals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."races" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "race_type" "text" NOT NULL,
    "race_name" "text",
    "race_date" "date" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL
);


ALTER TABLE "public"."races" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."training_sessions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "source" "text" NOT NULL,
    "session_date" "date" NOT NULL,
    "session_type" "text" NOT NULL,
    "distance_km" numeric(6,2),
    "duration_mins" integer,
    "status" "text" DEFAULT 'planned'::"text" NOT NULL,
    "strava_activity_id" "text",
    "perceived_exertion" integer,
    "created_at" timestamp with time zone DEFAULT "timezone"('utc'::"text", "now"()) NOT NULL,
    "runna_uid" "text"
);


ALTER TABLE "public"."training_sessions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "clerk_id" "text" NOT NULL,
    "email" "text",
    "height_cm" numeric,
    "weight_kg" numeric,
    "age" integer,
    "gender" "text",
    "units" "text" DEFAULT 'metric'::"text",
    "training_level" "text",
    "weekly_activities" "jsonb",
    "has_completed_onboarding" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "apns_device_token" "text"
);


ALTER TABLE "public"."users" OWNER TO "postgres";


ALTER TABLE ONLY "public"."coach_conversations"
    ADD CONSTRAINT "coach_conversations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."coach_messages"
    ADD CONSTRAINT "coach_messages_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."integrations"
    ADD CONSTRAINT "integrations_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."macro_targets"
    ADD CONSTRAINT "macro_targets_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."meals"
    ADD CONSTRAINT "meals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."races"
    ADD CONSTRAINT "races_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."training_sessions"
    ADD CONSTRAINT "training_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_clerk_id_key" UNIQUE ("clerk_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



CREATE INDEX "coach_conversations_session_idx" ON "public"."coach_conversations" USING "btree" ("session_id");



CREATE INDEX "coach_conversations_user_id_idx" ON "public"."coach_conversations" USING "btree" ("user_id");



CREATE INDEX "coach_messages_conversation_date" ON "public"."coach_messages" USING "btree" ("conversation_id", "created_at");



CREATE INDEX "coach_messages_conversation_idx" ON "public"."coach_messages" USING "btree" ("conversation_id", "created_at");



CREATE INDEX "integrations_provider_user_id_idx" ON "public"."integrations" USING "btree" ("provider", "provider_user_id");



CREATE UNIQUE INDEX "integrations_user_provider_idx" ON "public"."integrations" USING "btree" ("user_id", "provider");



CREATE UNIQUE INDEX "macro_targets_user_date_idx" ON "public"."macro_targets" USING "btree" ("user_id", "target_date");



CREATE INDEX "meals_user_id_idx" ON "public"."meals" USING "btree" ("user_id");



CREATE UNIQUE INDEX "races_single_active_per_user_idx" ON "public"."races" USING "btree" ("user_id") WHERE ("is_active" = true);



CREATE UNIQUE INDEX "training_sessions_user_runna_uid_idx" ON "public"."training_sessions" USING "btree" ("user_id", "runna_uid") WHERE ("runna_uid" IS NOT NULL);



CREATE UNIQUE INDEX "training_sessions_user_strava_activity_idx" ON "public"."training_sessions" USING "btree" ("user_id", "strava_activity_id") WHERE ("strava_activity_id" IS NOT NULL);



ALTER TABLE ONLY "public"."coach_conversations"
    ADD CONSTRAINT "coach_conversations_session_fk" FOREIGN KEY ("session_id") REFERENCES "public"."training_sessions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."coach_conversations"
    ADD CONSTRAINT "coach_conversations_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."training_sessions"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."coach_messages"
    ADD CONSTRAINT "coach_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "public"."coach_conversations"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."macro_targets"
    ADD CONSTRAINT "macro_targets_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "public"."training_sessions"("id") ON DELETE SET NULL;



CREATE POLICY "Users manage own conversations" ON "public"."coach_conversations" USING (("public"."requesting_user_id"() = "user_id"));



CREATE POLICY "Users manage own messages" ON "public"."coach_messages" USING (("public"."requesting_user_id"() = "user_id"));



ALTER TABLE "public"."coach_conversations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "coach_conversations_manage_own" ON "public"."coach_conversations" USING (("public"."requesting_user_id"() = "user_id")) WITH CHECK (("public"."requesting_user_id"() = "user_id"));



ALTER TABLE "public"."coach_messages" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "coach_messages_manage_own" ON "public"."coach_messages" USING (("public"."requesting_user_id"() = "user_id")) WITH CHECK (("public"."requesting_user_id"() = "user_id"));



ALTER TABLE "public"."integrations" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "integrations_manage_own" ON "public"."integrations" USING (("user_id" = ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."clerk_id" = "public"."requesting_user_id"()))));



ALTER TABLE "public"."macro_targets" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "macro_targets_manage_own" ON "public"."macro_targets" USING (("user_id" = ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."clerk_id" = "public"."requesting_user_id"()))));



ALTER TABLE "public"."meals" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "meals_manage_own" ON "public"."meals" USING (("public"."requesting_user_id"() = "user_id")) WITH CHECK (("public"."requesting_user_id"() = "user_id"));



ALTER TABLE "public"."races" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "races_manage_own" ON "public"."races" USING (("user_id" = ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."clerk_id" = "public"."requesting_user_id"()))));



ALTER TABLE "public"."training_sessions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "training_sessions_manage_own" ON "public"."training_sessions" USING (("user_id" = ( SELECT "users"."id"
   FROM "public"."users"
  WHERE ("users"."clerk_id" = "public"."requesting_user_id"()))));



ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "users: select own row" ON "public"."users" FOR SELECT USING (("clerk_id" = "public"."requesting_user_id"()));



CREATE POLICY "users: update own row" ON "public"."users" FOR UPDATE USING (("clerk_id" = "public"."requesting_user_id"())) WITH CHECK (("clerk_id" = "public"."requesting_user_id"()));



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."handle_auth_user_created"() TO "anon";
GRANT ALL ON FUNCTION "public"."handle_auth_user_created"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."handle_auth_user_created"() TO "service_role";



GRANT ALL ON FUNCTION "public"."requesting_user_id"() TO "anon";
GRANT ALL ON FUNCTION "public"."requesting_user_id"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."requesting_user_id"() TO "service_role";



GRANT ALL ON TABLE "public"."coach_conversations" TO "anon";
GRANT ALL ON TABLE "public"."coach_conversations" TO "authenticated";
GRANT ALL ON TABLE "public"."coach_conversations" TO "service_role";



GRANT ALL ON TABLE "public"."coach_messages" TO "anon";
GRANT ALL ON TABLE "public"."coach_messages" TO "authenticated";
GRANT ALL ON TABLE "public"."coach_messages" TO "service_role";



GRANT ALL ON TABLE "public"."integrations" TO "anon";
GRANT ALL ON TABLE "public"."integrations" TO "authenticated";
GRANT ALL ON TABLE "public"."integrations" TO "service_role";



GRANT ALL ON TABLE "public"."macro_targets" TO "anon";
GRANT ALL ON TABLE "public"."macro_targets" TO "authenticated";
GRANT ALL ON TABLE "public"."macro_targets" TO "service_role";



GRANT ALL ON TABLE "public"."meals" TO "anon";
GRANT ALL ON TABLE "public"."meals" TO "authenticated";
GRANT ALL ON TABLE "public"."meals" TO "service_role";



GRANT ALL ON TABLE "public"."races" TO "anon";
GRANT ALL ON TABLE "public"."races" TO "authenticated";
GRANT ALL ON TABLE "public"."races" TO "service_role";



GRANT ALL ON TABLE "public"."training_sessions" TO "anon";
GRANT ALL ON TABLE "public"."training_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."training_sessions" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";







