-- Run this in the Supabase SQL Editor before enabling sentence pronunciation
-- for all existing words. Each vocabulary meaning needs an English example.

select
  vc.id,
  coalesce(t.name, 'Chưa phân loại') as topic_name,
  vc.visibility,
  vc.word,
  vc.word_form,
  vc.e_example
from public.vocab_catalog as vc
left join public.topics as t on t.id = vc.topic_id
where nullif(btrim(coalesce(vc.e_example, '')), '') is null
order by topic_name, vc.word, vc.word_form;

-- Manual review only: these examples may still be valid when the word appears
-- in an inflected form. They are worth checking because iOS can only apply the
-- stored IPA when the target word appears as a whole word in the example.
select
  vc.id,
  coalesce(t.name, 'Chưa phân loại') as topic_name,
  vc.visibility,
  vc.word,
  vc.word_form,
  vc.e_example
from public.vocab_catalog as vc
left join public.topics as t on t.id = vc.topic_id
where nullif(btrim(coalesce(vc.e_example, '')), '') is not null
  and strpos(lower(vc.e_example), lower(vc.word)) = 0
order by topic_name, vc.word, vc.word_form;
