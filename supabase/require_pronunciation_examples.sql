-- Enforce the new pronunciation prerequisite for every future write.
-- NOT VALID keeps existing legacy rows untouched, while new inserts and
-- updates must include a non-blank English example.

alter table public.vocab_catalog
  drop constraint if exists vocab_catalog_e_example_required;

alter table public.vocab_catalog
  add constraint vocab_catalog_e_example_required
  check (nullif(btrim(coalesce(e_example, '')), '') is not null) not valid;

alter table public.topic_submission_words
  drop constraint if exists topic_submission_words_e_example_required;

alter table public.topic_submission_words
  add constraint topic_submission_words_e_example_required
  check (nullif(btrim(coalesce(e_example, '')), '') is not null) not valid;
