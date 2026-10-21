# Audio Production Roadmap

Counts below refer to the 119 manifest asset IDs. “Variations” are delivered individual alternatives; music duration is target composed runtime before alternate mixes. Estimates exclude human editing, implementation, voice casting, tax, and contractor fees.

## Milestone 1 — Essential gameplay audio

Scope: P0 movement, weapon motion/contact, guard/parry, damage/death, enemy alerts/attacks, projectile feedback, pickups, traps, essential UI, wave/descent, revive, and multiplayer connection state.

Estimated production: about 58 asset IDs, roughly 210–250 delivered one-shot variations, 0 music minutes. Start with the 22-asset batch in the overview, approve style, then complete remaining P0 families.

## Milestone 2 — Environmental audio

Scope: five biome beds, weather, indoor tone, water/fire emitters, doors, break material polish, animals where runtime value is confirmed.

Estimated production: 18–24 asset IDs, 25–40 one-shot variations, about 4–6 minutes of loop material.

## Milestone 3 — Music

Scope: title, character select, level select, online lobby, exploration, combat, boss, wave victory, defeat; intense combat remains optional until state logic is approved.

Estimated production: 10 tracks/stingers, about 17 minutes of target music. Plan multiple generations per accepted track and editorial loop work.

## Milestone 4 — Character audio

Scope: player exertion/hurt/down/revival/exhaustion and species-specific nonverbal enemy voices. Spoken taunts wait for corrected scripts and approved lines.

Estimated production: 18–25 asset IDs, 90–130 vocal variations, plus up to 1 minute of spoken dialogue if nine short taunts are approved.

## Milestone 5 — Polish

Scope: extra footstep surfaces, repeat-reduction alternates, dynamic mix, transitions, concurrency tuning, loop repair, browser optimization, and replacement of weak generations.

Estimated production: 15–25 additional alternates/transition assets plus editing passes; no mandatory new music minutes.

## AI generation budget (checked 2026-10-21)

Official references: [ElevenLabs pricing](https://elevenlabs.io/pricing), [ElevenLabs Sound Effects pricing](https://elevenlabs.io/sound-effects), and [Suno pricing](https://suno.com/pricing).

- ElevenLabs lists Sound Effects at approximately 200 credits per generation. Its official pricing showed Starter at US$6/month with 30,000 shared credits and commercial use; Creator at US$22/month (first month promotion may differ) with 121,000 credits. The dedicated SFX page describes 150 Starter generations and 605 Creator generations, though another landing-page snapshot showed 105 Starter generations; treat plan quotas as subject to account/region/product changes and verify at checkout.
- ElevenLabs Music is listed at approximately 900 credits per generated minute. Voice/TTS cost depends on model and text length; nonverbal vocal SFX may be generated through Sound Effects, while spoken lines consume voice credits.
- Suno's official pricing showed Pro at US$8/month when billed yearly (tax extra) with 2,500 credits and 20 monthly song downloads, and Premier at US$24/month yearly with 10,000 credits and 60 downloads. Commercial rights require a paid plan; verify monthly-billing prices in the account before purchase.

### Working budget

For 119 IDs and the requested variation counts, expect roughly 350–450 accepted deliverables and at least 2–4 candidate generations per accepted family. A practical production allowance is:

- **SFX/ambience/nonverbal voice:** one ElevenLabs Creator month (US$22 list monthly; promotional first month may be US$11) should cover hundreds of SFX generations under the currently published quota. Allow US$22–99 if multiple review rounds or Pro WAV/API needs are required.
- **Music:** one paid Suno Pro month may be sufficient for initial candidates but its 20-download allowance is tight for ten finalized tracks plus alternates; budget US$8–24 on the currently displayed annual-equivalent tiers, or use ElevenLabs shared credits. Expect editorial looping/mastering outside this figure.
- **Realistic AI-service total:** **US$30–125**, excluding tax and human labor. The lower end assumes disciplined prompting and one subscription month; the upper end allows substantial regeneration and higher-quality export/API needs.

Pricing is not a quote. Recheck official pages immediately before purchase, record the plan and commercial terms used for every generated asset, and retain receipts/generation metadata.

## Gates

1. Approve manifest and style guide.
2. Generate/review first batch in isolation and in a gameplay build.
3. Lock naming, loudness, and signature motifs.
4. Finish P0 before ambience/music breadth.
5. Correct taunt ownership and script before spoken voice.
6. Complete multiplayer and browser stress tests before final mastering.
