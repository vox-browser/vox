module css

fn test_unparsed_value_serializes_self_and_nested_cycles() {
	mut cycle := CSSUnparsedValue.create([]CSSUnparsedSegment{})
	cycle.tokens << CSSUnparsedSegment(CSSVariableReferenceValue.create('--a', cycle))
	assert cycle.to_string()! == ''
	outer := CSSUnparsedValue.create([
		CSSUnparsedSegment(CSSVariableReferenceValue.create('--b', cycle)),
	])
	assert outer.to_string()! == 'var(--b,)'
}

fn test_unparsed_value_serializes_mutual_fallback_cycle() {
	mut first := CSSUnparsedValue.create([]CSSUnparsedSegment{})
	mut second := CSSUnparsedValue.create([]CSSUnparsedSegment{})
	first.tokens << CSSUnparsedSegment(CSSVariableReferenceValue.create('--second', second))
	second.tokens << CSSUnparsedSegment(CSSVariableReferenceValue.create('--first', first))
	outer := CSSUnparsedValue.create([
		CSSUnparsedSegment('prefix '),
		CSSUnparsedSegment(CSSVariableReferenceValue.create('--outer', first)),
		CSSUnparsedSegment(' suffix'),
	])
	assert first.to_string()! == ''
	assert second.to_string()! == ''
	assert outer.to_string()! == 'prefix var(--outer,) suffix'
}

fn test_unparsed_value_keeps_shared_acyclic_fallbacks() {
	fallback := CSSUnparsedValue.create([CSSUnparsedSegment('red')])
	value := CSSUnparsedValue.create([
		CSSUnparsedSegment(CSSVariableReferenceValue.create('--a', fallback)),
		CSSUnparsedSegment(' '),
		CSSUnparsedSegment(CSSVariableReferenceValue.create('--b', fallback)),
	])
	assert value.to_string()! == 'var(--a,red) var(--b,red)'
}
