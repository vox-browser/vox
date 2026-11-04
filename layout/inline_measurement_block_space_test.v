module layout

import css
import dom

fn test_inline_measurement_reuses_text_across_unused_available_block_sizes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	container := measurement_inline_fixture(document, '')
	for mode in [LayoutMode.normal,.intrinsic_sizing] {
		for width in [AvailableSize.make_definite(CSSPixels.new(180)),AvailableSize.make_min_content(),AvailableSize.make_max_content()] {
			mut source := LayoutState.new()
			source.enable_measurement_chunk_pool()
			defer { source.release_measurement_chunk_pool() }
			assert !measurement_height_compare(mut source,container,AvailableSpace.new(width,AvailableSize.make_indefinite()),mode,CSSPixels.new(17),false)
			for height in [AvailableSize.make_definite(CSSPixels.new(0)),AvailableSize.make_definite(CSSPixels.new(37)),AvailableSize.make_definite(CSSPixels.new(950)),AvailableSize.make_min_content(),AvailableSize.make_max_content()] {
				assert measurement_height_compare(mut source,container,AvailableSpace.new(width,height),mode,CSSPixels.new(17),false) == (!disable_inline_measurement_reuse && !retain_inline_measurement_block_space)
			}
		}
	}
}

fn test_inline_measurement_keeps_definite_block_bases_in_available_space_key() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	container := measurement_inline_fixture(document,'')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	width := AvailableSize.make_definite(CSSPixels.new(180))
	for height in [AvailableSize.make_indefinite(),AvailableSize.make_definite(CSSPixels.new(0)),AvailableSize.make_definite(CSSPixels.new(37)),AvailableSize.make_min_content(),AvailableSize.make_max_content()] {
		space := AvailableSpace.new(width,height)
		assert !measurement_height_compare(mut source,container,space,.normal,CSSPixels.new(17),true)
		assert measurement_height_compare(mut source,container,space,.normal,CSSPixels.new(17),true) == !disable_inline_measurement_reuse
	}
}

fn test_inline_measurement_block_space_reuse_preserves_live_text_and_environment_guards() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut container := measurement_inline_fixture(document,'')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	defer { source.release_measurement_chunk_pool() }
	width := AvailableSize.make_definite(CSSPixels.new(180))
	first := AvailableSpace.new(width,AvailableSize.make_definite(CSSPixels.new(100)))
	second := AvailableSpace.new(width,AvailableSize.make_definite(CSSPixels.new(200)))
	assert !measurement_height_compare(mut source,container,first,.normal,CSSPixels.new(0),false)
	assert measurement_height_compare(mut source,container,second,.normal,CSSPixels.new(0),false) == (!disable_inline_measurement_reuse && !retain_inline_measurement_block_space)
	mut text := container.children()[0].as_text_node()?
	mut data := text.dom_node()?.as_character_data()?
	data.set_data('Changed text across available heights')
	text.invalidate_text_for_rendering()
	assert !measurement_height_compare(mut source,container,first,.normal,CSSPixels.new(0),false)
	document.bump_style_environment_version()
	assert !measurement_height_compare(mut source,container,second,.normal,CSSPixels.new(0),false)
	mut computer := css.css_style_computer_for(document).font_computer()
	computer.did_load_font('ChangedMeasurementEnvironment')
	assert !measurement_height_compare(mut source,container,first,.normal,CSSPixels.new(0),false)
}
