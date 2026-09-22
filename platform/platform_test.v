module platform

import math

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

fn test_glyph_run_caches_conservative_bounds_with_final_replay_data() {
	font := &Font{
		family: 'sans-serif'
		point_size: 16
	}
	mut run := shape_text(0, 0, 'abc', font, .ltr)
	bounds := run.bounding_box()
	assert bounds.width > 0
	assert bounds.height > 0
	face_bounds := font.typeface_bounds() or { panic('missing typeface bounds') }
	for glyph in run.glyphs() {
		assert bounds.x <= glyph.position.x + face_bounds.x_min
		assert bounds.y <= glyph.position.y - face_bounds.y_max
		assert bounds.x + bounds.width >= glyph.position.x + face_bounds.x_max
		assert bounds.y + bounds.height >= glyph.position.y - face_bounds.y_min
	}

	// Line construction is allowed to merge and reposition this storage. The
	// finalization refresh updates bounds alongside the packed replay arrays.
	run.glyphs_[0].position.translate_by(-40, 3)
	run.invalidate_replay_data()
	run.refresh_replay_data()
	refreshed := run.bounding_box()
	assert refreshed.x == bounds.x - 40
	assert refreshed.height == bounds.height + 3
	assert run.glyph_positions()[0] == run.glyphs_[0].position.x

	non_painting := GlyphRun.new(font, .ltr, [Glyph{
		glyph_index: run.glyphs_[0].glyph_index
		should_paint: false
	}])
	assert non_painting.bounding_box() == GlyphRunBounds{}
	assert non_painting.glyph_indices().len == 0
	assert non_painting.glyph_positions().len == 0
	assert non_painting.glyph_intercepts(1, -100, 100).len == 0
	assert GlyphRun.new(font, .ltr, []).bounding_box() == GlyphRunBounds{}
}

fn test_glyph_run_layout_clone_has_independent_mutable_storage() {
	font := &Font{
		family: 'sans-serif'
		point_size: 16
	}
	original := GlyphRun.new_with_face(font, .rtl, [Glyph{
		glyph_index: 7
		position: GlyphPosition{2.5, -0.25}
		advance: 4
	}], .emoji)
	mut clone := original.clone_for_layout()
	clone.glyphs_[0].position.x = 99
	clone.glyph_indices_[0] = 42
	clone.glyph_positions_[0] = 88

	assert original.glyphs_[0].position.x == 2.5
	assert original.glyph_indices()[0] == 7
	assert original.glyph_positions()[0] == 2.5
	assert clone.font() == font
	assert clone.text_type() == .rtl
	assert clone.face() == .emoji
	assert clone.width() == original.width()
}

fn test_shape_text_applies_word_spacing_and_records_trailing_whitespace() {
	font := &Font{
		family: 'sans-serif'
		point_size: 16
	}
	for text in ['a b', 'a b', 'a\nb'] {
		unspaced := shape_text_with_spacing(0, 0, 0, text, font, .ltr)
		spaced := shape_text_with_spacing(0, 0, 6, text, font, .ltr)
		assert spaced.glyph_run.width() == unspaced.glyph_run.width() + 6
	}
	unspaced_word := shape_text_with_spacing(0, 0, 0, 'ab', font, .ltr)
	spaced_word := shape_text_with_spacing(0, 0, 6, 'ab', font, .ltr)
	assert spaced_word.glyph_run.width() == unspaced_word.glyph_run.width()

	shaped := shape_text_with_spacing(0, 1.25, 6, 'ab  ', font, .ltr)
	assert shaped.trailing_whitespace.length_in_code_units == 2
	glyphs := shaped.glyph_run.glyphs()
	assert shaped.trailing_whitespace.advance == glyphs[glyphs.len - 2].advance + glyphs.last().advance
}

fn test_shape_text_retains_but_does_not_paint_default_ignorables() {
	font := &Font{
		family: 'sans-serif'
		point_size: 24
	}
	plain := shape_text(0, 0, 'Search in r/programming', font, .ltr)
	isolated := shape_text(0, 0, 'Search in ⁨r/programming⁩', font, .ltr)
	assert isolated.width() == plain.width()
	ignored := isolated.glyphs().filter(!it.should_paint)
	assert ignored.len == 2
	assert ignored.all(it.advance == 0)
	assert ignored[0].code_point == 0x2068
	assert ignored[1].code_point == 0x2069
	assert isolated.glyph_indices().len == isolated.glyphs().len - ignored.len
	assert isolated.glyph_positions().len == isolated.glyph_indices().len * 2
	assert code_point_is_default_ignorable(0x200b)
	assert code_point_is_default_ignorable(0xfe0f)
	assert !code_point_is_default_ignorable(u32(`A`))
}

fn test_harfbuzz_font_scale_clamps_before_integer_conversion() {
	assert scale_for_harfbuzz(f32(100_000_000)) == 2147483647
	assert scale_for_harfbuzz(f32(-100_000_000)) == -2147483648
	assert scale_for_harfbuzz(f32(16)) == 1024
	font := &Font{
		family: 'sans-serif'
		point_size: 100_000_000
	}
	run := shape_text(0, 0, 'AAAA', font, .ltr)
	assert run.glyphs().len == 4
	assert run.width() > 0
}

