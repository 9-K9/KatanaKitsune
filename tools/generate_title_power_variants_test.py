import unittest

import numpy as np
from PIL import Image

from generate_title_power_variants import PALETTES, apply_palette, clothing_mask


class TitleMaskTests(unittest.TestCase):
    def test_background_and_skin_exclusions(self):
        image = Image.new("RGBA", (838, 469), (220, 30, 30, 255))
        mask = clothing_mask(image)
        for x, y in ((490, 200), (410, 390), (790, 394), (700, 355),
                     (746, 380), (590, 130), (350, 360)):
            with self.subTest(point=(x, y)):
                self.assertFalse(mask[y, x])

    def test_disconnected_cloth_and_burgundy_folds(self):
        for color in ((220, 30, 30, 255), (140, 50, 100, 255),
                      (65, 25, 50, 255)):
            image = Image.new("RGBA", (838, 469), color)
            mask = clothing_mask(image)
            for x, y in ((410, 375), (460, 376), (680, 370), (790, 384)):
                with self.subTest(color=color, point=(x, y)):
                    self.assertTrue(mask[y, x])

    def test_transparent_pixels_and_black_outlines_preserved(self):
        for color in ((220, 30, 30, 0), (25, 22, 35, 255),
                      (188, 117, 116, 255)):
            image = Image.new("RGBA", (838, 469), color)
            self.assertFalse(clothing_mask(image).any())

    def test_palettes_change_only_masked_rgb(self):
        image = Image.new("RGBA", (838, 469), (220, 30, 30, 255))
        original = np.asarray(image)
        mask = clothing_mask(image)
        for name, ramp in PALETTES.items():
            with self.subTest(palette=name):
                result = np.asarray(apply_palette(image, mask, ramp))
                np.testing.assert_array_equal(result[~mask], original[~mask])
                np.testing.assert_array_equal(result[:, :, 3], original[:, :, 3])
                self.assertTrue(np.any(result[mask] != original[mask]))


if __name__ == "__main__":
    unittest.main()
