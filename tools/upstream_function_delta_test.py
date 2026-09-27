import unittest

import upstream_function_delta as delta


class UpstreamFunctionDeltaTest(unittest.TestCase):
    def test_normalize_cpp_ignores_comments_and_whitespace_but_keeps_literals(self) -> None:
        self.assertEqual(
            delta.normalize_cpp('return /* why */ "a // b" ; // tail\n'),
            'return "a // b" ;',
        )
        self.assertNotEqual(delta.normalize_cpp('return "a";'), delta.normalize_cpp('return "b";'))

    def test_extracts_methods_and_namespace_functions(self) -> None:
        definitions = delta.cpp_definitions(
            "Libraries/LibWeb/Example/Thing.cpp",
            """/*
 * Copyright header with { braces } and a pretend function().
 */
int Thing::value(int input) const
{
    return input + 1;
}

bool enabled()
{
    return true;
}
""",
        )
        self.assertEqual([(item.owner, item.name) for item in definitions], [("Thing", "value"), ("<namespace>", "enabled")])
        self.assertEqual(definitions[0].body, "{ return input + 1; }")
        self.assertEqual(definitions[1].body, "{ return true; }")

    def test_extracts_inline_header_methods(self) -> None:
        definitions = delta.header_definitions(
            "Libraries/LibWeb/Example/Thing.h",
            """// A leading comment must not shift source offsets.
class Thing {
public:
    int value() const { return 42; }
    int declaration_only() const;
};
""",
        )
        self.assertEqual([(item.owner, item.name) for item in definitions], [("Thing", "value")])
        self.assertEqual(definitions[0].body, "{ return 42; }")

    def test_comparison_recognizes_moves_changes_additions_and_removals(self) -> None:
        def definition(source: str, name: str, body: str, line: int = 1) -> delta.Definition:
            return delta.Definition(source, line, "Thing", name, "int ()", body)

        old = [
            definition("Libraries/LibWeb/Example/Old.cpp", "moved", "{ return 1; }"),
            definition("Libraries/LibWeb/Example/A.cpp", "changed", "{ return 1; }"),
            definition("Libraries/LibWeb/Example/A.cpp", "removed", "{ return 1; }"),
        ]
        current = [
            definition("Libraries/LibWeb/Example/New.cpp", "moved", "{ return 1; }"),
            definition("Libraries/LibWeb/Example/A.cpp", "changed", "{ return 2; }"),
            definition("Libraries/LibWeb/Example/A.cpp", "added", "{ return 1; }"),
        ]
        entries = delta.compare_definitions(old, current)
        self.assertEqual([(entry.kind, entry.name) for entry in entries], [("added", "added"), ("changed", "changed"), ("removed", "removed")])

    def test_comparison_recognizes_an_exact_move_between_modules(self) -> None:
        old = [
            delta.Definition(
                "Libraries/LibWeb/Animations/Animation.cpp",
                10,
                "Animation",
                "play",
                "void ()",
                "{ update(); }",
            )
        ]
        current = [
            delta.Definition(
                "Libraries/LibWeb/CSS/Animation.cpp",
                20,
                "Animation",
                "play",
                "void ()",
                "{ update(); }",
            )
        ]

        self.assertEqual(delta.compare_definitions(old, current), [])

    def test_comparison_reports_a_signature_only_change(self) -> None:
        old = [
            delta.Definition("Libraries/LibWeb/Example/Thing.cpp", 1, "Thing", "value", "int ()", "{ return 1; }")
        ]
        current = [
            delta.Definition("Libraries/LibWeb/Example/Thing.cpp", 1, "Thing", "value", "long ()", "{ return 1; }")
        ]

        entries = delta.compare_definitions(old, current)
        self.assertEqual([(entry.kind, entry.name) for entry in entries], [("changed", "value")])

    def test_classifies_out_of_line_lifecycle_definitions(self) -> None:
        entries = [
            delta.DeltaEntry("added", "Example", "Thing.cpp", 1, "Thing", "Thing"),
            delta.DeltaEntry("added", "Example", "Thing.cpp", 2, "Thing", "~Thing"),
        ]

        self.assertTrue(all(delta.is_language_lifecycle_definition(entry) for entry in entries))
        self.assertFalse(
            delta.is_language_lifecycle_definition(
                delta.DeltaEntry("added", "Example", "Thing.cpp", 3, "Thing", "create")
            )
        )

    def test_classifies_root_support_definitions_across_typed_v_modules(self) -> None:
        functions = {
            ("nearest_value_for", "CSSPixels"),
            ("navigation_tree", None),
            ("dom_tree", None),
            ("layout_tree", None),
        }
        exact = delta.DeltaEntry(
            "changed", "(root support)", "PixelUnits.h", 96, "CSSPixels", "nearest_value_for"
        )
        mapped = delta.DeltaEntry(
            "changed", "(root support)", "Dump.cpp", 59, "<namespace>", "dump_tree"
        )
        runtime = delta.DeltaEntry(
            "added", "(root support)", "TreeNode.h", 65, "TreeNode", "parent_offset"
        )

        self.assertEqual(
            delta.root_support_disposition(exact, functions),
            ("candidate-name-match", ("nearest_value_for",)),
        )
        self.assertEqual(
            delta.root_support_disposition(mapped, functions),
            (
                "consolidated-name-match",
                ("navigation_tree", "dom_tree", "layout_tree"),
            ),
        )
        self.assertEqual(
            delta.root_support_disposition(runtime, functions),
            ("gc-or-binding-runtime", ()),
        )


if __name__ == "__main__":
    unittest.main()
