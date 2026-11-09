module jpegxl

import crypto.sha256
import encoding.binary
import encoding.hex

fn hf_global_test_digest(state HfPasses) !string {
	mut words := [state.histogram_sets, u32(if state.coefficient_storage == .signed16 { 16 } else { 32 }), u32(state.passes.len)]
	for pass in state.passes {
		words << u32(pass.coefficient_orders.len)
		for order in pass.coefficient_orders {
			words << u32(order.values.len)
			words << order.values
		}
		h := pass.histograms
		words << [u32(h.num_histograms()), u32(h.max_num_bits()!),
			u32(if h.can_use_config_420_fast_path() { 1 } else { 0 }),
			u32(if h.is_rle() { 1 } else { 0 }), u32(h.context_map.len)]
		for value in h.context_map { words << u32(value) }
		for c in 0 .. h.num_histograms() { words << h.single_symbol(c) or { u32(0xffffffff) } }
	}
	mut bytes := []u8{len: words.len * 4}
	for i, word in words { binary.little_endian_put_u32_at(mut bytes, word, i * 4) }
	return sha256.sum(bytes).hex()
}

fn test_hf_global_combines_default_matrices_with_all_source_pass_headers() {
	mut count := 0
	mut accepted := 0
	for line in $embed_file('testdata/hf-passes.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		frame := FrameHeader{ width: f[0].u32() * 256, height: 256,
			passes: Passes{ count: f[1].u32(), shifts: if f[2] == '-' { []u32{} } else { f[2].split(',').map(it.u32()) } },
			restoration: RestorationFilter.default() }
		lf := LfGlobalState{ vardct: VarDctLfContext{ block_context: BlockContextMap{ num_contexts: f[3].int() } } }
		header := hex.decode(f[4])!
		mut packet := []u8{len: header.len + 1}
		// Start matrices at bit 7 so the original header retains exactly its
		// original available bytes, including every truncated error packet.
		packet[0] = 128
		copy(mut packet[1..], header)
		mut reader := new_bit_reader(packet)
		reader.read(7)!
		actual := if global := reader.read_hf_global(frame, lf, .signed32) {
			assert global.matrices.tables.len == 17
			for table in global.matrices.tables { assert table.samples.len == 3 * table.rows * table.columns }
			accepted++
			hf_global_test_digest(global.passes)!
		} else { 'err' }
		assert actual == f[6], 'HF global pass state ${count}'
		assert reader.position == 8 + f[5].int(), 'HF global cursor ${count}'
		count++
	}
	assert count == 66 && accepted == 34
}

fn test_hf_global_requires_vardct_state_and_bounded_group_geometry_before_input() {
	frame := FrameHeader{ width: 8, height: 8, restoration: RestorationFilter.default() }
	mut missing := new_bit_reader([u8(255)])
	if _ := missing.read_hf_global(frame, LfGlobalState{}, .signed32) { assert false }
	assert missing.position == 0
	lf := LfGlobalState{ vardct: VarDctLfContext{ block_context: BlockContextMap{ num_contexts: 1 } } }
	for bad in [FrameHeader{ ...frame, encoding: .modular },
		FrameHeader{ ...frame, width: 65537 * 256, height: 256 }] {
		mut reader := new_bit_reader([u8(255)])
		if _ := reader.read_hf_global(bad, lf, .signed32) { assert false }
		assert reader.position == 0
	}
}
