module layout

import css
import dom
import html
import platform

fn measurement_image_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic(id) }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('layout') }.real_layout_handle()) }
}

fn measurement_image_pixels(height int) html.DecodedImageData {
	return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{
		frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
			width: 8
			height: height
			pitch: 32
			data: []u8{len: 32 * height, init: 255}
		})
	}], 0, false)
}

fn measurement_image_document(kind string, pending bool, contents string) &dom.Document {
	address := dom.URL{value: 'https://measurement-images.example/'}
	document := html.parse_navigation_document('<!doctype html><main><section id="root" style="display:${kind};position:relative;grid-template-columns:1fr 2fr;gap:7px;align-items:start">${contents}<p>Wrapping alpha beta gamma 😀 á words.</p></section></main>', address, address.origin(), none) or { panic(err) }
	element := document.get_element_by_id('photo') or { panic('photo') }
	mut image := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	if pending {
		image.set_async_fetch_hook(fn (_ dom.URL, _ html.HTMLImageFetchCompletion) {})
	} else {
		image.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return measurement_image_pixels(6) })
	}
	image.update_the_image_data(false, false)
	assert image.is_image_pending() == pending
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	_ = layout_document_typed_in_viewport(document, 500, 400)
	owner.finish()
	return document
}

fn measurement_image_prepare(mut state LayoutState, root &Node, width int, height int) &UsedValues {
	parent := root.containing_block() or { panic('parent') }
	mut ancestors := LayoutState.new()
	mut basis := ancestors.get_mutable(unsafe { &NodeWithStyle(parent) })
	basis.set_content_width(CSSPixels.new(500))
	basis.set_content_height(CSSPixels.new(300))
	basis.set_has_definite_width(true)
	basis.set_has_definite_height(true)
	populate_intrinsic_containing_block_chain(mut state, mut ancestors, root)
	mut used := state.get_mutable(root.as_node_with_style() or { panic('style') })
	used.set_containing_block_used_values(state.get(unsafe { &NodeWithStyle(parent) }))
	used.set_content_width(CSSPixels.new(width))
	used.set_content_height(CSSPixels.new(height))
	used.set_has_definite_width(true)
	used.set_has_definite_height(height > 0)
	used.offset = css.CSSPixelPoint.from_values(11, 13)
	resolve_box_model_edges(root.computed_values(), mut used, 500)
	return used
}

fn measurement_image_geometry(state &LayoutState, root &Node) []string {
	mut result := []string{}
	if styled := root.as_node_with_style() {
		if used := state.try_get(styled) {
			result << '${used.content_width()} ${used.content_height()} ${used.has_definite_width()} ${used.has_definite_height()} ${used.offset} ${used.static_position()}'
			result << '${used.margin_left} ${used.margin_right} ${used.margin_top} ${used.margin_bottom} ${used.padding_left} ${used.padding_right} ${used.padding_top} ${used.padding_bottom}'
			result << '${used.inset_left} ${used.inset_right} ${used.inset_top} ${used.inset_bottom} ${used.grid_template_columns()} ${used.grid_template_rows()}'
			for line in used.line_boxes {
				result << '${line.width()} ${line.height()} ${line.baseline()}'
				for fragment in line.fragments_ {
					result << '${fragment.start()} ${fragment.length_in_code_units()} ${fragment.offset()} ${fragment.inline_length()}'
					if run := fragment.glyph_run() { result << '${run.glyphs()} ${run.glyph_positions()}' }
				}
			}
		}
	}
	for child in root.children() { result << measurement_image_geometry(state, child) }
	return result
}

fn measurement_image_run(mut state LayoutState, root &Node, mut used UsedValues,
	space AvailableSpace, cached bool) FormattingContextResult {
	if root.display().is_grid_inside() {
		if cached { return run_grid_formatting_context_internal(mut state, root, mut used, .normal, space, false) }
		return run_uncached_grid_formatting_context_internal(mut state, root, mut used, .normal, space, false)
	}
	if cached { return run_flex_formatting_context_with_mode(mut state, root, mut used, .normal, space) }
	return run_uncached_flex_formatting_context_with_mode(mut state, root, mut used, .normal, space)
}

