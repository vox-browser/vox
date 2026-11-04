module layout

import css
import dom
import html
import platform

fn flex_measurement_test_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing '+id) }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn flex_measurement_test_prepare(mut state LayoutState, root &Node, width int, height int,
	change string) &UsedValues {
	styled := root.as_node_with_style() or { panic('style') }
	parent := root.containing_block() or { panic('parent') }
	mut ancestors := LayoutState.new()
	mut parent_values := ancestors.get_mutable(unsafe { &NodeWithStyle(parent) })
	parent_values.set_content_width(CSSPixels.new(if change == 'parent-width' { 501 } else { 500 }))
	parent_values.set_content_height(CSSPixels.new(if change == 'parent-height' { 301 } else { 300 }))
	parent_values.set_has_definite_height(true)
	populate_intrinsic_containing_block_chain(mut state, mut ancestors, root)
	parent_values = state.get_mutable(unsafe { &NodeWithStyle(parent) })
	mut used := state.get_mutable(styled)
	used.set_containing_block_used_values(parent_values)
	used.set_content_width(CSSPixels.new(width))
	used.set_content_height(CSSPixels.new(height))
	used.set_has_definite_height(height > 0)
	used.offset = css.CSSPixelPoint.from_values(11, 13)
	used.set_relative_inset_basis(CSSPixels.new(731), CSSPixels.new(919))
	resolve_box_model_edges(root.computed_values(), mut used, parent_values.content_width().to_double())
	if change == 'constraint' { used.width_constraint = .min_content }
	if change == 'edge' { used.padding_left = used.padding_left.plus(CSSPixels.new(1)) }
	if change == 'ancestor' {
		outer := unsafe { &Node(parent) }.containing_block() or { panic('outer') }
		mut values := state.get_mutable(unsafe { &NodeWithStyle(outer) })
		values.set_content_width(CSSPixels.new(800))
	}
	return used
}

fn flex_measurement_test_geometry(state &LayoutState, root &Node) []string {
	mut result := []string{}
	if styled := root.as_node_with_style() {
		if used := state.try_get(styled) {
			result << '${used.content_width()} ${used.content_height()} ${used.has_definite_width()} ${used.has_definite_height()} ${used.offset} ${used.relative_inset_basis_width()} ${used.relative_inset_basis_height()}'
			if used.has_computed_svg_transforms() {
				result << '${used.svg_transform()} ${used.svg_viewport_transform()} ${used.svg_rendering_disabled()}'
			}
			if path := used.computed_svg_path() { result << path.serialize() }
			for line in used.line_boxes {
				result << '${line.width()} ${line.height()} ${line.baseline()}'
				for fragment in line.fragments_ {
					result << '${fragment.start()} ${fragment.length_in_code_units()} ${fragment.offset()} ${fragment.inline_length()}'
					if run := fragment.glyph_run() {
						result << '${u64(voidptr(run.font()))} ${run.glyphs()} ${run.glyph_positions()} ${run.bounding_box()}'
					}
				}
			}
		}
	}
	for child in root.children() { result << flex_measurement_test_geometry(state, child) }
	return result
}

