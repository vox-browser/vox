import tempfile
import unittest
from pathlib import Path

import libweb_translation_audit as audit


class TrivialImplementationInventoryTests(unittest.TestCase):
    def test_verified_allocator_factory_is_not_suspicious(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "permissionsapi" / "permissions.v"
            source.parent.mkdir()
            source.write_text(
                """
module permissionsapi

struct Permissions {}

fn Permissions.create() &Permissions {
    return &Permissions{}
}
"""
            )
            region_source = Path(directory) / "webvtt" / "vtt_region.v"
            region_source.parent.mkdir()
            region_source.write_text(
                """
module webvtt

struct VTTRegion {}

fn VTTRegion.create() &VTTRegion {
    return &VTTRegion{}
}
"""
            )

            suspicious, verified = audit.trivial_implementation_inventories(Path(directory))

        self.assertEqual(suspicious, [])
        self.assertEqual(len(verified), 2)
        self.assertEqual(
            {finding["owner"] for finding in verified}, {"Permissions", "VTTRegion"}
        )

    def test_foreign_function_declaration_is_not_an_empty_implementation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "boundary.c.v"
            source.write_text(
                """
module boundary

fn C.external_value() &C.Value

const cache = map[string]int{}

fn genuinely_empty() {
}
"""
            )

            suspicious, _ = audit.trivial_implementation_inventories(Path(directory))

        self.assertEqual(
            suspicious,
            [
                {
                    "source": "boundary.c.v",
                    "line": 8,
                    "owner": None,
                    "name": "genuinely_empty",
                    "body": "",
                }
            ],
        )


if __name__ == "__main__":
    unittest.main()
