# NewsDigest

Send a news + fun fact digest email every Monday, Wednesday, and Friday at 6:45 AM.

- **From/To:** shyguygamedev@gmail.com → shyguygamedev@gmail.com (send from and to the same address)
- **Schedule:** Every Monday, Wednesday, and Friday at 6:45 AM (America/Los_Angeles). Cron is `45 13 * * 1,3,5` (UTC, matches 6:45 AM PDT; will land at 5:45 AM once PST begins in November).
- **Coverage window:** Everything notable since the last digest — from the end date of the most recent genuine digest send through today (roughly the last 2-3 days)
- **Dedup:** Determine the last send by searching Gmail's sent folder for prior "News Digest: ..." subjects — do NOT rely on a repo file or git commit/push for history (the GitHub App for these routines is authorization-only and can't push commits)
- **Content, in this order (exactly 3 items per news category, exactly 1 fun fact):**
  1. Politics — major domestic and international developments
  2. Tech — notable launches, industry shifts, research breakthroughs
  3. Science — new discoveries, studies, space/health news
  4. Business — markets and the economy: earnings, M&A/IPOs, central-bank and rate moves, economic data (jobs, inflation, GDP), major corporate news, layoffs, antitrust/regulatory action, commodities/energy
  5. Wildcard — anything else genuinely interesting (culture, sports, odd stories) that doesn't fit above
  6. Fun fact — exactly 1 fact, unrelated to the news, as a lighter closer. It must be genuinely surprising (not common knowledge) AND verifiable against a reputable source (link it). **Never repeat a fact from any previous digest** — before choosing, the agent builds the list of already-used facts from **every past digest, not just the recent ones** (see "Checking past fun facts" below) and excludes any fact already used, including trivial rewordings. Vary the topic area from recent sends rather than leaning on one repeatedly.
