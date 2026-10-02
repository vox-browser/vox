module css

fn test_author_family_candidates_exclude_installed_non_exact_matches() {
	// Arial is a real installed family on macOS. The author face intentionally
	// has a different weight so this exercises candidate assembly, not the
	// exact registration-key fast path.
	$if macos {
		assert platform_typefaces_with_family_name_boundary('Arial').len > 0
		mut computer := FontComputer.create()
		mut set := FontFaceSet.create_for_font_computer(computer)
		mut face := FontFaceObject.construct_impl('Arial',
			FontFaceSource.from_string('url("author.ttf")'), FontFaceDescriptors{
				weight: '900'
			})
		face.status_ = .loaded
		face.parsed_font = &PlatformTypeface{
			family_name: 'Arial'
			source_path: 'author.ttf'
			weight_:     900
		}
		set.add(face)!
		matched := computer.find_font('Arial', 400, 0, 12, FontVariationSettings{
			weight: 400
			width:  100
		}, FontFeatureData{})
		assert matched != unsafe { nil }
		assert matched.fonts.len == 1
		assert matched.fonts[0].font.typeface.source_path == 'author.ttf'
		set.delete_(face)
		installed := computer.find_font('Arial', 400, 0, 12, FontVariationSettings{
			weight: 400
			width:  100
		}, FontFeatureData{})
		assert installed != unsafe { nil }
		assert installed.fonts[0].font.typeface.source_path != 'author.ttf'
	}
}