fn flex_measurement_test_compare(mut source LayoutState, root &Node, width int, height int,
	mode LayoutMode, change string) bool {
	styled := root.as_node_with_style() or { panic('style') }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)),
		if height > 0 { AvailableSize.make_definite(CSSPixels.new(height)) } else { AvailableSize.make_indefinite() })
	mut probe := source.new_measurement_for_subtree(styled)
	mut used := flex_measurement_test_prepare(mut probe, root, width, height, change)
	actual := run_flex_formatting_context_with_mode(mut probe, root, mut used, mode, space)
	assert used.offset == css.CSSPixelPoint.from_values(11, 13)
	assert (used.relative_inset_basis_width() or { panic('basis') }) == CSSPixels.new(731)
	assert (used.relative_inset_basis_height() or { panic('basis') }) == CSSPixels.new(919)
	mut snapshots := platform.enter_retained_allocations()
	geometry := flex_measurement_test_geometry(probe, root)
	snapshots.finish()
	mut reused := false
	if source.measurement_chunk_pool_ != unsafe { nil } {
		for entry in source.measurement_chunk_pool_.flex_measurements_[u64(voidptr(root))] or { []&FlexMeasurementLayout{} } {
			mut replayed_entry := false
			for candidate in entry.values {
				if candidate.values.line_boxes.len == 0 { continue }
				if current := probe.try_get(candidate.node) {
					if current.line_boxes.data == candidate.values.line_boxes.data { replayed_entry = true }
				}
			}
			for snapshot in entry.values {
				if saved := snapshot.values.computed_svg_path() {
					if !replayed_entry { continue }
					if current := probe.try_get(snapshot.node) {
						if path := current.computed_svg_path() {
							before := saved.serialize()
							for instruction in path.instructions {
								if instruction.data.len == 0 { continue }
								mut borrowed := unsafe { instruction.data }
								borrowed[0] += 123
								break
							}
							assert saved.serialize() == before
						}
					}
				}
				if snapshot.values.line_boxes.len == 0 { continue }
				if current := probe.try_get(snapshot.node) {
					if current.line_boxes.data == snapshot.values.line_boxes.data {
						reused = true
						mut writable := probe.get_mutable(snapshot.node)
						writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(999)
						assert snapshot.values.line_boxes[0].fragments_[0].inline_length_ != CSSPixels.new(999)
					}
				}
			}
		}
	}
	probe.release_measurement()
	gc_collect()
	mut oracle := LayoutState.new_for_subtree(styled)
	mut expected := flex_measurement_test_prepare(mut oracle, root, width, height, change)
	result := run_uncached_flex_formatting_context_with_mode(mut oracle, root, mut expected, mode, space)
	assert actual == result
	assert geometry == flex_measurement_test_geometry(oracle, root)
	oracle.release_measurement()
	return reused
}

fn test_flex_measurement_owns_replayed_geometry_after_scratch_release() {
	for rules in ['gap:7px', 'flex-wrap:wrap;direction:rtl;gap:3px',
		'flex-direction:column;gap:2px', 'flex-direction:column;flex-wrap:wrap;gap:3px'] {
		// CSS ignores float on a flex item; it remains eligible normal flow.
		mut document := html.parse_document('<!doctype html><main><section id="flex" style="display:flex;${rules}"><p style="float:left">Wrapping words alpha beta gamma 😀 á אבג.</p><p>More text to wrap.</p></section></main>')
		document.set_font_rendering_policy(.chromium)
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer { owner.finish(); document.finalize(); document.release_native_storage() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := flex_measurement_test_node(document, 'flex')
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		for height in [0, 160] {
			assert !flex_measurement_test_compare(mut source, root, 180, height, .normal, '')
			for _ in 0 .. 3 {
				assert flex_measurement_test_compare(mut source, root, 180, height, .normal, '') == !disable_flex_measurement_reuse
			}
		}
		pool := source.measurement_chunk_pool_
		source.release_measurement_chunk_pool()
		assert pool.closed && pool.flex_measurements_.len == 0 && pool.flex_measurement_rejections_.len == 0
	}
}

fn test_flex_measurement_revalidates_text_style_fonts_tree_and_geometry() {
	for change in ['width', 'height', 'parent-width', 'parent-height', 'ancestor', 'constraint',
		'edge', 'text', 'style', 'font', 'environment', 'tree', 'mode'] {
		mut document := html.parse_document('<!doctype html><main><section id="flex" style="display:flex;gap:7px"><p id="item">Original wrapping words alpha beta gamma.</p><p>Other content.</p></section></main>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := flex_measurement_test_node(document, 'flex')
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		assert !flex_measurement_test_compare(mut source, root, 180, 0, .normal, '')
		assert flex_measurement_test_compare(mut source, root, 180, 0, .normal, '') == !disable_flex_measurement_reuse
		if change == 'text' {
			mut text := flex_measurement_test_node(document, 'item').children()[0].as_text_node()?
			mut data := text.dom_node()?.as_character_data()?
			data.set_data('Changed text with different wrapping and extraordinary words.')
			text.invalidate_text_for_rendering()
		}
		if change == 'style' {
			mut element := document.create_element('p')!
			element.set_attribute_value('style', 'display:block;font-size:23px')
			mut item := flex_measurement_test_node(document, 'item').as_node_with_style()?
			item.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
		}
		if change == 'font' {
			mut computer := css.css_style_computer_for(document).font_computer()
			computer.did_load_font('FlexMeasurementFace')
		}
		if change == 'environment' { document.bump_style_environment_version() }
		if change == 'tree' {
			mut mutable_root := unsafe { &Node(root) }
			mutable_root.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node('extra').as_node(), 'extra')) })
			mut top := unsafe { &Node(root) }
			for { parent := top.parent() or { break }; top = unsafe { &Node(parent) } }
			assign_layout_indexes(top)
			recompute_containing_blocks(top)
		}
		assert !flex_measurement_test_compare(mut source, root,
			if change == 'width' { 181 } else { 180 }, if change == 'height' { 160 } else { 0 },
			if change == 'mode' { LayoutMode.intrinsic_sizing } else { LayoutMode.normal }, change)
		for width in [80, 100, 120, 140, 160, 180] {
			_ = flex_measurement_test_compare(mut source, root, width, 0, .normal, '')
		}
		assert (source.measurement_chunk_pool_.flex_measurements_[u64(voidptr(root))] or { []&FlexMeasurementLayout{} }).len <= 4
		source.release_measurement_chunk_pool()
	}
}