- **Per-item content:** short headline + 2-4 sentence plain-language summary + source link. Assume no prior context.
- **Length:** every news category carries **exactly 3 items** — pick the 3 most significant developments in the window and cut the rest. If fewer than 3 genuinely notable things happened in a category, fill with the next-most-relevant story rather than dropping below 3. Fun fact section is always exactly 1.
- **Formatting:** the email is **rich HTML** — see [Email format](#email-format) for the exact template. Bold headlines, hyperlinked source names, section headers with emojis, line breaks between lines. Never send a plain-text-only digest.
- **Subject line:** "News Digest: <start date> – <end date>" (the range it covers) — kept consistent so it's searchable for dedup.
- **No git dependency:** no repo commits/pushes required for this routine to function.

## Recipients

The digest goes to a fixed base address plus a subscriber list stored in Supabase. No email addresses are stored in this repo.

- **Base recipient:** shyguygamedev@gmail.com — always in `To:`.
- **Subscriber list:** the `public.subscribers` table in Supabase. Each row stores `email_enc` — the address encrypted with Fernet. No plaintext address is stored anywhere.
- **Environment (set in the routine's settings, not this repo):**
  - `SUPABASE_URL` — the project URL
  - `SUPABASE_PUBLISHABLE_KEY` — read-only publishable key. Safe to expose: RLS limits it to `SELECT` of `email_hash, email_enc, created_at` and permits no writes.
  - `EMAIL_ENC_KEY` — Fernet key that decrypts `email_enc`.
- **How the list is built each run:**
  1. `GET $SUPABASE_URL/rest/v1/subscribers?select=email_enc` with headers `apikey: $SUPABASE_PUBLISHABLE_KEY` and `Authorization: Bearer $SUPABASE_PUBLISHABLE_KEY`.
  2. Decrypt every `email_enc` with `EMAIL_ENC_KEY` (Python: `cryptography.fernet.Fernet`; `pip install cryptography` in the setup step if needed).
  3. Lowercase, trim, dedupe, drop shyguygamedev@gmail.com. The remainder is the Bcc list.
- **Send format:** one email per run via the Gmail connector — `To:` shyguygamedev@gmail.com, `Bcc:` the decrypted subscriber list (Bcc so subscribers can't see each other's addresses). Pass the digest as **`htmlBody`** (the [Email format](#email-format) template) and a plain-text version as `body`.
- **Verify before every send:** print the decrypted Bcc list and confirm its length matches the number of rows returned from Supabase. Never send with an unverified list.
- **Adding / removing subscribers:** insert or delete rows in `public.subscribers`. Writes need the Supabase service_role key (which the routine does **not** hold) — do it from the SQL editor or a separate admin tool. Each row needs `email_hash` (HMAC-SHA256 of the lowercased address, keyed with `EMAIL_HASH_PEPPER`) and `email_enc` (Fernet of the lowercased address with `EMAIL_ENC_KEY`). See [`supabase/`](supabase/).

## Email format

Send the digest as **`htmlBody`** on the Gmail connector, following this template exactly. Also pass a plain-text `body` (the same content, links inline in parentheses) as the fallback. Match the original digests: bold headlines, `<br>` line breaks, source names as `<a href>` links, section headers with the emoji shown below.

Section headers and their emojis, in order: **🏛️ Politics**, **💻 Tech**, **🔬 Science**, **💼 Business**, **🎲 Wildcard**, **✨ Fun fact**.

```html
<div style="font-family:-apple-system,Helvetica,Arial,sans-serif;max-width:640px;margin:0 auto;color:#222;line-height:1.5">
  <h1 style="font-size:22px;margin-bottom:4px">News Digest: Sep 1 – Sep 3, 2026</h1>
  <p style="color:#666;margin-top:0;font-size:13px">Everything notable since Monday.</p>

  <h2 style="font-size:18px;border-bottom:2px solid #333;padding-bottom:4px;margin-top:28px">🏛️ Politics</h2>

  <p><strong>Headline sentence, ending with a period.</strong><br>
  Two to four sentences of plain-language summary. Assume the reader has no prior context.<br>
  <a href="https://example.com/article">Source Name</a></p>

  <!-- exactly 3 <p> items per news section -->

  <h2 style="font-size:18px;border-bottom:2px solid #333;padding-bottom:4px;margin-top:28px">💻 Tech</h2>
  <!-- ... -->

  <h2 style="font-size:18px;border-bottom:2px solid #333;padding-bottom:4px;margin-top:28px">✨ Fun fact</h2>

  <p><strong>The surprising claim, stated in one line.</strong><br>
  One or two sentences explaining it. <a href="https://example.com/source">Source Name</a></p>

  <hr style="margin-top:32px;border:none;border-top:1px solid #ddd">
  <p style="color:#999;font-size:12px">Your automated News Digest — sent every Monday, Wednesday, and Friday.</p>
</div>
```

Rules:
- `<h1>` is the exact subject line. The grey line under it is `Everything notable since <weekday of the last digest>.`
- Every news section has **exactly 3** `<p>` items; Fun fact has **exactly 1**.
- Each news item: `<strong>headline</strong><br>` then summary `<br>` then one `<a href>` source link.
- Link text is the publication name (e.g. `Reuters`, `NPR`), never a bare URL.
- Keep the inline styles as shown — email clients need them; do not switch to a `<style>` block or external CSS.

## Dedup

The "last send" lookup searches `in:sent subject:"News Digest:" -subject:Fwd -subject:Re -subject:TEST` so that forwards, replies, and `[TEST]` sends don't get mistaken for a prior genuine digest. A run stops only if a genuine digest whose coverage window ends today (or later) already went out.

## Checking past fun facts

The no-repeat rule only works if **all** past digests are checked, not the first page of results.

- Search `in:sent subject:"News Digest:" -subject:Fwd -subject:Re -subject:TEST` and **page all the way through** — keep following `pageToken`/next-page until there are no more results. Don't rely on a single search call or on snippets.
- For each genuine digest found, fetch its **full body** (`get_message` / `get_thread`, plain-text format) — snippets are truncated and will hide the fun-fact section.
- Extract every fun fact from every digest into one running list, then exclude any candidate that matches one already used, including trivial rewordings or the same fact with a different number/framing.
- Sanity-check: the number of digests you pulled facts from should match the number of genuine past sends. If it doesn't, you missed some — redo the enumeration before choosing.
