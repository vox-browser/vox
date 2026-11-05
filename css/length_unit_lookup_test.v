module css

import platform

fn lookup_length_unit_reference(input string) ?LengthUnit {
	mut bytes := input.bytes()
	for mut byte in bytes {
		if byte >= `A` && byte <= `Z` { byte += 32 }
	}
	canonical := bytes.bytestr()
	for unit in [LengthUnit.cap, .ch, .cm, .cqb, .cqh, .cqi, .cqmax, .cqmin, .cqw,
		.dvb, .dvh, .dvi, .dvmax, .dvmin, .dvw, .em, .ex, .ic, .in_, .lh,
		.lvb, .lvh, .lvi, .lvmax, .lvmin, .lvw, .mm, .pc, .pt, .px, .q,
		.rcap, .rch, .rem, .rex, .ric, .rlh, .svb, .svh, .svi, .svmax, .svmin,
		.svw, .vb, .vh, .vi, .vmax, .vmin, .vw] {
		if canonical == length_unit_name(unit) || (unit == .q && canonical == 'q') { return unit }
	}
	return none
}

fn test_length_unit_lookup_preserves_every_spelling_and_ascii_case_permutation() {
	for unit in [LengthUnit.cap, .ch, .cm, .cqb, .cqh, .cqi, .cqmax, .cqmin, .cqw,
		.dvb, .dvh, .dvi, .dvmax, .dvmin, .dvw, .em, .ex, .ic, .in_, .lh,
		.lvb, .lvh, .lvi, .lvmax, .lvmin, .lvw, .mm, .pc, .pt, .px, .q,
		.rcap, .rch, .rem, .rex, .ric, .rlh, .svb, .svh, .svi, .svmax, .svmin,
		.svw, .vb, .vh, .vi, .vmax, .vmin, .vw] {
		name := length_unit_name(unit).to_lower()
		for mask in 0 .. (1 << name.len) {
			mut bytes := name.bytes()
			for index in 0 .. bytes.len {
				if mask & (1 << index) != 0 { bytes[index] -= 32 }
			}
			input := bytes.bytestr()
			assert string_to_length_unit(input) == ?LengthUnit(unit), input
			assert packed_length_unit(input) == ?LengthUnit(unit), input
		}
	}
}

fn test_length_unit_lookup_preserves_every_byte_substitution_and_boundaries() {
	for name in ['cap', 'ch', 'cm', 'cqb', 'cqh', 'cqi', 'cqmax', 'cqmin', 'cqw',
		'dvb', 'dvh', 'dvi', 'dvmax', 'dvmin', 'dvw', 'em', 'ex', 'ic', 'in', 'lh',
		'lvb', 'lvh', 'lvi', 'lvmax', 'lvmin', 'lvw', 'mm', 'pc', 'pt', 'px', 'q',
		'rcap', 'rch', 'rem', 'rex', 'ric', 'rlh', 'svb', 'svh', 'svi', 'svmax', 'svmin',
		'svw', 'vb', 'vh', 'vi', 'vmax', 'vmin', 'vw'] {
		for index in 0 .. name.len {
			for byte in 0 .. 256 {
				mut bytes := name.bytes()
				bytes[index] = u8(byte)
				input := bytes.bytestr()
				assert string_to_length_unit(input) == lookup_length_unit_reference(input)
				assert packed_length_unit(input) == lookup_length_unit_reference(input)
			}
		}
		for input in ['', '${name} ', ' ${name}', '${name}\x00', '\x00${name}',
			'${name}\t', '\\70${name}', name.repeat(7)] {
			assert string_to_length_unit(input) == lookup_length_unit_reference(input)
			assert packed_length_unit(input) == lookup_length_unit_reference(input)
		}
	}
	for input in ['µm', 'ＰＸ', 'K', 'px😀', '\x00', 'p\x00x', 'in_', 'percent'] {
		assert string_to_length_unit(input) == none
		assert packed_length_unit(input) == none
	}
}

fn test_packed_length_unit_lookup_does_not_allocate_for_mixed_case() {
	$if prealloc {
		mut arena := platform.new_arena('packed length unit lookup test')
		defer { arena.release() }
		entry := arena.enter()
		before := arena.usage().used
		for _ in 0 .. 4096 {
			assert (packed_length_unit('PX') or { panic('missing px') }) == .px
			assert (packed_length_unit('rEm') or { panic('missing rem') }) == .rem
			assert (packed_length_unit('SvMaX') or { panic('missing svmax') }) == .svmax
			assert packed_length_unit('ＰＸ') == none
		}
		after := arena.usage().used
		arena.leave(entry)
		assert after == before
	}
}
