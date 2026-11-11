module svg

import math

fn test_numeric_attribute_parsing() {
	assert parse_coordinate('  -1.25e2 ') or { 0 } == -125
	assert parse_length('+.5') or { 0 } == 0.5
	assert parse_integer(' -42 ') or { 0 } == -42
	assert parse_integer('1.5') == none
	assert parse_positive_length('-1') == none
	assert parse_positive_length('3.5') or { 0 } == 3.5
	assert parse_number_percentage('25%') or { NumberPercentage{} } == percentage(25)
	assert parse_number_percentage('25px') == none
}

fn test_sequences_points_and_viewbox() {
	assert parse_number_sequence('1,2 3,-4')! == [1.0, 2.0, 3.0, -4.0]
	assert parse_points('0,0 10,20') == [Point{ x: 0, y: 0 }, Point{ x: 10, y: 20 }]
	assert parse_points('0 0 1') == [Point{ x: 0, y: 0 }]
	assert parse_points('0 0 trailing').len == 0
	assert parse_points('0 0 1 trailing').len == 0
	assert parse_table_values('0 .25, 1') == [0.0, 0.25, 1.0]
	assert parse_table_values('-1 0').len == 0
	assert parse_table_values('+1 0').len == 0
	assert parse_table_values('0,').len == 1
	assert parse_viewbox('0 1 640 480') or { ViewBox{} } == ViewBox{
		min_y: 1
		width: 640
		height: 480
	}
	assert parse_viewbox('0 0 -1 2') or { ViewBox{} }.width == -1
}

fn test_enumerated_attribute_parsing() {
	ratio := parse_preserve_aspect_ratio('xMaxYMin slice') or { PreserveAspectRatio{} }
	assert ratio.align == .x_max_y_min
	assert ratio.meet_or_slice == .slice
	assert parse_preserve_aspect_ratio('xMidYMid bogus') == none
	assert parse_preserve_aspect_ratio('xMidYMid meet ignored') != none
	assert parse_units(' userSpaceOnUse ') or { Units.object_bounding_box } == .user_space_on_use
	assert parse_spread_method('reflect') or { SpreadMethod.pad } == .reflect
}

fn test_transform_parsing_and_composition() {
	transforms := parse_transform('translate(10, 20) scale(2) rotate(90)') or { []Transform{} }
	assert transforms.len == 3
	assert transforms[0].kind == .translate
	assert transforms[1].values[1] == 2
	assert transforms[2].values[0] == 90
	matrix := compose_transforms(transforms)
	assert math.abs(matrix.e - 10) < 0.0001
	assert math.abs(matrix.f - 20) < 0.0001
	assert parse_transform('scale()') == none
	assert (parse_transform('rotate(10 20)') or { []Transform{} })[0].values[2] == 0
	assert (parse_transform('translate(10-20)') or { []Transform{} })[0].values[1] == -20
	assert parse_transform('matrix(1 0 0 1 4 5)') or { []Transform{} }.len == 1
}

fn test_canonical_name_coverage() {
	assert attribute_names().len == 109
	assert tag_names().len == 49
	assert 'xlink:href' in attribute_names()
	assert 'feTurbulence' in tag_names()
}
