module domurl

@[heap]
struct InputParserOwner {
mut:
	parser URLInputParser
}

fn input_parser_from_constructor() &InputParserOwner {
	return &InputParserOwner{}
}

fn test_url_input_parser_initial_slots_are_all_null_after_constructor_returns() {
	mut owner := input_parser_from_constructor()
	mut parser := &owner.parser
	defer { parser.clear() }
	for index, entry in parser.slots_ {
		assert entry == unsafe { nil }, 'non-null initial slot ${index}'
	}
}

fn test_url_input_parser_can_admit_and_clear_bucket_zero() {
	mut owner := input_parser_from_constructor()
	mut parser := &owner.parser
	defer { parser.clear() }
	mut input := ''
	for index in 0 .. 4096 {
		candidate := 'https://slot-zero.test/${index}'
		if url_input_cache_set(candidate, none) == 0 {
			input = candidate
			break
		}
	}
	assert input != ''
	for _ in 0 .. 3 {
		assert parser.parse(input, none)?.serialize(false) == input
	}
	parser.clear()
	for index, entry in parser.slots_ {
		assert entry == unsafe { nil }, 'non-null cleared slot ${index}'
	}
	assert parser.parse(input, none)?.serialize(false) == input
}
