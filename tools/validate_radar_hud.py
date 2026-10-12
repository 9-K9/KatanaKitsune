"""Non-game checks for radar orbit, kill-counter wiring and HUD asset bounds."""

import math
from pathlib import Path
import re
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


def source(name):
    return (ROOT / "scripts/system" / f"{name}.gd").read_text()


def method(text, name):
    match = re.search(rf"^func {name}\([^)]*\)[^\n]*:\n(.*?)(?=^func |\Z)",
                      text, re.MULTILINE | re.DOTALL)
    if match is None:
        raise AssertionError(f"Missing method {name}")
    return match.group(1)


class RadarHudChecks(unittest.TestCase):
    def test_actual_orbit_expression(self):
        cycle = source("DayNightCycle")
        duration = float(re.search(r"PHASE_SECONDS: float = ([\d.]+)", cycle)[1])
        expression = method(cycle, "orbit_angle").strip().removeprefix("return ")
        for elapsed, expected in ((0, (-1, 0)), (150, (0, -1)),
                                  (300, (1, 0)), (450, (0, 1)),
                                  (600, (-1, 0)), (750, (0, -1))):
            with self.subTest(elapsed=elapsed):
                angle = eval(expression, {"__builtins__": {}}, {
                    "PI": math.pi, "TAU": math.tau,
                    "fposmod": lambda x, y: x % y,
                    "elapsed": elapsed, "PHASE_SECONDS": duration,
                })
                self.assertAlmostEqual(math.cos(angle), expected[0])
                self.assertAlmostEqual(math.sin(angle), expected[1])
        radar = source("Radar")
        self.assertIn("cycle.orbit_angle()", radar)
        self.assertIn("if cycle.is_night():", radar)
        self.assertIn("_draw_moon(at)", radar)
        self.assertIn("_draw_sun(at)", radar)
        self.assertNotIn("advance(", radar)

    def test_counter_reset_and_credit_wiring(self):
        score = source("Score")
        floor = method(score, "begin_floor")
        run = method(score, "begin_run")
        killed = method(score, "killed")
        self.assertIn("floor_kills = [0, 0, 0, 0]", floor)
        self.assertNotIn("run_kills =", floor)
        self.assertNotIn("points =", floor)
        self.assertIn("run_kills = [0, 0, 0, 0]", run)
        self.assertIn("begin_floor()", run)
        self.assertIn("if slot < 0 or slot > 3:", killed)
        for counter in ("floor_kills", "run_kills"):
            self.assertEqual(killed.count(f"{counter}[slot] += 1"), 1)
        self.assertIn("Score.begin_floor()", method(source("MazeDemo"), "_populate"))
        enemy = (ROOT / "scripts/stateMachine/class/EnemyStateClass.gd").read_text()
        self.assertIn("Score.killed(_last_hit_by, tier, unseen)", enemy)
        self.assertIn("if is_dead:\n\t\treturn", method(enemy, "begin_death"))
        self.assertNotIn("run_kills =", source("GameOver"))

    def test_counter_lifecycle_from_source_operations(self):
        score = source("Score")
        state = {"floor_kills": [0] * 4, "run_kills": [0] * 4}

        def apply_counter_operations(name, slot=0):
            body = method(score, name)
            if name == "killed" and not 0 <= slot <= 3:
                return
            for line in body.splitlines():
                reset = re.fullmatch(r"\s*(floor_kills|run_kills) = \[0, 0, 0, 0\]", line)
                increment = re.fullmatch(r"\s*(floor_kills|run_kills)\[slot\] \+= 1", line)
                if reset:
                    state[reset[1]] = [0] * 4
                elif increment:
                    state[increment[1]][slot] += 1
                elif line.strip() == "begin_floor()":
                    apply_counter_operations("begin_floor")

        for slot in (0, 1, 1, 3, -1, 4):
            apply_counter_operations("killed", slot)
        self.assertEqual(state["floor_kills"], [1, 2, 0, 1])
        self.assertEqual(state["run_kills"], [1, 2, 0, 1])
        apply_counter_operations("begin_floor")
        self.assertEqual(state["floor_kills"], [0] * 4)
        self.assertEqual(state["run_kills"], [1, 2, 0, 1])
        apply_counter_operations("killed", 2)
        self.assertEqual(state["run_kills"], [1, 2, 1, 1])
        apply_counter_operations("begin_run")
        self.assertEqual(state["floor_kills"], [0] * 4)
        self.assertEqual(state["run_kills"], [0] * 4)

    def test_hud_counts_and_layout(self):
        hud = source("HUD")
        self.assertIn('str(Score.floor_kills[cell["slot"]])', hud)
        self.assertNotIn("_phase_label", hud)
        self.assertNotIn("_kill_count_label", hud)
        radar = source("Radar")
        self.assertIn('"%d/%d\\n%d"', radar)
        self.assertIn("maxi(total - killed, 0)", radar)
        self.assertIn("HORIZONTAL_ALIGNMENT_CENTER", radar)
        self.assertIn("Color(0.0, 0.0, 0.0, 0.65)", radar)
        self.assertIn("UI_THEME", radar)
        self.assertIn("Geometry2D.intersect_polygons", radar)
        scene = (ROOT / "scenes/world/mazeDemo.tscn").read_text()
        block = scene.split('[node name="Radar"')[1].split("\n[node ")[0]
        self.assertIn("offset_left = -292.0", block)
        self.assertIn("offset_right = -12.0", block)
        for players in range(1, 5):
            self.assertLessEqual(8 + 300 * players, 1536 - 292)
        self.assertLess(286 + 54, 356 - 12)
        self.assertLessEqual(140 + 128 + 12, 280)

    def test_dragon_opening_and_transparency(self):
        image = Image.open(ROOT / "assets/sprites/ui/radar/dragon_frame.png")
        self.assertEqual(image.mode, "RGBA")
        self.assertEqual(image.getpixel((0, 0))[3], 0)
        radar = source("Radar")
        radius = float(re.search(r"radius: float = ([\d.]+)", radar)[1])
        frame = tuple(map(float, re.search(
            r"FRAME_RECT := Rect2\(([^)]+)\)", radar)[1].split(",")))
        centre = tuple(map(float, re.search(
            r"CENTRE := Vector2\(([^)]+)\)", radar)[1].split(",")))
        orbit = float(re.search(r"ORBIT_RADIUS: float = ([\d.]+)", radar)[1])
        self.assertEqual(image.width, image.height)
        self.assertEqual(frame[2], frame[3])
        self.assertGreaterEqual(radius, 88)
        self.assertLess(radius, orbit - 12)
        self.assertEqual(centre, (frame[0] + frame[2] / 2, frame[1] + frame[3] / 2))
        self.assertIn("range_world: float = 1400.0", radar)
        scale = frame[2] / image.width
        # Include one screen pixel of clearance around the map. Test texel
        # corners, not just centres, so nearest-neighbour sampling stays clear.
        for y in range(image.height):
            for x in range(image.width):
                dx = max(abs(x + 0.5 - image.width / 2) - 0.5, 0) * scale
                dy = max(abs(y + 0.5 - image.height / 2) - 0.5, 0) * scale
                if dx ** 2 + dy ** 2 <= (radius + 1) ** 2:
                    self.assertEqual(image.getpixel((x, y))[3], 0)
                if image.getpixel((x, y))[3] > 0:
                    far_x = (abs(x + 0.5 - image.width / 2) + 0.5) * scale
                    far_y = (abs(y + 0.5 - image.height / 2) + 0.5) * scale
                    self.assertLess(far_x ** 2 + far_y ** 2, (orbit - 12) ** 2)
        self.assertGreater(image.getchannel("A").getbbox()[2], 0)


if __name__ == "__main__":
    unittest.main()
