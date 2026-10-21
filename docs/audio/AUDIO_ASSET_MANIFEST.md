# Audio Asset Manifest Overview

The canonical production sheet is [AUDIO_ASSET_MANIFEST.csv](AUDIO_ASSET_MANIFEST.csv). It contains 119 stable asset IDs and complete generation/integration fields.

## Status language

- **Implemented:** the trigger/mechanic is verified in current scenes or scripts; the audio itself is still missing unless Existing Audio is populated.
- **Partial:** relevant code/content exists, but timing, wiring, or content assignment is incomplete.
- **Planned:** explicitly documented by the project but not operational.
- **Proposed:** an audio/design recommendation not represented as current gameplay.

## Category summary

| Category | Coverage |
|---|---|
| Movement | Indoor/outdoor/snow footfalls, run, roll, jump, landing, stealth |
| Combat | Draw/sheathe, slash variants, charge, counter, guard, parry, impacts, projectile, critical, defeat, wave clear |
| Characters | Exertion, hurt, downed, revive, exhaustion, rest |
| Enemies | Alert, attack, hurt/death for all nine active species; shared movement/projectile cues |
| Environment | Five theme beds, four weather beds, interior, pond, fire |
| Interactive objects | Pickups, scrolls, break materials, doors, traps, stairs, descent |
| Interface | Navigation, errors, selection, inventory, level-up, health, game over, score |
| Music | Ten state tracks/stingers |
| Multiplayer | Join/fail/seat/start/disconnect feedback |
| Narrative | Type sound, taunt voice set, floor announcement |

## Priority interpretation

P0 rows are immediate clarity cues: attacks, impacts, damage, danger telegraphs, pickups, core UI, critical co-op state, and progression transitions. P1 establishes identity and atmosphere. P2 covers layering and polish. No speculative feature displaces verified gameplay.

## Recommended first production batch (22 assets)

1. MOV-001 indoor hard-floor walk
2. MOV-004 run footstep
3. MOV-005 forward roll
4. CMB-001 katana draw
5. CMB-003 fast slash whoosh
6. CMB-004 charged slash release
7. CMB-006 counter slash
8. CMB-007 blade block
9. CMB-008 perfect parry
10. CMB-009 blade-flesh hit
11. CMB-010 kick impact
12. CMB-014 enemy defeat
13. CHR-003 player hurt
14. CHR-004 player downed
15. CHR-006 revive complete
16. ENM-004 enemy projectile launch
17. ENM-005 enemy projectile hit
18. OBJ-002 scroll pickup
19. OBJ-003 scroll activate
20. OBJ-009 spike warning
21. UI-002 menu confirm
22. UI-004 UI error

This batch is grounded entirely in implemented mechanics. Generate the listed variation counts, review in context, then lock loudness and tonal direction before expanding.

## Sharing and redundancy decisions

- A single impact family can serve multiple compatible weapons/enemies, with per-species vocal layers providing identity.
- Indoor surfaces are intentionally grouped for milestone 1; split tatami/wood/stone later only if runtime surface identification proves reliable.
- Alert/attack/hurt-death are separate per species because silhouette and threat readability matter.
- Weather and biome loops remain separate because they can crossfade independently.
- Multiplayer world sounds reuse ordinary combat/object assets; networking changes playback ownership, not the sound file.

