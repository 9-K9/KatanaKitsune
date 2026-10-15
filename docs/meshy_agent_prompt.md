# Meshy agent prompt — Katana Kitsune prop library

You are generating a complete library of 3D props for **Katana Kitsune**, a dark-fantasy
isometric action roguelike set in a haunted Edo-period Japan overrun by yokai. Every
model will be rendered to 2D isometric pixel-art sprites (a 2:1 diamond grid, camera at
roughly 30° elevation, light from the upper-left), so model for silhouette readability
at small size, not for close-up detail.

## Global rules (apply to every asset)

- **Style:** stylised, slightly chunky proportions, clean readable silhouettes,
  hand-painted/flat-shaded PBR with low texture noise. No photoreal micro-detail.
  Think "Okami meets a grim Ghibli dungeon". Muted, slightly desaturated palette:
  aged wood, lacquer black and vermilion, oxidised bronze, washi paper, grey granite,
  moss green, with small accents of warm lantern orange or ghostly teal.
- **Setting:** Edo-period Japan, worn and slightly cursed. Things are old, used,
  chipped, damp, cobwebbed — not pristine and not comic.
- **Scale reference:** the player character is a ~1.7 m humanoid fox-samurai. State
  every prop's real-world size against that so the set stays consistent.
- **Topology:** game-ready low/mid poly (1k–8k tris for small props, up to 20k for
  trees), single mesh or few submeshes, one texture set each, transparent background,
  centred at origin, Y-up, resting on the ground plane at Y=0.
- **Framing:** no base plinth or ground disc unless the prop is listed as having one.
- **Breakable variants:** every prop marked **[BREAKABLE]** needs a second
  `_broken` model: the same object smashed/toppled/splintered, same footprint,
  roughly half the height, debris scattered within the original footprint.
- **Light variants:** every prop marked **[LIGHT]** needs three models: `unlit`,
  `lit` (with a visible flame/glow element and warm emissive material), and `broken`.
- Deliver each as `<name>.glb` (and `<name>_broken.glb` / `<name>_lit.glb` where
  applicable), named exactly as given below in snake_case.

---

## A. Interior props — Japanese household / shrine set
All ~96 px sprites → real-world footprint about 0.6–1.2 m. All **[BREAKABLE]**.

1. **ceramic_jar** — tall round-bellied stoneware storage jar, ~0.8 m, dark brown ash
   glaze with drips, cracked rim, rope collar around the neck. Broken: shattered shards
   in a ring, base ring still standing.
2. **tea_set** — low lacquered tray holding a cast-iron tetsubin kettle, three small
   clay cups and a bamboo whisk, ~0.5 m across. Broken: tray tipped, kettle on its side,
   cups in pieces.
3. **sake_barrel** — komodaru straw-wrapped sake cask, ~0.7 m tall, rice-straw wrapping
   bound with black rope, red calligraphy label on the front, wooden lid. Broken: staves
   burst outward, straw torn, dark liquid pool.
4. **storage_chest** — plain wooden nagamochi storage trunk, ~1.0 × 0.5 × 0.5 m, iron
   corner brackets, iron hasp, lid slightly ajar. Broken: lid torn off, boards split.
5. **offering_box** — saisen-bako shrine offering box, ~0.9 m wide, dark wood with
   slatted top, red and gold trim, a few coins on the slats. Broken: slats caved in,
   coins spilled.
6. **zabuton_stack** — stack of five folded floor cushions, ~0.5 m tall, indigo and
   mustard patterned fabric, slightly slumped. Broken: cushions scattered, one burst
   with stuffing.
7. **tansu_chest** — stepped kaidan-tansu cabinet, ~1.3 m tall, dark keyaki wood with
   black iron drawer pulls and plates, one drawer pulled open. Broken: toppled on its
   side, drawers out, boards cracked.
8. **samurai_armour_stand** — full ō-yoroi armour displayed on a wooden stand, ~1.6 m
   tall, black lacquered lamellar with red silk lacing, kabuto helmet with crescent
   maedate on top. Broken: stand collapsed, helmet rolled off, plates scattered.
9. **taiko_drum** — large barrel taiko drum on a cross-legged wooden stand, ~1.2 m
   tall, red lacquered body, pale hide heads with black iron tacks, two bachi sticks
   resting on it. Broken: head split, drum fallen from stand.
10. **rice_bales** — pyramid of three tawara straw rice bales, ~1.1 m tall, tightly
    woven straw bound with rope, worn ends. Broken: bales burst, rice spilled.