fn test_flex_measurement_keeps_unpooled_and_specialized_layout_uncached() {
	for contents in ['<div style="position:absolute">Positioned.</div>',
		'<div style="position:relative;left:2px">Shifted relative.</div>', '<div><div style="float:left">Float in ordinary flow.</div></div>',
		'<svg width="20" height="20"><text>Unsupported text</text></svg>',
		'<p style="max-lines:1;continue:collapse">Clamped content.</p>', '<input value="Control">',
		'<img width="20" height="20">', '<p>Plain content.</p>'] {
		mut document := html.parse_document('<!doctype html><main><section id="flex" style="display:flex">${contents}<p>Other content.</p></section></main>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := flex_measurement_test_node(document, 'flex')
		mut source := LayoutState.new()
		assert !flex_measurement_test_compare(mut source, root, 180, 0, .normal, '')
		source.enable_measurement_chunk_pool()
		if contents != '<p>Plain content.</p>' {
			for _ in 0 .. 2 {
				assert !flex_measurement_test_compare(mut source, root, 180, 0, .normal, ''), contents
			}
		}
		mut used := flex_measurement_test_prepare(mut source, root, 180, 0, '')
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
		before := source.measurement_chunk_pool_.flex_measurements_.len
		_ = run_flex_formatting_context_with_mode(mut source, root, mut used, .normal, space)
		assert source.measurement_chunk_pool_.flex_measurements_.len == before
		source.release_measurement_chunk_pool()
	}
}

fn flex_measurement_image_pixels(height int) html.DecodedImageData {
	return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{
		frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
			width: 8
			height: height
			pitch: 32
			data: []u8{len: 32 * height, init: 255}
			native_resource_replay_compatible: true
		})
	}], 0, false)
}

