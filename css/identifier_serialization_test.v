module css

$if gcboehm ? {
	fn C.GC_gcollect()
}

struct IdentifierSerializationCase {
	value    string
	expected string
}

fn test_identifier_serialization_preserves_ascii_and_escape_boundaries() {
	cases := [
		IdentifierSerializationCase{'', ''},
		IdentifierSerializationCase{'alpha_22-beta', 'alpha_22-beta'},
		IdentifierSerializationCase{'--3', '--3'},
		IdentifierSerializationCase{'_9', '_9'},
		IdentifierSerializationCase{'3d', '\\33 d'},
		IdentifierSerializationCase{'-3d', '-\\33 d'},
		IdentifierSerializationCase{'-', '\\-'},
		IdentifierSerializationCase{'a.b:c', 'a\\.b\\:c'},
		IdentifierSerializationCase{'a\u0000b', 'a�b'},
		IdentifierSerializationCase{'a\u0001b', 'a\\1 b'},
		IdentifierSerializationCase{'\u007f', '\\7f '},
		IdentifierSerializationCase{'中文-β', '中文-β'},
		IdentifierSerializationCase{'😀9', '😀9'},
	]
	for case in cases {
		assert serialize_an_identifier(case.value) == case.expected
	}
}

fn retained_serialized_identifier() string {
	return serialize_an_identifier('retained-'.repeat(2048) + '42')
}

fn test_verbatim_identifier_serialization_outlives_its_input_scope() {
	identifier := retained_serialized_identifier()
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		assert identifier.len == 9 * 2048 + 2
		assert identifier.starts_with('retained-retained-')
		assert identifier.ends_with('retained-42')
	}
}