11. **supply_crates** — two stacked rough wooden crates with a rope-tied bundle on top,
    ~1.2 m tall, black ink kanji stencils on the sides. Broken: crates smashed, planks
    splayed.
12. **butsudan_shrine** — household Buddhist altar cabinet, ~1.4 m tall, black lacquer
    with gold leaf interior, doors open revealing a small Buddha figure, candles and an
    incense bowl. Broken: doors hanging, interior gutted, figure fallen.
13. **katana_rack** — horizontal katana-kake display stand, ~0.6 m tall, black lacquer
    with gold trim, holding two sheathed swords (one katana, one wakizashi). Broken:
    rack snapped, swords on the floor.
14. **folding_screen** — four-panel byōbu screen, ~1.5 m tall, gold-leaf ground with an
    ink painting of pine and cranes, black lacquer frame, panels zigzagged so it stands
    on its own. Broken: frame snapped, panels torn and leaning.
15. **low_table** — chabudai low dining table, ~0.35 m tall, ~0.9 m wide, dark wood,
    with a bowl and a pair of chopsticks on top. Broken: legs snapped, top split in two.
16. **stone_lantern_japanese** — kasuga-style granite tōrō lantern, ~1.6 m tall,
    hexagonal roof cap with curled corners, light chamber with carved window openings,
    moss in the crevices. Broken: upper tiers toppled beside the stem.

## B. Interior props — dungeon / castle set

17. **breakable_urn** [BREAKABLE] — squat grey-green glazed funerary urn, ~0.7 m, lid
    on, faint spiral pattern, chipped. Broken: smashed into large curved shards.
18. **breakable_chest** [BREAKABLE] — iron-banded treasure chest, ~0.8 m wide, dark
    wood, heavy rounded lid, big iron lock. Broken: lid blown open, banding bent.
19. **breakable_statue** [BREAKABLE] — weathered stone guardian statue of a seated
    hooded demon (oni-like), ~1.2 m tall, cracked, lichen-spotted. Broken: head and
    shoulders fallen off, torso crumbling.
20. **brazier** — round iron fire-bowl on three claw legs, ~0.9 m tall, with glowing
    coals and small flames, soot-blackened. (Static, always lit.)
21. **chair** — simple Edo-period folding camp stool / kyokuroku with a lacquered
    frame and worn fabric seat, ~0.8 m tall.
22. **pillar** — square load-bearing hinoki wood pillar on a granite base stone,
    ~2.6 m tall, 0.4 m thick, dark aged wood with iron reinforcing bands at top and
    bottom.
23. **spike_trap** — floor plate ~1.0 × 1.0 m of dark stone with a grid of rusted
    iron spikes rising from slots, some spikes blood-stained. Provide two poses:
    spikes retracted (flush) and spikes extended.
24. **exit_stairs** — square stone stairwell going DOWN into the floor, ~1.5 × 1.5 m
    opening, worn granite steps descending into darkness, low stone lip around the
    edge. Also a larger variant **exit_stairs_big** at ~3 × 3 m with a torii-shaped
    wooden frame over the opening.

## C. Light sources — all **[LIGHT]** (unlit / lit / broken)
~0.9–1.8 m tall. The `lit` version must have a clear flame or glow element.

25. **iron_brazier** — tall standing iron brazier on a tripod, ~1.5 m, bowl of coals.
26. **stone_lantern** — small oki-dōrō garden lantern, ~0.9 m, granite, lit by a
    candle inside the chamber.
27. **stake_torch** — a wooden stake driven into the ground with an oil-soaked
    rag-wrapped head, ~1.6 m.
28. **paper_lantern** — tall chōchin paper lantern on a wooden pole stand, ~1.8 m,
    white/cream washi with red kanji, bamboo ribs, candle glow from within.
29. **spirit_censer** — bronze incense burner on a stand, ~1.2 m, three-legged with
    a lid pierced in a cloud pattern; the lit version emits ghostly **teal-blue**
    spirit fire instead of orange flame.
30. **bamboo_torch** — thick bamboo pole with the top split into a cage holding a
    small fire, ~1.7 m, bound with rope.

## D. Pickups / items — small, high-contrast, slightly oversized (~0.3–0.4 m)
These must read at 32 px, so exaggerate shape and colour. No breakable variant.

31. **onigiri** — rice ball triangle with a strip of nori, two sesame seeds, bright
    white rice.
32. **sake_flask** — ceramic tokkuri sake bottle, cream glaze with blue brush stroke,
    a small cup beside it.
33. **health_potion** — round glass gourd flask with a cork, filled with glowing red
    liquid, rope tied at the neck.