fn test_flex_measurement_replays_decoded_image_geometry_after_scratch_release() {
	for rules in ['gap:7px', 'flex-wrap:wrap;direction:rtl;gap:3px',
		'flex-direction:column;gap:2px'] {
		address := dom.URL{value: 'https://flex-images.example/'}
		mut document := html.parse_navigation_document('<!doctype html><main><section id="flex" style="display:flex;${rules}"><img id="photo" src="a.png" style="width:40px;height:auto;flex:none"><p>Wrapping words alpha beta gamma 😀 á.</p></section></main>', address, address.origin(), none) or { panic(err) }
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer { owner.finish(); document.finalize(); document.release_native_storage() }
		element := document.get_element_by_id('photo') or { panic('photo') }
		mut image := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
		image.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return flex_measurement_image_pixels(6) })
		image.update_the_image_data(false, false)
		assert image.complete()
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := flex_measurement_test_node(document, 'flex')
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		for height in [0, 160] {
			assert !flex_measurement_test_compare(mut source, root, 180, height, .normal, '')
			for _ in 0 .. 3 {
				assert flex_measurement_test_compare(mut source, root, 180, height, .normal, '') == (!disable_flex_measurement_reuse && !disable_flex_image_measurement_reuse)
			}
		}
		source.release_measurement_chunk_pool()
	}
}

fn test_flex_measurement_revalidates_decoded_image_source_and_natural_size() {
	address := dom.URL{value: 'https://flex-images.example/'}
	mut document := html.parse_navigation_document('<!doctype html><main><section id="flex" style="display:flex;gap:7px;align-items:start"><img id="photo" src="a.png" style="width:40px;height:auto;flex:none"><p>Wrapping words alpha beta gamma.</p></section></main>', address, address.origin(), none) or { panic(err) }
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	mut element := document.get_element_by_id('photo') or { panic('photo') }
	mut image := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	image.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return flex_measurement_image_pixels(6) })
	image.update_the_image_data(false, false)
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := flex_measurement_test_node(document, 'flex')
	photo := flex_measurement_test_node(document, 'photo')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	assert !flex_measurement_test_compare(mut source, root, 180, 0, .normal, '')
	assert flex_measurement_test_compare(mut source, root, 180, 0, .normal, '') == (!disable_flex_measurement_reuse && !disable_flex_image_measurement_reuse)
	// Same-size source replacement must reject the previous capture, too.
	for taller in [false, true] {
		if taller {
			image.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return flex_measurement_image_pixels(12) })
		}
		element.set_attribute_value('src', if taller { 'taller.png' } else { 'other.png' })
		image.update_the_image_data(false, false)
		assert image.complete()
		for cached in source.measurement_chunk_pool_.flex_measurements_[u64(voidptr(root))] or { []&FlexMeasurementLayout{} } {
			assert !grid_measurement_inputs_are_current(cached.inputs)
		}
		// Normal document relayout resets this ImageBox before the flex probe.
		mut image_box := photo.as_image_box() or { panic('image box') }
		image_box.reset_for_relayout()
		assert !flex_measurement_test_compare(mut source, root, 180, 0, .normal, '')
		assert flex_measurement_test_compare(mut source, root, 180, 0, .normal, '') == (!disable_flex_measurement_reuse && !disable_flex_image_measurement_reuse)
	}
	source.release_measurement_chunk_pool()
}

fn test_flex_measurement_replays_unshifted_relative_root_and_descendants() {
	for root_style in ['', 'position:relative;'] {
		for rules in ['gap:7px', 'flex-direction:column;gap:3px'] {
			mut document := html.parse_document('<!doctype html><main><section id="flex" style="${root_style}display:flex;${rules}"><div style="position:relative"><p style="position:relative">Wrapping alpha beta gamma 😀.</p></div><p>Other text.</p></section></main>')
			document.enable_native_storage()
			mut owner := document.enter_native_storage()
			defer { owner.finish(); document.finalize(); document.release_native_storage() }
			_ = layout_document_typed_in_viewport(document, 500, 400)
			root := flex_measurement_test_node(document, 'flex')
			mut source := LayoutState.new()
			source.enable_measurement_chunk_pool()
			source.measurement_chunk_pool_.scratch_enabled_ = true
			for height in [0, 160] {
				assert !flex_measurement_test_compare(mut source, root, 180, height, .normal, '')
				for _ in 0 .. 3 {
					assert flex_measurement_test_compare(mut source, root, 180, height, .normal, '') == (!disable_flex_measurement_reuse && !disable_relative_measurement_reuse && !disable_relative_flow_layout_reuse)
				}
			}
			source.release_measurement_chunk_pool()
		}
	}
}

