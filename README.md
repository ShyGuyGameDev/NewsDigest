# NewsDigest

Send a news + fun facts digest email every Monday and Friday at 7:00 AM.

- **From/To:** shyguygamedev@gmail.com → shyguygamedev@gmail.com (send from and to the same address)
- **Schedule:** Every Monday and Friday at 7:00 AM
- **Coverage window:** Everything notable since the last digest (previous Friday for a Monday send, previous Monday for a Friday send)
- **Dedup:** Determine the last send by searching Gmail's sent folder for prior "News Digest: ..." subjects — do NOT rely on a repo file or git commit/push for history (the GitHub App for these routines is authorization-only and can't push commits)
- **Content, in this order:**
  1. Politics — major domestic and international developments
  2. Tech — notable launches, industry shifts, research breakthroughs
  3. Science — new discoveries, studies, space/health news
  4. Wildcard — anything else genuinely interesting (culture, sports, odd stories) that doesn't fit above
  5. Fun fact(s) — 1-3 surprising/delightful facts, unrelated to the news, as a lighter closer
- **Per-item format:** short headline + 2-4 sentence plain-language summary + source link. Assume no prior context.
- **Length:** signal over completeness — skimmable beats exhaustive. Cap each section at ~5-10 items.
- **Subject line:** "News Digest: <start date> – <end date>" (the range it covers) — kept consistent so it's searchable for dedup.
- **No git dependency:** no repo commits/pushes required for this routine to function.
