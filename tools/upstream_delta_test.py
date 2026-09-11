import unittest

import upstream_delta


class UpstreamDeltaTest(unittest.TestCase):
    def test_parse_numstat_includes_binary_rows_without_counting_them(self) -> None:
        self.assertEqual(
            upstream_delta.parse_numstat("12\t3\tLibraries/LibWeb/CSS/A.cpp\n-\t-\timage.png"),
            [(12, 3, "Libraries/LibWeb/CSS/A.cpp"), (0, 0, "image.png")],
        )

    def test_module_for_distinguishes_root_support(self) -> None:
        self.assertEqual(
            upstream_delta.module_for("Libraries/LibWeb/Painting/A.cpp"), "Painting"
        )
        self.assertEqual(
            upstream_delta.module_for("Libraries/LibWeb/PixelUnits.cpp"),
            "(root support)",
        )
        self.assertIsNone(upstream_delta.module_for("Libraries/LibJS/A.cpp"))

    def test_delta_churn_sums_additions_and_deletions(self) -> None:
        delta = upstream_delta.Delta(files=3, additions=12, deletions=7)
        self.assertEqual(delta.churn, 19)


if __name__ == "__main__":
    unittest.main()
