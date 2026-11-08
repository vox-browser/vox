module jpegxl

import encoding.hex

fn modular_weighted_text(header WeightedPredictorHeader) string {
	return '${if header.all_default { 1 } else { 0 }},${header.p1c},${header.p2c},${header.p3ca},${header.p3cb},${header.p3cc},${header.p3cd},${header.p3ce},${header.w0},${header.w1},${header.w2},${header.w3}'
}

fn modular_squeeze_text(squeeze SqueezeParams) string {
	return '${if squeeze.horizontal { 1 } else { 0 }},${if squeeze.in_place { 1 } else { 0 }},${squeeze.begin_channel},${squeeze.num_channels}'
}

fn modular_transform_text(transform ModularTransform) string {
	return '${int(transform.id)},${transform.begin_channel},${transform.rct_type},${transform.num_channels},${transform.num_colors},${transform.num_deltas},${transform.predictor_id}|${transform.squeezes.map(modular_squeeze_text(it)).join(';')}'
}

fn modular_header_result(operation string, mut reader BitReader) !string {
	return match operation {
		'weighted' { modular_weighted_text(reader.read_weighted_predictor_header()!) }
		'squeeze' { modular_squeeze_text(reader.read_squeeze_params()!) }
		'transform' { modular_transform_text(reader.read_modular_transform()!) }
		else {
			header := reader.read_modular_group_header()!
			'${if header.use_global_tree { 1 } else { 0 }}|${modular_weighted_text(header.weighted)}|${header.transforms.map(modular_transform_text(it)).join('~')}'
		}
	}
}

fn test_modular_headers_match_complete_source_records_and_errors() {
	mut count := 0
	for line in $embed_file('testdata/modular-headers.tsv').to_string().split_into_lines() {
		if line == '' || line.starts_with('#') { continue }
		fields := line.split('\t')
		assert fields.len == 4
		mut input := new_bit_reader(hex.decode(fields[1])!)
		actual := modular_header_result(fields[0], mut input) or { 'err' }
		assert actual == fields[3], 'Modular header ${count}, ${fields[0]}'
		assert input.position == fields[2].int(), 'Modular header position ${count}, ${input.position}, expected ${fields[2]}'
		count++
	}
	assert count == 8289
}

fn test_modular_header_defaults_and_invalid_transform_are_explicit() {
	mut weighted := new_bit_reader([u8(1)])
	assert weighted.read_weighted_predictor_header()! == WeightedPredictorHeader{}
	assert weighted.position == 1
	mut automatic_squeeze := new_bit_reader([u8(2)])
	transform := automatic_squeeze.read_modular_transform()!
	assert transform.id == .squeeze && transform.squeezes.len == 0
	assert automatic_squeeze.position == 4
	mut invalid := new_bit_reader([u8(3)])
	if _ := invalid.read_modular_transform() {
		assert false
	}
	assert invalid.position == 2
}
