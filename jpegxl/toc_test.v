module jpegxl

import encoding.hex
import os

fn toc_text(toc FrameToc) string {
	return '${if toc.permuted { 1 } else { 0 }}|${toc.permutation.values.map(it.str()).join(',')}|${toc.entries.map(it.str()).join(',')}'
}

fn test_complete_toc_matches_source_tables_and_consumed_bits() {
	mut count := 0
	for line in $embed_file('testdata/toc.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 4
		mut input := new_bit_reader(hex.decode(fields[1])!)
		actual := if toc := input.read_toc(fields[0].int()) { toc_text(toc) } else { 'err' }
		assert actual == fields[3], 'TOC ${count}: ${actual}, expected ${fields[3]}'
		assert input.position == fields[2].int(), 'TOC ${count}: position ${input.position}, expected ${fields[2]}'
		count++
	}
	assert count == 2424
}

fn incremental_toc_result(entries int, mut input BitReader, mut trace []string) !string {
	mut toc := IncrementalTocReader.new(entries, mut input)!
	trace << '${toc.num_read_entries()},${toc.remaining_entries()},${if toc.is_complete() {
		1
	} else {
		0
	}},${input.position}'
	for !toc.is_complete() {
		mut failed := false
		if _ := toc.read_step(mut input) {} else { failed = true }
		trace << '${toc.num_read_entries()},${toc.remaining_entries()},${if toc.is_complete() {
			1
		} else {
			0
		}},${input.position}'
		if failed { return error('TOC step failed') }
	}
	return toc_text(toc.finalize()!)
}

fn test_incremental_toc_states_and_partial_reads_match_source() {
	mut count := 0
	for line in $embed_file('testdata/toc-incremental.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 4
		mut input := new_bit_reader(hex.decode(fields[1])!)
		mut trace := []string{}
		result := incremental_toc_result(fields[0].int(), mut input, mut trace) or { 'err' }
		actual := '${trace.join(';')}|${result}'
		assert actual == fields[3], 'Incremental TOC ${count}'
		assert input.position == fields[2].int(), 'Incremental TOC position ${count}'
		count++
	}
	assert count == 2424
}

fn test_entropy_permutations_skips_and_compositions_match_source() {
	mut count := 0
	for line in $embed_file('testdata/permutations.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 5
		mut input := new_bit_reader(hex.decode(fields[2])!)
		hist := input.read_histograms(8, true)!
		mut symbols := SymbolReader.new(hist, mut input, none)!
		actual := if mut permutation := decode_permutation(fields[0].int(), fields[1].int(), hist, mut input, mut symbols) {
			before := permutation.values.map(it.str()).join(',')
			mut reverse := []u32{len: permutation.values.len}
			for i in 0 .. reverse.len { reverse[i] = u32(reverse.len - 1 - i) }
			permutation.compose(Permutation{ values: reverse })!
			'${before}|${permutation.values.map(it.str()).join(',')}'
		} else {
			'err'
		}
		assert actual == fields[4], 'Permutation ${count}'
		assert input.position == fields[3].int(), 'Permutation position ${count}'
		count++
	}
	assert count == 576
}

fn test_real_frame_section_chains_match_source_payloads_and_positions() {
	mut previous_name := ''
	mut input := new_bit_reader([]u8{})
	mut context := FrameHeaderContext{}
	mut count := 0
	mut saw_visible_vardct := false
	for line in $embed_file('testdata/frame-sections.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 6
		if fields[0] != previous_name {
			bytes := os.read_bytes(os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/jpegxl', fields[0]))!
			input = new_bit_reader(extract_codestream(bytes)!)
			header := input.read_file_header()!
			context = header.frame_header_context()
			previous_name = fields[0]
		}
		mut frame := input.read_frame_header(context)!
		frame.postprocess(context)!
		assert '${int(frame.frame_type)},${int(frame.encoding)},${if frame.is_visible() {
			1
		} else {
			0
		}},${if frame.is_last { 1 } else { 0 }}' == fields[2]
		toc := input.read_toc(int(frame.num_toc_entries()))!
		assert input.position == fields[3].int()
		mut sections := input.read_sections(toc)!
		mut payloads := []string{}
		for mut section in sections {
			assert section.position == 0
			mut bytes := []u8{}
			for section.available_bits() >= 8 { bytes << u8(section.read(8)!) }
			section.check_end()!
			payloads << hex.encode(bytes)
		}
		assert '${toc_text(toc)}|${payloads.join(';')}' == fields[5], 'Fixture ${fields[0]} frame ${fields[1]}'
		assert input.position == fields[4].int()
		if fields[0] == 'guardian-photo.jxl' && frame.encoding == .vardct {
			assert frame.is_visible() && frame.has_lf_frame()
			saw_visible_vardct = true
		}
		count++
	}
	assert count == 7 && saw_visible_vardct
}

fn test_lehmer_tree_matches_independent_removal_and_known_skip_example() {
	for length in 1 .. 65 {
		mut code := []u32{}
		mut base := []u32{}
		for i in 0 .. length {
			base << u32(i * 3 + 1)
			code << u32((i * 7 + 3) % (length - i))
		}
		mut remaining := base.clone()
		mut expected := []u32{}
		for digit in code {
			expected << remaining[int(digit)]
			remaining.delete(int(digit))
		}
		assert decode_lehmer_code(code, base)! == expected
	}
	permutation := permutation_from_lehmer(16, 4, [u32(1), 1, 2, 3, 3, 6, 0, 1])!
	assert permutation.values == [u32(0), 1, 2, 3, 5, 6, 8, 10, 11, 15, 4, 9, 7, 12, 13, 14]
	if _ := decode_lehmer_code([u32(4)], [u32(4), 5, 6, 7]) {
		assert false
	}
	if _ := permutation_from_lehmer(0, 0, []u32{}) {
		assert false
	}
}

fn test_sections_use_logical_permutation_order_and_enforce_bounds() {
	mut input := new_bit_reader('ABCDEF'.bytes())
	toc := FrameToc{
		permuted:    true
		permutation: Permutation{ values: [u32(2), 0, 1] }
		entries:     [
			u32(2),
			3,
			1,
		]
	}
	mut sections := input.read_sections(toc)!
	mut values := []string{}
	for mut part in sections {
		mut bytes := []u8{}
		for part.available_bits() > 0 { bytes << u8(part.read(8)!) }
		if _ := part.read(1) {
			assert false
		}
		values << bytes.bytestr()
	}
	assert values == ['F', 'AB', 'CDE'] && input.position == 48
	mut truncated := new_bit_reader([u8(1), 2])
	if _ := truncated.read_sections(FrameToc{ entries: [u32(3)] }) {
		assert false
	}
	assert truncated.position == 16
	mut empty := new_bit_reader([u8(0)])
	mut incremental := IncrementalTocReader.new(0, mut empty)!
	assert !incremental.is_complete()
	if _ := incremental.finalize() {
		assert false
	}
	incremental.read_step(mut empty)!
	assert incremental.is_complete()
	incremental.finalize()!
	if _ := incremental.read_step(mut empty) {
		assert false
	}
	assert empty.position == 8
}
