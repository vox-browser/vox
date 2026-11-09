module jpegxl

fn test_hf_transform_ids_shapes_and_quant_tables_match_source() {
	mut count := 0
	mut valid := 0
	for line in $embed_file('testdata/hf-transform.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		f := line.split('\t')
		assert f.len == 2
		actual := if transform := hf_transform_from_id(f[0].int()) {
			valid++
			dims := transform.covered_blocks()
			'${int(transform)},${dims[0]},${dims[1]},${transform.shape_id()},${transform.quant_table_index()}'
		} else {
			'err'
		}
		assert actual == f[1], 'transform ${f[0]}'
		count++
	}
	assert count == 258
	assert valid == 27
}
