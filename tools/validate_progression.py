#!/usr/bin/env python3
"""Static checks for per-player experience and floor upgrades. Does not launch Godot."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def source(path):
    return (ROOT / path).read_text()


def method(text, name):
    match = re.search(rf"^(?:static )?func {name}\(.*?(?=^(?:static )?func |\Z)", text, re.M | re.S)
    if match is None:
        raise AssertionError(f"missing {name}")
    return match.group(0)


PROGRESSION = source("scripts/system/Progression.gd")


def const(name):
    match = re.search(rf"^const {name}: \w+ = ([\d.]+)", PROGRESSION, re.M)
    if match is None:
        raise AssertionError(f"missing {name}")
    return float(match[1])


def species_xp():
    block = re.search(r"const SPECIES_XP: Dictionary = \{(.*?)\n\}", PROGRESSION, re.S)[1]
    return {key: int(value) for key, value in re.findall(r'"(\w+)": (\d+)', block)}


def xp_for(species, base_tier, rolled_tier):
    base = species_xp().get(species, max(base_tier, 1) * 10)
    return round(base * (1 + const("TIER_BONUS") * max(rolled_tier - base_tier, 0)))


def xp_to_next(level):
    return int(const("FIRST_LEVEL_XP") + const("LEVEL_XP_STEP") * max(level - 1, 0))


class ProgressionChecks(unittest.TestCase):
    def test_species_values_match_every_active_monster(self):
        self.assertEqual(species_xp(), {
            "kappa": 10, "karasuShinobi": 12, "ninaNinja": 15, "jorogumo": 25,
            "oni": 30, "tengu": 35, "kasha": 40, "yukiOnna": 60, "yokailord": 200,
        })
        scenes = re.search(r"enemy_scene_paths = Array\[String\]\(\[(.*?)\]\)", source("scenes/world/mazeDemo.tscn"))[1]
        active = {Path(path).stem for path in re.findall(r'"(res://[^"]+)"', scenes)}
        self.assertEqual(active, set(species_xp()))
        self.assertEqual(xp_for("kasha", 3, 3), 4 * xp_for("kappa", 2, 2))

    def test_rolled_tier_bonus_and_level_curve(self):
        self.assertEqual(xp_for("kappa", 2, 4), 13)
        self.assertEqual(xp_for("kasha", 3, 6), 58)
        self.assertEqual(xp_for("kasha", 3, 1), 40)
        self.assertEqual([xp_to_next(level) for level in (1, 2, 3)], [80, 120, 160])
        self.assertIn("while xp[slot] >= xp_to_next(level[slot])", method(PROGRESSION, "gain"))
        self.assertIn("floor_levels[slot] += 1", method(PROGRESSION, "gain"))

    def test_spending_caps_and_refunds(self):
        self.assertEqual(const("MAX_RANK"), 5)
        self.assertIn("points[slot] > 0 and rank(slot, stat) < MAX_RANK", method(PROGRESSION, "can_spend"))
        self.assertIn("points[slot] += 1", method(PROGRESSION, "refund"))
        rank5 = {
            "health": 1 + const("HEALTH_PER_RANK") * 5,
            "speed": 1 + const("SPEED_PER_RANK") * 5,
            "sneak_drain": 1 - const("SNEAK_DRAIN_PER_RANK") * 5,
        }
        self.assertAlmostEqual(rank5["health"], 1.5)
        self.assertAlmostEqual(rank5["speed"], 1.2)
        self.assertAlmostEqual(rank5["sneak_drain"], 0.6)

    def test_kill_credit_and_run_lifecycle(self):
        enemy = source("scripts/stateMachine/class/EnemyStateClass.gd")
        self.assertIn("if base_tier < 0:\n\t\tbase_tier = tier\n\ttier = to", method(enemy, "apply_tier"))
        death = method(enemy, "begin_death")
        self.assertEqual(death.count("Progression.killed("), 1)
        self.assertLess(death.index("if is_dead:"), death.index("Progression.killed("))
        self.assertIn("Progression.begin_run()", method(source("scripts/system/CharacterSelect.gd"), "_start_game"))
        self.assertIn('Progression="*res://scripts/system/Progression.gd"', source("project.godot"))
        maze = source("scripts/system/MazeDemo.gd")
        self.assertIn("Progression.begin_floor()", method(maze, "_populate"))
        finish = method(maze, "_finish_wave")
        self.assertLess(finish.index("await _offer_upgrades(party)"), finish.index("descend()"))

    def test_upgrades_use_captured_bases(self):
        body = source("scripts/stateMachine/class/AnimatedCharacterClass.gd")
        apply = method(body, "apply_progression")
        for field in ("max_stamina", "stamina_regen", "max_sneak", "sneak_regen"):
            self.assertIn(f'{field} = _progress_base["{field}"]', apply)
        self.assertIn("if _progress_base.is_empty():", apply)
        self.assertIn("* trained", method(body, "_apply_speed"))
        self.assertIn("sneak_drain_factor", method(body, "drain_sneak"))
        scale = method(source("scripts/system/MazeDemo.gd"), "_scale_party")
        self.assertIn('base["health"] * deep * trained', scale)
        self.assertIn("apply_progression()", scale)

    def test_screen_is_per_player_and_pause_safe(self):
        screen = source("scripts/system/LevelUpScreen.gd")
        self.assertIn("Roster.input_for(slot)", screen)
        self.assertIn('"ready": Roster.is_bot(slot) or Progression.points[slot] == 0', screen)
        self.assertIn('if Roster.is_bot(column["slot"]):', screen)
        self.assertIn("_spend_bot_points(slot)", screen)
        self.assertIn("for slot in party:", screen)
        self.assertIn("process_mode = Node.PROCESS_MODE_ALWAYS", screen)
        self.assertIn('get_first_node_in_group("level_up_screen")', source("scripts/system/PauseMenu.gd"))
        width = 4 * 330 + 3 * 24
        self.assertLessEqual(width, 1536)


if __name__ == "__main__":
    unittest.main()