fn measurement_image_compare(mut source LayoutState, root &Node, width int, height int) bool {
	styled := root.as_node_with_style() or { panic('style') }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)),
		if height > 0 { AvailableSize.make_definite(CSSPixels.new(height)) } else { AvailableSize.make_indefinite() })
	mut probe := source.new_measurement_for_subtree(styled)
	mut used := measurement_image_prepare(mut probe, root, width, height)
	actual := measurement_image_run(mut probe, root, mut used, space, true)
	mut retained := platform.enter_retained_allocations()
	before_absolute := measurement_image_geometry(probe, root)
	retained.finish()
	mut reused := false
	mut snapshots := []RetainedBlockValues{}
	key := u64(voidptr(root))
	if root.display().is_grid_inside() {
		for entry in source.measurement_chunk_pool_.grid_measurements_[key] or { []&GridMeasurementLayout{} } { snapshots << entry.values }
	} else {
		for entry in source.measurement_chunk_pool_.flex_measurements_[key] or { []&FlexMeasurementLayout{} } { snapshots << entry.values }
	}
	for entry in snapshots {
		if entry.values.line_boxes.len == 0 { continue }
		if current := probe.try_get(entry.node) {
			if current.line_boxes.data == entry.values.line_boxes.data { reused = true }
		}
	}
	layout_absolutely_positioned_descendants(mut probe, root)
	retained = platform.enter_retained_allocations()
	after_absolute := measurement_image_geometry(probe, root)
	retained.finish()
	// Mutable consumers must not corrupt either retained lines or glyph storage.
	for entry in snapshots {
		if entry.values.line_boxes.len == 0 { continue }
		if current := probe.try_get(entry.node) {
			if current.line_boxes.data != entry.values.line_boxes.data { continue }
			mut writable := probe.get_mutable(entry.node)
			writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(999)
			assert entry.values.line_boxes[0].fragments_[0].inline_length_ != CSSPixels.new(999)
		}
	}
	probe.release_measurement()
	gc_collect()
	mut oracle := LayoutState.new_for_subtree(styled)
	mut expected := measurement_image_prepare(mut oracle, root, width, height)
	assert actual == measurement_image_run(mut oracle, root, mut expected, space, false)
	assert before_absolute == measurement_image_geometry(oracle, root)
	layout_absolutely_positioned_descendants(mut oracle, root)
	assert after_absolute == measurement_image_geometry(oracle, root)
	oracle.release_measurement()
	return reused
}

fn measurement_image_enabled(kind string) bool {
	return !disable_extended_image_measurements && !disable_retained_block_images
		&& if kind == 'grid' { !disable_grid_measurement_reuse } else { !disable_flex_measurement_reuse && !disable_flex_image_measurement_reuse }
}

fn test_image_measurements_own_pending_and_absolute_geometry_after_scratch_release() {
	for kind in ['grid', 'flex'] {
		for pending in [true, false] {
			for style in ['width:40px;height:auto;flex:none',
				'position:absolute;width:40%;height:auto;left:10%;top:5px',
				'position:absolute;width:40%;height:25%;inset:auto'] {
				if !pending && !style.contains('absolute') { continue }
				mut document := measurement_image_document(kind, pending, '<img id="photo" src="a.png" style="${style}">')
				mut owner := document.enter_native_storage()
				root := measurement_image_node(document, 'root')
				mut source := LayoutState.new()
				source.enable_measurement_chunk_pool()
				source.measurement_chunk_pool_.scratch_enabled_ = true
				for height in [0, 160] {
					assert !measurement_image_compare(mut source, root, 180, height)
					for _ in 0 .. 3 { assert measurement_image_compare(mut source, root, 180, height) == measurement_image_enabled(kind), '${kind} pending=${pending} ${style}' }
				}
				source.release_measurement_chunk_pool()
				owner.finish()
				document.finalize()
				document.release_native_storage()
			}
		}
	}
}

fn test_image_measurements_recheck_live_requests_sources_sizes_and_provider_kind() {
	for kind in ['grid', 'flex'] {
		for change in ['decode', 'natural', 'broken', 'svg', 'source', 'srcset', 'sizes', 'box-size', 'resolution'] {
			mut document := measurement_image_document(kind, change != 'natural', '<img id="photo" src="a.png" style="position:absolute;width:40%;height:auto;left:0;top:0">')
			mut owner := document.enter_native_storage()
			root := measurement_image_node(document, 'root')
			photo := measurement_image_node(document, 'photo')
			mut source := LayoutState.new()
			source.enable_measurement_chunk_pool()
			assert !measurement_image_compare(mut source, root, 180, 0)
			assert measurement_image_compare(mut source, root, 180, 0) == measurement_image_enabled(kind)
			mut element := document.get_element_by_id('photo') or { panic('photo') }
			mut image := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
			match change {
				'decode', 'natural' { mut request := image.current_request(); request.set_image_data(html.SharedResourceImageData{data: measurement_image_pixels(12)}); request.set_state(.completely_available) }
				'broken' { mut request := image.current_request(); request.set_state(.broken) }
				'svg' {
					svg_document := html.parse_document('<svg xmlns="http://www.w3.org/2000/svg" width="8" height="6"/>')
					mut request := image.current_request()
					request.set_image_data(html.SharedResourceImageData{data: html.SVGDecodedImageData.create(svg_document, 8.0, 6.0, 8.0/6.0)})
					request.set_state(.completely_available)
				}
				'source' { element.set_attribute_value('src', 'other.png') }
				'srcset' { element.set_attribute_value('srcset', 'other.png 2x') }
				'sizes' { element.set_attribute_value('sizes', '120px') }
				'box-size' { mut box := photo.as_image_box() or { panic('box') }; box.natural_size_ = size_with_optional_aspect_ratio(CSSPixels.new(8), CSSPixels.new(20)) }
				'resolution' { mut box := photo.as_image_box() or { panic('box') }; box.source_resolution_ = 2 }
				else {}
			}
			key := u64(voidptr(root))
			if kind == 'grid' {
				for entry in source.measurement_chunk_pool_.grid_measurements_[key] or { []&GridMeasurementLayout{} } { assert !grid_measurement_inputs_are_current(entry.inputs), change }
			} else {
				for entry in source.measurement_chunk_pool_.flex_measurements_[key] or { []&FlexMeasurementLayout{} } { assert !grid_measurement_inputs_are_current(entry.inputs), change }
			}
			assert !measurement_image_compare(mut source, root, 180, 0)
			source.release_measurement_chunk_pool()
			owner.finish()
			document.finalize()
			document.release_native_storage()
		}
	}
}

