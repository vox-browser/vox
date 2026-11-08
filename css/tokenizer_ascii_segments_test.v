module css

fn test_mixed_ascii_runs_keep_unicode_scalars_and_original_byte_offsets() {
	for source in ['aébc尾d🙂ef', '🙂asciié', 'ascii尾', 'é', 'é尾🙂'] {
		mut input := TokenizerInputArena.new(source)
		defer { input.release() }
		points := source.runes()
		assert input.len == points.len
		mut offset := 0
		for index, point in points {
			assert unsafe { input.code_points[index] } == u32(point)
			assert unsafe { input.byte_offsets[index] } == offset
			offset += point.str().len
		}
		assert offset == source.len
	}
}
