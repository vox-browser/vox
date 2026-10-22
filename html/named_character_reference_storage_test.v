module html

import platform

fn test_named_reference_fixed_data_matches_upstream_checksum_and_order() {
	assert named_char_ref_data.len == 2231
	mut hash := u64(14695981039346656037)
	mut pairs := 0
	for index, reference in named_char_ref_data {
		if index > 0 {
			assert named_char_ref_data[index - 1].name < reference.name
		}
		assert reference.first != 0
		if reference.second != 0 {
			pairs++
		}
		for byte in reference.name {
			hash = (hash ^ u64(byte)) * u64(1099511628211)
		}
		hash *= u64(1099511628211)
		for shift in 0 .. 4 {
			hash = (hash ^ u64(u8(reference.first >> (shift * 8)))) * u64(1099511628211)
		}
		for shift in 0 .. 4 {
			hash = (hash ^ u64(u8(reference.second >> (shift * 8)))) * u64(1099511628211)
		}
	}
	assert pairs == 93
	// FNV-1a of the independently generated upstream names, NUL separators,
	// and both little-endian u32 code points (zero for an absent second).
	assert hash == u64(0xe4eeb910b8b975a0)
}

fn test_named_reference_lookup_and_result_records_do_not_allocate() {
	matcher := NamedCharacterReferenceMatcher{
		consumed:         'NotEqualTilde;'
		last_match:       'NotEqualTilde;'
		last_match_index: named_char_ref_lower_bound('NotEqualTilde;')
	}
	mut owner := platform.new_arena('named reference lookup')
	entry := owner.enter()
	before := owner.usage().used
	mut total := u64(0)
	for _ in 0 .. 512 {
		assert named_char_ref_has_prefix('NotEqual')
		assert !named_char_ref_has_prefix('NotEqual!')
		points := matcher.code_points() or { panic('missing entity') }
		total += u64(points.first) + u64(points.second)
	}
	$if prealloc {
		assert owner.usage().used == before
	}
	assert total == u64(512) * (u64(0x2242) + u64(0x338))
	owner.leave(entry)
	owner.release()
}

fn test_named_reference_match_result_is_independent_of_consumed_workspace() {
	scratch := platform.begin_thread_scratch('named reference lifetime')
	mut matcher := NamedCharacterReferenceMatcher{}
	for byte in 'NotEqualTilde;' {
		assert matcher.try_consume_ascii_char(byte)
	}
	points := matcher.code_points() or { panic('missing entity') }
	assert matcher.overconsumed_code_points() == 0
	scratch.leave()
	scratch.finish()
	gc_collect()
	assert points.name == 'NotEqualTilde;'
	assert points.first == 0x2242
	assert points.second == 0x338
	index := named_char_ref_lower_bound(points.name)
	assert voidptr(points.name.str) == voidptr(named_char_ref_data[index].name.str)
}

fn test_named_reference_xml_lookup_preserves_pairs_aliases_and_unknown_names() {
	assert resolve_named_character_reference('AMP')? == '&'
	assert resolve_named_character_reference('amp;')? == '&'
	assert resolve_named_character_reference('NotEqualTilde')? == '\u2242\u0338'
	assert resolve_named_character_reference('fjlig;')? == 'fj'
	assert resolve_named_character_reference('Afr;')? == '\U0001d504'
	assert resolve_named_character_reference('not')? == '\u00ac'
	assert resolve_named_character_reference('notit;') == none
	assert resolve_named_character_reference('') == none
	assert resolve_named_character_reference('zzzz;') == none
}