fn cached_shape_for_test(glyph_count int) CachedShape {
	return CachedShape{
		glyphs: []Glyph{len: glyph_count}
		face: .document
	}
}

fn cache_shape_for_test(mut cache ShapingCache, font_key string, text string, params ShapeParams, glyph_count int) {
	if _ := cache.lookup(font_key, text, params) {
		return
	}
	cache.store(font_key, text, params, cached_shape_for_test(glyph_count))
}

fn test_shaping_cache_reuses_text_and_separates_spacing_parameters() {
	mut cache := ShapingCache{}
	plain := ShapeParams.new(.common, 0, 0)
	spaced := ShapeParams.new(.common, 2, 0)
	cache_shape_for_test(mut cache, 'font', 'word', plain, 4)
	assert cache.lookup('font', 'word', plain) or { panic('missing cached shape') }.glyphs.len == 4
	assert cache.lookup('font', 'word', spaced) == none
	cache.store('font', 'word', spaced, cached_shape_for_test(2))
	assert cache.lookup('font', 'word', spaced) or { panic('missing spaced shape') }.glyphs.len == 2
	negative_zero := ShapeParams.new(.common, math.f32_from_bits(u32(0x8000_0000)), 0)
	assert cache.lookup('font', 'word', negative_zero) == none

	cache_shape_for_test(mut cache, 'font', 'a', plain, 1)
	font_index := cache.font_index('font')
	assert cache.fonts[font_index].single_ascii_present[int(`a`)]
	assert 'a' !in cache.fonts[font_index].text_indices
	assert cache.lookup('font', 'a', negative_zero) or { panic('signed zero should use ASCII cache') }.glyphs.len == 1
	cache_shape_for_test(mut cache, 'font', 'a', spaced, 1)
	assert 'a' in cache.fonts[font_index].text_indices
}

fn test_shaping_cache_evicts_least_recently_used_font_at_capacity() {
	mut cache := ShapingCache{}
	params := ShapeParams.new(.common, 0, 0)
	for index in 0 .. max_shape_cache_fonts {
		cache_shape_for_test(mut cache, 'font-${index}', 'a', params, 1)
	}
	assert cache.lookup('font-0', 'a', params) or { panic('missing most recent font') }.glyphs.len == 1
	cache_shape_for_test(mut cache, 'font-overflow', 'a', params, 1)
	assert cache.fonts.len == max_shape_cache_fonts
	assert cache.font_index('font-0') >= 0
	assert cache.font_index('font-1') == -1
}

fn test_shaping_cache_evicts_least_recently_used_half_of_texts() {
	mut cache := ShapingCache{}
	params := ShapeParams.new(.common, 0, 0)
	for index in 0 .. max_shape_cache_texts_per_font {
		cache_shape_for_test(mut cache, 'font', 'text-${index}', params, 1)
	}
	assert cache.lookup('font', 'text-0', params) or { panic('missing refreshed text') }.glyphs.len == 1
	cache_shape_for_test(mut cache, 'font', 'one-more', params, 1)
	font_index := cache.font_index('font')
	assert cache.fonts[font_index].shapes_by_text.len == max_shape_cache_texts_per_font / 2
	assert 'text-0' in cache.fonts[font_index].text_indices
	assert 'text-1' !in cache.fonts[font_index].text_indices
	assert 'one-more' in cache.fonts[font_index].text_indices
}

fn test_shared_shaping_cache_returns_independent_translated_runs() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{
		family: 'sans-serif'
		point_size: 16
	}
	first := shape_text_with_spacing(0, 0, 0, 'cache me', font, .ltr)
	original_x := first.glyph_run.glyphs_[0].position.x
	mut first_run := first.glyph_run
	first_run.glyphs_[0].position.x = 999
	translated := shape_text_with_spacing(17, 0, 0, 'cache me', font, .ltr)
	assert translated.glyph_run.glyphs()[0].position.x == original_x + 17
	assert shaped_text_width(0, 0, 'cache me', font, .ltr) == translated.glyph_run.width()
	spaced := shape_text_with_spacing(0, 2, 0, 'cache me', font, .ltr)
	assert spaced.glyph_run.width() > translated.glyph_run.width()
}

fn test_single_glyph_width_uses_the_shared_shaping_cache() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{
		family: 'sans-serif'
		point_size: 16
	}
	width := font.glyph_width(u32(`A`))
	assert width == shape_text(0, 0, 'A', font, .common).width()
	font_index := platform_shaping_cache.font_index(shaping_cache_font_key(font))
	assert font_index >= 0
	assert platform_shaping_cache.fonts[font_index].single_ascii_present[int(`A`)]
	assert font.glyph_width(0x11_0000) == font.glyph_width(0xfffd)
}

fn test_timer_state_and_single_shot_fire() {
	mut timer := Timer.create_single_shot(10, no_op)
	assert timer.interval() == 10
	timer.start()
	assert timer.is_active()
	assert timer.has_activity_root()
	timer.fire()
	assert !timer.is_active()
	assert !timer.has_activity_root()
	timer.set_single_shot(false)
	timer.restart_with_interval(20)
	timer.fire()
	assert timer.is_active()
	assert timer.has_activity_root()
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
