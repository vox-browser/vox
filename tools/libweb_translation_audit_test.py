import tempfile
import unittest
from pathlib import Path

import libweb_translation_audit as audit


class TrivialImplementationInventoryTests(unittest.TestCase):
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
