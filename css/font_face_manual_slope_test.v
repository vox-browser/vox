module css

fn test_manual_font_faces_register_and_match_declared_style() {
	mut computer := FontComputer.create()
	mut set := FontFaceSet.create_for_font_computer(computer)
	for index, style in ['normal', 'italic', 'oblique 20deg'] {
		mut face := FontFaceObject.construct_impl('Style Fixture',
			FontFaceSource.from_string('url("fixture.ttf")'), FontFaceDescriptors{
				style:  style
				weight: '400'
			})
		face.status_ = .loaded
		face.parsed_font = &PlatformTypeface{
			family_name: 'Style Fixture'
			source_path: '${style}.ttf'
		}
		set.add(face)!
		assert face.parsed_font_face().slope()? == index
	}
	assert computer.font_faces.len == 3
	for slope in 0 .. 3 {
		matched := computer.compute_font_for_style_values(['Style Fixture'],
			CSSPixels.new(16), slope, 400, Percentage{ value_: 100 }, .none_,
			map[string]f64{}, FontFeatureData{})
		assert matched.fonts.len == 1
		assert matched.fonts[0].font.typeface.source_path == ['normal.ttf', 'italic.ttf',
			'oblique 20deg.ttf'][slope]
	}
	mut italic := set.set_entries()[1]
	italic.set_style('oblique')!
	assert italic.parsed_font_face().slope()? == 2
	assert 'style fixture|400-400|1|100' !in computer.font_faces
	assert (computer.font_faces['style fixture|400-400|2|100'] or { []&FontFaceObject{} }).len == 2
}