fn test_flex_measurement_rejects_relative_geometry_after_insets_change() {
	mut document := html.parse_document('<!doctype html><main><section id="flex" style="display:flex;gap:7px"><div id="item" style="position:relative"><p>Wrapping alpha beta gamma.</p></div><p>Other text.</p></section></main>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := flex_measurement_test_node(document, 'flex')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	assert !flex_measurement_test_compare(mut source, root, 180, 0, .normal, '')
	assert flex_measurement_test_compare(mut source, root, 180, 0, .normal, '') == (!disable_flex_measurement_reuse && !disable_relative_measurement_reuse && !disable_relative_flow_layout_reuse)
	mut element := document.create_element('div')!
	element.set_attribute_value('style', 'display:block;position:relative;left:3px')
	mut item := flex_measurement_test_node(document, 'item').as_node_with_style() or { panic('item') }
	item.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
	for _ in 0 .. 2 { assert !flex_measurement_test_compare(mut source, root, 180, 0, .normal, '') }
	source.release_measurement_chunk_pool()
}

fn test_flex_measurement_owns_closed_svg_shapes_across_scratch_release() {
	mut document := html.parse_document('<!doctype html><main><section id="flex" style="display:flex;position:relative;gap:7px"><svg id="icon" width="24" height="24" viewBox="0 0 24 24"><g transform="translate(1 2)"><path id="path" d="M0 0H18V12H0Z" fill="red"/><rect x="1" y="2" width="50%" height="6" fill="green"/><circle cx="6" cy="6" r="3" fill="blue"/></g></svg><p>Wrapping alpha beta gamma 😀.</p></section></main>')
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := flex_measurement_test_node(document, 'flex')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	source.measurement_chunk_pool_.scratch_enabled_ = true
	assert !flex_measurement_test_compare(mut source, root, 180, 0, .normal, '')
	for _ in 0 .. 4 { assert flex_measurement_test_compare(mut source, root, 180, 0, .normal, '') == (!disable_flex_measurement_reuse && !disable_svg_measurement_reuse && !disable_retained_simple_svg && !disable_relative_measurement_reuse && !disable_relative_flow_layout_reuse) }
	source.release_measurement_chunk_pool()
}

fn test_flex_measurement_revalidates_svg_attributes_before_replay() {
	for change in ['d', 'viewBox', 'transform', 'namespaced'] {
		mut document := html.parse_document('<!doctype html><main><section id="flex" style="display:flex;position:relative;gap:7px"><svg id="icon" width="24" height="24" viewBox="0 0 24 24"><g transform="translate(1 2)"><path id="path" d="M0 0H18V12H0Z" fill="red"/><rect x="1" y="2" width="50%" height="6" fill="green"/><circle cx="6" cy="6" r="3" fill="blue"/></g></svg><p>Wrapping alpha beta gamma 😀.</p></section></main>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := flex_measurement_test_node(document, 'flex')
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		assert !flex_measurement_test_compare(mut source, root, 180, 0, .normal, '')
		assert flex_measurement_test_compare(mut source, root, 180, 0, .normal, '') == (!disable_flex_measurement_reuse && !disable_svg_measurement_reuse && !disable_retained_simple_svg && !disable_relative_measurement_reuse && !disable_relative_flow_layout_reuse)
		mut target := document.get_element_by_id(if change == 'viewBox' { 'icon' } else { 'path' }) or { panic('target') }
		match change {
			'd' { target.set_attribute_value('d', 'M0 0H4V20H0Z') }
			'viewBox' { target.set_attribute_value('viewBox', '0 0 48 48') }
			'transform' { target.set_attribute_value('transform', 'translate(4 5)') }
			else { target.set_attribute_value_ns('test', 'value', 'x', 'urn:svg-measurement-test') }
		}
		for cached in source.measurement_chunk_pool_.flex_measurements_[u64(voidptr(root))] or { []&FlexMeasurementLayout{} } {
			assert !grid_measurement_inputs_are_current(cached.inputs)
		}
		document.update_style()
		assert !flex_measurement_test_compare(mut source, root, 180, 0, .normal, '')
		assert flex_measurement_test_compare(mut source, root, 180, 0, .normal, '') == (!disable_flex_measurement_reuse && !disable_svg_measurement_reuse && !disable_retained_simple_svg && !disable_relative_measurement_reuse && !disable_relative_flow_layout_reuse)
		source.release_measurement_chunk_pool()
	}
}

fn committed_flex_measurement_test_reused(state &LayoutState, cached &FlexMeasurementLayout) bool {
	for entry in cached.values {
		if entry.values.line_boxes.len == 0 { continue }
		if current := state.try_get(entry.node) {
			if current.line_boxes.data == entry.values.line_boxes.data { return true }
		}
	}
	return false
}

fn test_committed_flex_consumes_owned_measurement_without_replacing_caller_geometry() {
	for rules in ['gap:7px', 'flex-wrap:wrap;direction:rtl;gap:3px',
		'flex-direction:column;gap:2px', 'flex-direction:column;flex-wrap:wrap;gap:3px'] {
		for height in [0, 80] {
			mut document := html.parse_document('<!doctype html><main><section id="flex" style="display:flex;${rules}"><p>Wrapping words alpha beta gamma 😀.</p><p>Other words.</p></section></main>')
			document.enable_native_storage()
			mut owner := document.enter_native_storage()
			defer { owner.finish(); document.finalize(); document.release_native_storage() }
			_ = layout_document_typed_in_viewport(document, 500, 400)
			root := flex_measurement_test_node(document, 'flex')
			styled := root.as_node_with_style() or { panic('style') }
			mut source := LayoutState.new()
			source.enable_measurement_chunk_pool()
			source.measurement_chunk_pool_.scratch_enabled_ = true
			space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)),
				if height > 0 { AvailableSize.make_definite(CSSPixels.new(height)) } else { AvailableSize.make_indefinite() })
			mut producer := source.new_measurement_for_subtree(styled)
			mut measured := flex_measurement_test_prepare(mut producer, root, 180, height, '')
			result := run_flex_formatting_context_with_mode(mut producer, root, mut measured, .normal, space)
			entries := source.measurement_chunk_pool_.flex_measurements_[u64(voidptr(root))] or { []&FlexMeasurementLayout{} }
			producer.release_measurement()
			gc_collect()
			mut used := flex_measurement_test_prepare(mut source, root, 180, height, '')
			used.set_derived_baselines(CSSPixels.new(71), CSSPixels.new(93))
			actual := run_flex_formatting_context_with_mode(mut source, root, mut used, .normal, space)
			assert actual == result
			assert used.offset == css.CSSPixelPoint.from_values(11, 13)
			assert used.relative_inset_basis_width() or { panic('basis') } == CSSPixels.new(731)
			assert used.relative_inset_basis_height() or { panic('basis') } == CSSPixels.new(919)
			assert used.derived_first_baseline() == none && used.derived_last_baseline() == none
			if !disable_flex_measurement_reuse {
				assert entries.len == 1
				assert committed_flex_measurement_test_reused(source, entries[0]) == !disable_committed_flex_measurement_reuse
			}
			mut retained := platform.enter_retained_allocations()
			geometry := flex_measurement_test_geometry(source, root)
			retained.finish()
			source.release_measurement_chunk_pool()
			gc_collect()
			assert geometry == flex_measurement_test_geometry(source, root)
			mut oracle := LayoutState.new_for_subtree(styled)
			mut expected := flex_measurement_test_prepare(mut oracle, root, 180, height, '')
			expected.set_derived_baselines(CSSPixels.new(71), CSSPixels.new(93))
			assert actual == run_uncached_flex_formatting_context_with_mode(mut oracle, root, mut expected, .normal, space)
			assert geometry == flex_measurement_test_geometry(oracle, root)
			assert expected.derived_first_baseline() == none && expected.derived_last_baseline() == none
			oracle.release_measurement()
			if !disable_flex_measurement_reuse && !disable_committed_flex_measurement_reuse {
				for entry in entries[0].values {
					if entry.values.line_boxes.len == 0 { continue }
					before := entry.values.line_boxes[0].fragments_[0].inline_length_
					mut writable := source.get_mutable(entry.node)
					writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(999)
					assert entry.values.line_boxes[0].fragments_[0].inline_length_ == before
					break
				}
			}
		}
	}
}

