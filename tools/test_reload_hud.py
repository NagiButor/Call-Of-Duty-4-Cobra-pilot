"""Static/mask regressions; run with Python 3 from the repository root.
Does not replace shader_tool/linker compilation or an in-game smoke test.
"""
import pathlib
import re
import unittest
ROOT = pathlib.Path(__file__).resolve().parents[1]
class ReloadHUDTests(unittest.TestCase):
    def test_reload_has_fixed_quad_and_native_progress(self):
        script = (ROOT / "raw/maps/_playervehicle_abrams.gsc").read_text()
        block = script.split("\nabrams_hud_reload_start()\n", 1)[1].split("\nabrams_hud_reload_done()", 1)[0]
        self.assertNotIn("scaleOverTime", block)
        self.assertIn('setshader( "pv_reload", 44, 44 )', block)
        self.assertIn("hud.shell.alpha = elapsed / total;", block)
        self.assertIn("fadeOverTime( remaining )", block)
        self.assertIn("pv_max( 0.05, level.pv_abrams_reload_time )", block)
    def test_mask_reveals_bottom_up_without_resampling(self):
        for progress in (0, .25, .5, .75, 1):
            visible = [y for y in range(44) if (y + .5) / 44 >= 1 - progress]
            self.assertEqual(len(visible), round(44 * progress))
            if visible:
                self.assertEqual(visible, list(range(44 - len(visible), 44)))
    def test_profiles_match_and_texture_uv_is_unchanged(self):
        folder = ROOT / "raw/shader_bin/shader_src"
        for kind in ("vs", "ps"):
            self.assertEqual((folder / (kind + "_2_0_pv_shell_fill.hlsl")).read_text(),
                             (folder / (kind + "_3_0_pv_shell_fill.hlsl")).read_text())
        ps = (folder / "ps_3_0_pv_shell_fill.hlsl").read_text()
        self.assertIn("tex2D(colorMapSampler, input.texCoord)", ps)
        self.assertIn("clip(input.texCoord.y - (1.0 - progress))", ps)
    def test_material_is_in_zone(self):
        self.assertEqual((ROOT / "zone_source/cobra_pilot.csv").read_text().count("material,pv_reload"), 1)
if __name__ == "__main__":
    unittest.main()
