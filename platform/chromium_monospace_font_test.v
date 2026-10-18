module platform

fn test_chromium_monospace_uses_the_macos_menlo_default() {
	$if macos {
		for family in ['Monospace'] {
			font := Font{family: family, point_size: 9, font_rendering_policy: .chromium}
			face := resolve_system_font_face(font.family, 400, false, 9)?
			assert face.family_name == 'Menlo'
			assert face.postscript_name == 'Menlo-Regular'
		}
	}
}