fn test_committed_flex_misses_validate_measurement_inputs_without_mutating_the_pool() {
	for change in ['width', 'height', 'parent-width', 'parent-height', 'ancestor', 'constraint',
		'edge', 'text', 'font', 'environment', 'tree', 'mode'] {
		mut document := html.parse_document('<!doctype html><main><section id="flex" style="display:flex;gap:7px"><p id="item">Original wrapping words alpha beta gamma.</p><p>Other content.</p></section></main>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := flex_measurement_test_node(document, 'flex')
		styled := root.as_node_with_style() or { panic('style') }
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		mut producer := source.new_measurement_for_subtree(styled)
		mut measured := flex_measurement_test_prepare(mut producer, root, 180, 0, '')
		space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_indefinite())
		_ = run_flex_formatting_context_with_mode(mut producer, root, mut measured, .normal, space)
		producer.release_measurement()
		pool := source.measurement_chunk_pool_
		entries := pool.flex_measurements_[u64(voidptr(root))] or { []&FlexMeasurementLayout{} }
		count := pool.flex_measurements_.len
		rejections := pool.flex_measurement_rejections_.len
		if change == 'text' {
			mut text := flex_measurement_test_node(document, 'item').children()[0].as_text_node() or { panic('text') }
			mut data := (text.dom_node() or { panic('owner') }).as_character_data() or { panic('data') }
			data.set_data('Changed wrapping text with extraordinary words.')
			text.invalidate_text_for_rendering()
		}
		if change == 'font' {
			mut computer := css.css_style_computer_for(document).font_computer()
			computer.did_load_font('CommittedFlexMeasurementFace')
		}
		if change == 'environment' { document.bump_style_environment_version() }
		if change == 'tree' {
			mut mutable_root := unsafe { &Node(root) }
			mutable_root.append_child(unsafe { &Node(TextNode.new(document, document.create_text_node('extra').as_node(), 'extra')) })
			mut top := unsafe { &Node(root) }
			for { parent := top.parent() or { break }; top = unsafe { &Node(parent) } }
			assign_layout_indexes(top)
			recompute_containing_blocks(top)
		}
		width := if change == 'width' { 181 } else { 180 }
		height := if change == 'height' { 160 } else { 0 }
		mut used := flex_measurement_test_prepare(mut source, root, width, height, change)
		mode := if change == 'mode' { LayoutMode.intrinsic_sizing } else { LayoutMode.normal }
		actual := run_flex_formatting_context_with_mode(mut source, root, mut used, mode, space)
		assert pool.flex_measurements_.len == count && pool.flex_measurement_rejections_.len == rejections
		after := pool.flex_measurements_[u64(voidptr(root))] or { []&FlexMeasurementLayout{} }
		assert after.len == entries.len
		for index, entry in entries {
			assert voidptr(entry) == voidptr(after[index])
			assert !committed_flex_measurement_test_reused(source, entry)
		}
		mut oracle := LayoutState.new_for_subtree(styled)
		mut expected := flex_measurement_test_prepare(mut oracle, root, width, height, change)
		assert actual == run_uncached_flex_formatting_context_with_mode(mut oracle, root, mut expected, mode, space)
		assert flex_measurement_test_geometry(source, root) == flex_measurement_test_geometry(oracle, root)
		oracle.release_measurement()
		source.release_measurement_chunk_pool()
	}
}