fn test_image_measurements_keep_external_containing_blocks_and_fixed_images_uncached() {
	for kind in ['grid', 'flex'] {
		for style in ['position:fixed;width:40px', 'position:absolute;width:40%'] {
			mut document := measurement_image_document(kind, true, '<img id="photo" src="a.png" style="${style}">')
			mut owner := document.enter_native_storage()
			root := measurement_image_node(document, 'root')
			if !style.contains('fixed') {
				// Reparent the absolute image's containing-block dependency outside
				// the captured subtree without changing its ordinary DOM parent.
				mut root_style := root.as_node_with_style() or { panic('style') }
				mut element := document.create_element('section')!
				element.set_attribute_value('style', 'display:${kind};position:static')
				root_style.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
				recompute_containing_blocks(root)
			}
			mut inputs := []RetainedInlineInput{}
			mut rejected := map[u64]bool{}
			assert !collect_grid_measurement_inputs(root, mut inputs, mut rejected)
			rejected = map[u64]bool{}
			inputs = []RetainedInlineInput{}
			assert !collect_retained_block_inputs(root, mut inputs, mut rejected)
			owner.finish()
			document.finalize()
			document.release_native_storage()
		}
	}
}

fn test_image_measurements_promote_nested_absolute_geometry_into_final_layout() {
	for kind in ['grid', 'flex'] {
		for pending in [true, false] {
			mut document := measurement_image_document(kind, pending, '<div style="position:relative;height:90px;width:60px"><img id="photo" src="a.png" style="position:absolute;left:10%;top:25%;width:80%;height:auto"></div>')
			mut owner := document.enter_native_storage()
			root := measurement_image_node(document, 'root')
			mut source := LayoutState.new()
			source.enable_measurement_chunk_pool()
			source.measurement_chunk_pool_.scratch_enabled_ = true
			assert !measurement_image_compare(mut source, root, 180, 160)
			mut snapshots := []RetainedBlockValues{}
			key := u64(voidptr(root))
			if kind == 'grid' {
				for entry in source.measurement_chunk_pool_.grid_measurements_[key] or { []&GridMeasurementLayout{} } { snapshots << entry.values }
			} else {
				for entry in source.measurement_chunk_pool_.flex_measurements_[key] or { []&FlexMeasurementLayout{} } { snapshots << entry.values }
			}
			space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(180)), AvailableSize.make_definite(CSSPixels.new(160)))
			mut used := measurement_image_prepare(mut source, root, 180, 160)
			actual := measurement_image_run(mut source, root, mut used, space, true)
			mut reused := false
			for entry in snapshots {
				if entry.values.line_boxes.len == 0 { continue }
				if current := source.try_get(entry.node) {
					if current.line_boxes.data == entry.values.line_boxes.data { reused = true }
				}
			}
			committed_enabled := if kind == 'grid' { !disable_committed_grid_measurement_reuse } else { !disable_committed_flex_measurement_reuse }
			assert reused == (measurement_image_enabled(kind) && committed_enabled)
			layout_absolutely_positioned_descendants(mut source, root)
			geometry := measurement_image_geometry(source, root)
			source.release_measurement_chunk_pool()
			gc_collect()
			assert geometry == measurement_image_geometry(source, root)
			mut oracle := LayoutState.new_for_subtree(root.as_node_with_style() or { panic('style') })
			mut expected := measurement_image_prepare(mut oracle, root, 180, 160)
			assert actual == measurement_image_run(mut oracle, root, mut expected, space, false)
			layout_absolutely_positioned_descendants(mut oracle, root)
			assert geometry == measurement_image_geometry(oracle, root)
			oracle.release_measurement()
			owner.finish()
			document.finalize()
			document.release_native_storage()
		}
	}
}
