module platform

fn successful_decode(bytes []u8) !DecodedImage {
	return DecodedImage{
		frame_count: 1
		frames: [Frame{ bitmap: bytes, duration: 10 }]
	}
}

fn no_op() {}

fn normalize_decode(mut image DecodedImage) ! {
	image.is_animated = true
	image.loop_count = 2
}

fn ignore_decode_error(_ string) {}

fn test_font_plugin_fallbacks_and_layout_mode() {
	plugin := FontPlugin.new(false, ['Courier New', 'Noto Sans', 'Times New Roman'], false)
	assert plugin.generic_font_name(.monospace) == 'Courier New'
	assert plugin.generic_font_name(.sans_serif) == 'Noto Sans'
	assert plugin.default_font(16) or { panic('missing default') }.family == 'Noto Sans'
	assert plugin.symbol_font_names() == ['Noto Color Emoji', 'Noto Sans Symbols']
	layout := FontPlugin.new(true, [], false)
	assert layout.generic_font_name(.cursive) == 'SerenitySans'
	assert layout.symbol_font_names() == ['Noto Emoji']
}

fn test_platform_generic_font_aliases_are_available() {
	$if macos {
		assert system_font_family_available('Serif')
		assert system_font_family_available('Monospace')
		assert system_font_family_available('Helvetica')
		assert system_font_family_available('Lucida Grande')
		assert system_font_family_available('Tahoma')
		assert system_font_family_available('Georgia')
		assert font_path_for_family('Helvetica', 400)? == '/System/Library/Fonts/Supplemental/Arial.ttf'
		assert font_path_for_family('Lucida Grande', 400)? == '/System/Library/Fonts/LucidaGrande.ttc'
		assert font_path_for_family('Tahoma', 400)? == '/System/Library/Fonts/Supplemental/Tahoma.ttf'
		assert font_path_for_family('Tahoma', 700)? == '/System/Library/Fonts/Supplemental/Tahoma Bold.ttf'
		assert (&Font{ family: 'Helvetica', weight: 400 }).face_index() == 0
		assert (&Font{ family: 'Helvetica', weight: 700 }).face_index() == 0
		helvetica_metrics := (&Font{ family: 'Helvetica', point_size: 16 }).pixel_metrics()
		assert helvetica_metrics.ascent > 0
		metrics := (&Font{ family: 'Serif', point_size: 16 }).pixel_metrics()
		assert metrics.ascent == 12
		assert metrics.descent == 4
	}
}

fn test_bold_document_font_candidates_preserve_family_naming() {
	assert bold_font_path_candidates('/Fonts/Arial.ttf') == ['/Fonts/Arial Bold.ttf']
	assert bold_font_path_candidates('/Fonts/Example-Regular.ttf') == [
		'/Fonts/Example-Bold.ttf',
		'/Fonts/Example-Regular Bold.ttf',
	]
	assert bold_font_path_candidates('/Fonts/Example Regular.otf') == [
		'/Fonts/Example Bold.otf',
		'/Fonts/Example Regular Bold.otf',
	]
}

fn test_font_exposes_scaled_true_type_glyph_contours_for_svg_paths() {
	font := &Font{
		family: 'sans-serif'
		point_size: 16
	}
	_, glyph_index := font.glyph_advance_and_index(u32(`O`))
	outline := font.glyph_outline(glyph_index) or { panic('missing O outline') }
	assert outline.contours.len > 0
	assert outline.contours.all(it.len > 2)
	mut has_on_curve := false
	mut has_off_curve := false
	for contour in outline.contours {
		for point in contour {
			has_on_curve = has_on_curve || point.on_curve
			has_off_curve = has_off_curve || !point.on_curve
		}
	}
	assert has_on_curve
	assert has_off_curve
}

fn test_glyph_run_retains_packed_replay_data_and_slices_without_rebasing() {
	font := &Font{
		family: 'sans-serif'
		point_size: 16
	}
	mut run := GlyphRun.new_with_face(font, .ltr, [
		Glyph{
			glyph_index: 7
			position: GlyphPosition{2.5, -0.25}
			advance: 4
			length_in_code_units: 1
		},
		Glyph{
			glyph_index: 11
			position: GlyphPosition{6.5, 0.75}
			advance: 5
			length_in_code_units: 2
		},
	], .emoji)
	assert run.face() == .emoji
	assert run.glyph_indices() == [u16(7), 11]
	assert run.glyph_positions() == [f64(2.5), -0.25, 6.5, 0.75]
	// Gfx::GlyphRun retains the sum of advances as its logical width. Glyph
	// ink offsets can be negative and must not shorten that width.
	assert run.width() == 9
	run.glyphs_ << Glyph{
		glyph_index: 13
		position: GlyphPosition{11.5, 0}
		advance: 3
	}
	run.invalidate_replay_data()
	run.refresh_replay_data()
	assert run.glyph_indices() == [u16(7), 11, 13]
	assert run.glyph_positions() == [f64(2.5), -0.25, 6.5, 0.75, 11.5, 0]
	slice := run.slice(1, 1)
	assert slice.face() == .emoji
	assert slice.width() == 5
	assert slice.glyph_indices() == [u16(11)]
	// Gfx::GlyphRun::slice() retains the original position so a partial text
	// shadow stays aligned with the unsliced foreground run.
	assert slice.glyph_positions() == [f64(6.5), 0.75]
}

fn test_timer_state_and_single_shot_fire() {
	mut timer := Timer.create_single_shot(10, no_op)
	assert timer.interval() == 10
	timer.start()
	assert timer.is_active()
	timer.fire()
	assert !timer.is_active()
	timer.set_single_shot(false)
	timer.restart_with_interval(20)
	timer.fire()
	assert timer.is_active()
	assert timer.interval() == 20
}

fn test_image_codec_and_plugin_registries() {
	codec := &ImageCodecPlugin{
		decode_image_hook: successful_decode
	}
	mut codecs := ImageCodecPluginRegistry{}
	assert !codecs.is_initialized()
	codecs.install(codec)
	assert codecs.is_initialized()
	assert codecs.get().decode_image([u8(1), 2])!.frames[0].bitmap == [u8(1), 2]
	normalized := codecs.get().decode_image_with_callbacks([u8(3)], normalize_decode, ignore_decode_error)!
	assert normalized.is_animated
	assert normalized.loop_count == 2
	mut fonts := FontPluginRegistry{}
	font := FontPlugin.new(true, [], false)
	fonts.install(font)
	assert fonts.get().is_layout_test_mode()
}

fn test_platform_plugins_expose_upstream_process_singletons() {
	event_loop := EventLoopPlugin.new()
	EventLoopPlugin.install(event_loop)
	assert EventLoopPlugin.the() == event_loop
	font := FontPlugin.new(true, [], false)
	FontPlugin.install(font)
	assert FontPlugin.the() == font
	assert FontPlugin.the().is_layout_test_mode()
	codec := &ImageCodecPlugin{}
	assert !ImageCodecPlugin.is_initialized()
	ImageCodecPlugin.install(codec)
	assert ImageCodecPlugin.is_initialized()
	assert ImageCodecPlugin.the() == codec
}
