# NewsDigest

Send a news + fun facts digest email every Monday, Wednesday, and Friday at 7:00 AM.

- **From/To:** shyguygamedev@gmail.com → shyguygamedev@gmail.com (send from and to the same address)
- **Schedule:** Every Monday, Wednesday, and Friday at 7:00 AM (America/Los_Angeles)
- **Coverage window:** Everything notable since the last digest — from the end date of the most recent genuine digest send through today (roughly the last 2-3 days)
- **Dedup:** Determine the last send by searching Gmail's sent folder for prior "News Digest: ..." subjects — do NOT rely on a repo file or git commit/push for history (the GitHub App for these routines is authorization-only and can't push commits)
- **Content, in this order:**
  1. Politics — major domestic and international developments
  2. Tech — notable launches, industry shifts, research breakthroughs
  3. Science — new discoveries, studies, space/health news
  4. Business — markets and the economy: earnings, M&A/IPOs, central-bank and rate moves, economic data (jobs, inflation, GDP), major corporate news, layoffs, antitrust/regulatory action, commodities/energy
  5. Wildcard — anything else genuinely interesting (culture, sports, odd stories) that doesn't fit above
  6. Fun fact(s) — 1-3 facts, unrelated to the news, as a lighter closer. Each must be genuinely surprising (not common knowledge) AND verifiable against a reputable source (link it). **Never repeat a fact from any previous digest** — before choosing, the agent pulls the bodies of past digests (from the same `News Digest:` sent-mail search) and excludes any fact already used, including trivial rewordings. Mix up the topic areas across sends rather than leaning on one repeatedly; a shared domain within a single send is fine if both facts are strong.
- **Per-item format:** short headline + 2-4 sentence plain-language summary + source link. Assume no prior context.
- **Length:** signal over completeness — skimmable beats exhaustive. Cap each section at ~5-10 items.
- **Subject line:** "News Digest: <start date> – <end date>" (the range it covers) — kept consistent so it's searchable for dedup.
- **No git dependency:** no repo commits/pushes required for this routine to function.

## Recipients

The recipient list is driven entirely by Gmail — no addresses are stored in this repo.

- **Base recipient:** shyguygamedev@gmail.com (always included).
- **Anchor email:** the original digest with the exact subject `News Digest: Aug 28 – Aug 31, 2026` (the first test send).
- **Adding subscribers:** from the shyguygamedev@gmail.com mailbox (the account the Gmail connector is attached to), **forward** the anchor email to whoever should receive the digest. Keep Gmail's default `Fwd:` prefix; do not edit the rest of the subject line.
- **How the list is built each run:** before sending, the agent searches `from:shyguygamedev@gmail.com subject:"Fwd: News Digest: Aug 28 – Aug 31, 2026"`. It counts **only forwards of that one specific anchor digest, sent from shyguygamedev@gmail.com** — replies, reply-all Cc additions, the original anchor email, and forwards of any other digest are all ignored. From each qualifying forward it collects the To/Cc/Bcc addresses, lowercases, dedupes, and drops shyguygamedev@gmail.com. The result is the extra subscriber list.
- **The list is re-derived from scratch on every run** — forward the anchor to more people at any time and they are automatically included on the next send.
- **Send format:** one email per run, `To:` shyguygamedev@gmail.com and `Bcc:` all extra subscribers (Bcc so subscribers can't see each other's addresses).
- **Removing a subscriber:** delete that person's forward (the `Fwd: News Digest: Aug 28 – Aug 31, 2026` message) from All Mail, including Trash.

## Dedup

The "last send" lookup searches `in:sent subject:"News Digest:" -subject:Fwd -subject:Re -subject:TEST` so that forwards, replies, and `[TEST]` sends don't get mistaken for a prior genuine digest. A run stops only if a genuine digest whose coverage window ends today (or later) already went out.
