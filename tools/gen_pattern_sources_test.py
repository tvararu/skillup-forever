import unittest

from tools.gen_pattern_sources import parse, render

SAMPLE = """
  recipes = {
    [2149] = { name = "Handstitched Leather Boots", t = { 1, 40, 55, 70 }, basic = true, r = { { 2318, 2 } }, out = { 2302, 1 } },
    [1255138] = { name = "Stormrider's Leather Belt", t = { 1, 90, 105, 120 }, scroll = 252769, train = 60, sq = 3, favor = 30, r = { { 2318, 10 } }, out = { 252432, 1 }, oq = 3, bop = true },
    [1301457] = { name = "Azure Windraveled Jerkin", t = { 1, 65, 67, 70 }, scroll = 276964, train = 60, scrollPrice = 1250, rep = { 2758, 5 }, r = { { 2318, 7 } }, out = { 277028, 1 } },
    [9999] = { name = "Some \\"Quoted\\" Kit", t = { 1, 2, 3, 4 }, spec = "Tribal", faction = "Horde", gone = true, r = { { 1, 1 } }, out = { 2, 1 } },
  },
"""


class ParseTest(unittest.TestCase):
    def test_fields(self) -> None:
        recipes = parse(SAMPLE)
        self.assertEqual(recipes[2149], {"basic": "true"})
        self.assertEqual(recipes[1255138], {"train": "60", "favor": "30", "bop": "true"})
        self.assertEqual(
            recipes[1301457], {"train": "60", "scrollPrice": "1250", "rep": "{ 2758, 5 }"}
        )
        self.assertEqual(
            recipes[9999], {"spec": '"Tribal"', "faction": '"Horde"', "gone": "true"}
        )

    def test_render_is_sorted_lua(self) -> None:
        text = render(parse(SAMPLE))
        self.assertIn("\t[1255138] = { train = 60, favor = 30, bop = true },\n", text)
        self.assertLess(text.index("[2149]"), text.index("[9999]"))
        self.assertTrue(text.startswith("-- luacheck: ignore\n"))


if __name__ == "__main__":
    unittest.main()
