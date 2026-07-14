-- Drop the duplicate coach-table RLS policies (the originals from
-- 20260629000001_coach_tables.sql, which lack WITH CHECK), keeping the
-- "*_manage_own" versions that include WITH CHECK. Ends at exactly one
-- ALL policy per coach table. Policy names verified against the live
-- schema dump, 2026-07-14 (audit §4; docs/phase7-remediation-plan.md item 5).
drop policy if exists "Users manage own conversations" on "public"."coach_conversations";
drop policy if exists "Users manage own messages"      on "public"."coach_messages";
