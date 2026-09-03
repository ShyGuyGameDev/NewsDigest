# NewsDigest

Send a news + fun fact digest email every Monday, Wednesday, and Friday at 7:00 AM.

- **From/To:** shyguygamedev@gmail.com → shyguygamedev@gmail.com (send from and to the same address)
- **Schedule:** Every Monday, Wednesday, and Friday at 7:00 AM (America/Los_Angeles)
- **Coverage window:** Everything notable since the last digest — from the end date of the most recent genuine digest send through today (roughly the last 2-3 days)
- **Dedup:** Determine the last send by searching Gmail's sent folder for prior "News Digest: ..." subjects — do NOT rely on a repo file or git commit/push for history (the GitHub App for these routines is authorization-only and can't push commits)
- **Content, in this order (exactly 3 items per news category, exactly 1 fun fact):**
  1. Politics — major domestic and international developments
  2. Tech — notable launches, industry shifts, research breakthroughs
  3. Science — new discoveries, studies, space/health news
  4. Business — markets and the economy: earnings, M&A/IPOs, central-bank and rate moves, economic data (jobs, inflation, GDP), major corporate news, layoffs, antitrust/regulatory action, commodities/energy
  5. Wildcard — anything else genuinely interesting (culture, sports, odd stories) that doesn't fit above
  6. Fun fact — exactly 1 fact, unrelated to the news, as a lighter closer. It must be genuinely surprising (not common knowledge) AND verifiable against a reputable source (link it). **Never repeat a fact from any previous digest** — before choosing, the agent builds the list of already-used facts from **every past digest, not just the recent ones** (see "Checking past fun facts" below) and excludes any fact already used, including trivial rewordings. Vary the topic area from recent sends rather than leaning on one repeatedly.
- **Per-item format:** short headline + 2-4 sentence plain-language summary + source link. Assume no prior context.
- **Length:** every news category carries **exactly 3 items** — pick the 3 most significant developments in the window and cut the rest. If fewer than 3 genuinely notable things happened in a category, fill with the next-most-relevant story rather than dropping below 3. Fun fact section is always exactly 1.
- **Subject line:** "News Digest: <start date> – <end date>" (the range it covers) — kept consistent so it's searchable for dedup.
- **No git dependency:** no repo commits/pushes required for this routine to function.

## Recipients

The recipient list is driven entirely by Gmail — no addresses are stored in this repo.

- **Base recipient:** shyguygamedev@gmail.com (always included).
- **Anchor email:** the original digest with the exact subject `News Digest: Aug 28 – Aug 31, 2026` (the first test send).
- **Adding subscribers:** from the shyguygamedev@gmail.com mailbox (the account the Gmail connector is attached to), **forward** the anchor email to whoever should receive the digest. Keep Gmail's default `Fwd:` prefix; do not edit the rest of the subject line.
- **How the list is built each run:** before sending, the agent finds the anchor thread and fetches the **entire thread** (`get_thread`), then walks **every message in it**. It counts **only forwards of that one specific anchor digest, sent from shyguygamedev@gmail.com** — a message qualifies when its sender is shyguygamedev@gmail.com and its subject is exactly `Fwd: News Digest: Aug 28 – Aug 31, 2026`. Replies, reply-all Cc additions, the original anchor email, and forwards of any other digest are all ignored. From each qualifying forward it collects the To/Cc/Bcc addresses, lowercases, dedupes, and drops shyguygamedev@gmail.com. The result is the extra subscriber list.
- **Do NOT build the list from `search_threads` / `search` results alone.** That search truncates the messages it returns per thread (only ~5), so forwards silently go missing once more than a handful of people have been added. Use it only to locate the anchor thread's ID, then read the full thread with `get_thread` and enumerate messages from there. Cross-check that the number of `Fwd:` messages you processed matches what the thread actually contains.
- **The list is re-derived from scratch on every run** — forward the anchor to more people at any time and they are automatically included on the next send.
- **Trashed forwards don't count:** a `Fwd:` anchor message sitting in Trash is treated as a pending removal — skip its recipients when building the list.
- **Send format:** one email per run, `To:` shyguygamedev@gmail.com and `Bcc:` all extra subscribers (Bcc so subscribers can't see each other's addresses).
- **Always double-check the Bcc list before every send:** after deriving the list, re-fetch the full anchor thread with `get_thread`, list every `Fwd:` message and its recipients, and confirm each resolved Bcc address traces back to a qualifying, non-trashed forward — and that no such forward was missed. Never send with an unverified list.
- **Removing a subscriber:** delete that person's forward (the `Fwd: News Digest: Aug 28 – Aug 31, 2026` message) from All Mail, including Trash.

## Supabase (subscriber store) — NOT IN USE

The recipient list currently comes entirely from Gmail (above). Supabase is **not**
wired into the routine.

A schema for a future subscriber store lives in [`supabase/schema.sql`](supabase/schema.sql),
and the full from-scratch setup procedure is in [`supabase/SETUP.md`](supabase/SETUP.md).
Do not follow those steps until you actually intend to switch the routine off Gmail.

## Dedup

The "last send" lookup searches `in:sent subject:"News Digest:" -subject:Fwd -subject:Re -subject:TEST` so that forwards, replies, and `[TEST]` sends don't get mistaken for a prior genuine digest. A run stops only if a genuine digest whose coverage window ends today (or later) already went out.

## Checking past fun facts

The no-repeat rule only works if **all** past digests are checked, not the first page of results.

- Search `in:sent subject:"News Digest:" -subject:Fwd -subject:Re -subject:TEST` and **page all the way through** — keep following `pageToken`/next-page until there are no more results. Don't rely on a single search call or on snippets.
- For each genuine digest found, fetch its **full body** (`get_message` / `get_thread`, plain-text format) — snippets are truncated and will hide the fun-fact section.
- Extract every fun fact from every digest into one running list, then exclude any candidate that matches one already used, including trivial rewordings or the same fact with a different number/framing.
- Sanity-check: the number of digests you pulled facts from should match the number of genuine past sends. If it doesn't, you missed some — redo the enumeration before choosing.