34. **health_charm** — omamori cloth amulet, red brocade with gold thread and a knotted
    cord, slightly glowing.
35. **power_orb** — floating hitodama spirit orb, swirling violet-and-gold energy with
    a small trailing flame tail, emissive.
36. **scroll** — rolled makimono scroll with wooden end-caps and a red silk tie,
    partly unrolled showing a glyph.

## E. Exterior props — biome vegetation and landmarks
Trees ~4–8 m tall, shrubs ~0.6–1.2 m, rocks ~0.8–1.5 m. No breakable variants. Trees
need a believable trunk base since the camera sees them from above; skip root plates.

### Sakura / temple garden biome (lush, spring night)
37. **sakura_tree_a** — broad mature cherry tree in full pale-pink bloom, ~7 m,
    gnarled dark trunk, wide dome canopy.
38. **sakura_tree_c** — taller, narrower young cherry tree, ~7 m, upright, lighter
    canopy, pink-white blossoms.
39. **sakura_weeping** — shidare-zakura weeping cherry, ~6 m, long cascading blossom
    branches reaching near the ground.
40. **black_pine** — kuromatsu Japanese black pine, ~6 m, twisted trunk, layered
    flat "cloud" needle pads, trained-bonsai look at full size.
41. **bamboo_clump** — dense clump of 8–12 green bamboo culms, ~8 m, leaves only near
    the top, a few dry leaves at the base.
42. **garden_rocks** — arrangement of three mossy grey karesansui boulders of
    different sizes, ~1.2 m total footprint.
43. **azalea_bush** — rounded clipped azalea shrub, ~1 m, dense dark green with
    scattered magenta flowers.
44. **grass_tuft** — small clump of tall grass, ~0.5 m, green with a few yellowed
    blades.
45. **pond_reeds** — cluster of reeds and cattails, ~1.4 m, brown seed heads,
    growing from a small patch of mud.

### Desert biome (arid, night)
46. **cactus_a** — tall branching saguaro-like cactus, ~4.5 m, two arms, ribbed,
    dusty green.
47. **cactus_b** — low wide prickly-pear cluster, ~1.2 m, flat pads, a few red fruit.
48. **palm_a** — date palm, ~6 m, textured trunk leaning slightly, fronds spread with
    a few dead hanging ones.
49. **sandstone_rocks** — cluster of layered orange-tan sandstone rocks, ~1.3 m,
    wind-smoothed.
50. **dry_shrub** — dead tumbleweed-like sagebrush, ~0.7 m, grey-brown tangle.
51. **desert_skull** — bleached horned ox skull half-buried in sand, ~0.6 m.

### Snow biome (frozen, night)
52. **snowy_pine** — conical fir tree heavily laden with snow, ~5 m, branches bent
    under drifts.
53. **dead_tree_a** — large bare dead deciduous tree, ~5.5 m, twisted branches, dark
    bark, snow on upper limbs.
54. **dead_tree_b** — thinner leaning dead tree, ~5 m, split trunk, a crow-sized
    branch stub.
55. **snowy_rocks** — grey boulder cluster with snow caps, ~1.3 m, ice at the base.
56. **frozen_shrub** — bare twiggy shrub encased in frost and rime ice, ~0.9 m.
57. **jizo_statue** — small stone Jizō bodhisattva statue, ~1.0 m, with a red knitted
    bib and cap, snow on the head, serene face, hands clasped.

### Shared landmarks (all biomes)
58. **torii_gate** — vermilion two-post torii gate, ~5 m tall × 5 m wide, black
    kasagi top beam, slightly peeling paint, rope shimenawa with paper shide hanging
    from the crossbeam.
59. **komainu_statue** — stone lion-dog guardian on a square pedestal, ~1.8 m, mouth
    open, curled mane, weathered and moss-stained. Also provide a mirrored
    closed-mouth twin **komainu_statue_b**.
60. **dragon_statue** — bronze dragon coiled around a stone pillar, ~2.6 m, oxidised
    green-bronze with a water-spout mouth (temizuya fountain style).

---

## Output checklist
- 16 Japanese interior props × (base + broken) = 32 models
- 3 breakable dungeon props × 2 + brazier, chair, pillar, spike_trap (2 poses),
  exit_stairs, exit_stairs_big = 14 models
- 6 light sources × 3 states = 18 models
- 6 pickups = 6 models
- 24 exterior props + komainu_b = 25 models
- **Total: 95 models.** Keep material names, scale and lighting consistent across
  the whole batch so they can be rendered to sprites in a single pass.
