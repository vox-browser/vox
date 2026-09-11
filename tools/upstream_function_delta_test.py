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
            """
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
        self.assertIn("return input + 1", definitions[0].body)

    def test_extracts_inline_header_methods(self) -> None:
        definitions = delta.header_definitions(
            "Libraries/LibWeb/Example/Thing.h",
            """
class Thing {
public:
    int value() const { return 42; }
    int declaration_only() const;
};
""",
        )
        self.assertEqual([(item.owner, item.name) for item in definitions], [("Thing", "value")])

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


if __name__ == "__main__":
    unittest.main()
