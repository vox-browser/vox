module layout

import css
import dom
import html
import platform

fn previous_measurement_test_node(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing element') }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn previous_measurement_test_values(mut state LayoutState, root &Node, width int) &UsedValues {
	parent := root.containing_block() or { panic('missing containing block') }
	mut ancestors := LayoutState.new()
	mut outer := ancestors.get_mutable(unsafe { &NodeWithStyle(parent) })
	outer.set_content_width(CSSPixels.new(500))
	outer.set_content_height(CSSPixels.new(300))
	outer.set_has_definite_width(true)
	outer.set_has_definite_height(true)
	populate_intrinsic_containing_block_chain(mut state, mut ancestors, root)
	outer = state.get_mutable(unsafe { &NodeWithStyle(parent) })
	mut used := state.get_mutable(root.as_node_with_style() or { panic('missing style') })
	used.set_containing_block_used_values(outer)
	used.set_content_width(CSSPixels.new(width))
	used.set_content_height(CSSPixels.new(0))
	used.set_has_definite_width(true)
	used.set_has_definite_height(false)
	resolve_box_model_edges(root.computed_values(), mut used, 500)
	return used
}

fn previous_measurement_test_geometry(state &LayoutState, root &Node) []string {
	mut geometry := []string{}
	if styled := root.as_node_with_style() {
		if values := state.try_get(styled) {
			geometry << '${values.content_width()} ${values.content_height()} ${values.offset} ${values.has_definite_width()} ${values.has_definite_height()}'
			geometry << '${values.grid_template_columns()} ${values.grid_template_rows()}'
			if values.has_computed_svg_transforms() { geometry << '${values.svg_transform()} ${values.svg_viewport_transform()}' }
			if path := values.computed_svg_path() { geometry << path.serialize() }
			for line in values.line_boxes {
				geometry << '${line.width()} ${line.height()} ${line.baseline()}'
				for fragment in line.fragments_ {
					geometry << '${fragment.start()} ${fragment.length_in_code_units()} ${fragment.offset()} ${fragment.inline_length()}'
					if run := fragment.glyph_run() {
						geometry << '${run.glyphs()} ${run.glyph_positions()}'
					}
				}
			}
		}
	}
	for child in root.children() { geometry << previous_measurement_test_geometry(state, child) }
	return geometry
}

fn previous_measurement_test_probe(mut source LayoutState, root &Node, width int, flex bool) bool {
	hits_before := source.measurement_chunk_pool_.previous_measurement_entries_.values().filter(it).len
	styled := root.as_node_with_style() or { panic('missing style') }
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(width)), AvailableSize.make_indefinite())
	mut probe := source.new_measurement_for_subtree(styled)
	mut used := previous_measurement_test_values(mut probe, root, width)
	actual := if flex {
		run_flex_formatting_context_with_mode(mut probe, root, mut used, .normal, space)
	} else {
		run_grid_formatting_context_internal(mut probe, root, mut used, .normal, space, false)
	}
	mut retained := platform.enter_retained_allocations()
	geometry := previous_measurement_test_geometry(probe, root)
	retained.finish()
	if source.measurement_chunk_pool_.previous_measurement_entries_.values().any(it) {
		mut snapshots := []RetainedBlockValues{}
		key := u64(voidptr(root))
		if flex {
			for entry in source.measurement_chunk_pool_.flex_measurements_[key] or { []&FlexMeasurementLayout{} } { snapshots << entry.values }
		} else {
			for entry in source.measurement_chunk_pool_.grid_measurements_[key] or { []&GridMeasurementLayout{} } { snapshots << entry.values }
		}
		for entry in snapshots {
			if saved := entry.values.computed_svg_path() {
				if current := probe.try_get(entry.node) {
					if path := current.computed_svg_path() {
						before := saved.serialize()
						for instruction in path.instructions {
							if instruction.data.len == 0 { continue }
							mut writable := unsafe { instruction.data }
							writable[0] += 123
							break
						}
						assert saved.serialize() == before
					}
				}
			}
			if entry.values.line_boxes.len == 0 || entry.values.line_boxes[0].fragments_.len == 0 { continue }
			if current := probe.try_get(entry.node) {
				if current.line_boxes.data != entry.values.line_boxes.data { continue }
				mut writable := probe.get_mutable(entry.node)
				writable.line_boxes[0].fragments_[0].inline_length_ = CSSPixels.new(999)
				assert entry.values.line_boxes[0].fragments_[0].inline_length_ != CSSPixels.new(999)
			}
		}
	}
	probe.release_measurement()
	gc_collect()
	mut oracle_source := LayoutState.new()
	oracle_source.enable_measurement_chunk_pool()
	mut oracle := oracle_source.new_measurement_for_subtree(styled)
	mut expected := previous_measurement_test_values(mut oracle, root, width)
	result := if flex {
		run_uncached_flex_formatting_context_with_mode(mut oracle, root, mut expected, .normal, space)
	} else {
		run_uncached_grid_formatting_context_internal(mut oracle, root, mut expected, .normal, space, false)
	}
	assert actual == result
	assert geometry == previous_measurement_test_geometry(oracle, root)
	oracle.release_measurement()
	oracle_source.release_measurement_chunk_pool()
	return source.measurement_chunk_pool_.previous_measurement_entries_.values().filter(it).len > hits_before
}

fn test_previous_measurements_survive_pool_and_scratch_release_with_exact_geometry() {
	for flex in [false, true] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#box{display:${if flex { 'flex' } else { 'grid' }};width:240px;grid-template-columns:1fr 1fr;gap:7px}#box>div{width:80px}</style><div id="box"><div>alpha beta gamma delta</div><div>second text with several words</div></div>')
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer { owner.finish(); document.finalize(); document.release_native_storage() }
		initial := run_document_layout(document, 800, 600) or { panic('layout failed') }
		root := previous_measurement_test_node(document, 'box')
		mut producer := LayoutState.new()
		producer.enable_measurement_chunk_pool()
		producer.measurement_chunk_pool_.scratch_enabled_ = true
		assert !previous_measurement_test_probe(mut producer, root, 240, flex)
		producer.retain_measurements_for_next_layout(initial.root)
		producer.release_measurement_chunk_pool()
		gc_collect()
		if !disable_previous_measurement_reuse { assert producer.measurement_layouts_ != unsafe { nil } }
		for _ in 0 .. 3 {
			mut consumer := LayoutState.new()
			consumer.enable_measurement_chunk_pool()
			consumer.measurement_chunk_pool_.scratch_enabled_ = true
			consumer.seed_previous_measurements(producer, initial.root)
			assert previous_measurement_test_probe(mut consumer, root, 240, flex) == !disable_previous_measurement_reuse
			consumer.retain_measurements_for_next_layout(initial.root)
			consumer.release_measurement_chunk_pool()
			producer = consumer
			gc_collect()
		}
	}
}

fn test_previous_measurements_keep_geometry_keys_and_drop_unvisited_entries() {
	mut document := html.parse_document('<!doctype html><style>#grid{display:grid;grid-template-columns:1fr 1fr}#flex{display:flex}div>p{width:80px}</style><div id="grid"><p>grid text wraps here</p><p>second grid text</p></div><div id="flex"><p>flex text wraps here</p><p>second flex text</p></div>')
	defer { document.finalize() }
	initial := run_document_layout(document, 800, 600) or { panic('layout failed') }
	grid := previous_measurement_test_node(document, 'grid')
	flex := previous_measurement_test_node(document, 'flex')
	mut producer := LayoutState.new()
	producer.enable_measurement_chunk_pool()
	assert !previous_measurement_test_probe(mut producer, grid, 240, false)
	assert !previous_measurement_test_probe(mut producer, flex, 240, true)
	producer.retain_measurements_for_next_layout(initial.root)
	producer.release_measurement_chunk_pool()
	mut consumer := LayoutState.new()
	consumer.enable_measurement_chunk_pool()
	consumer.seed_previous_measurements(producer, initial.root)
	// A seed alone earns no hit; the changed width still runs full layout.
	assert !previous_measurement_test_probe(mut consumer, grid, 193, false)
	assert previous_measurement_test_probe(mut consumer, grid, 240, false) == !disable_previous_measurement_reuse
	consumer.retain_measurements_for_next_layout(initial.root)
	consumer.release_measurement_chunk_pool()
	if !disable_previous_measurement_reuse {
		assert consumer.measurement_layouts_.grids.len > 0
		assert consumer.measurement_layouts_.flexes.len == 0
	}
}

fn test_previous_measurements_reject_style_font_environment_and_rebuilt_roots() {
	for change in ['style', 'font', 'environment', 'root', 'policy'] {
		mut document := html.parse_document('<!doctype html><style>#box{display:grid;grid-template-columns:1fr 1fr}</style><div id="box"><div>first long text</div><div>second long text</div></div>')
		defer { document.finalize() }
		initial := run_document_layout(document, 800, 600) or { panic('layout failed') }
		root := previous_measurement_test_node(document, 'box')
		mut producer := LayoutState.new()
		producer.enable_measurement_chunk_pool()
		assert !previous_measurement_test_probe(mut producer, root, 240, false)
		producer.retain_measurements_for_next_layout(initial.root)
		producer.release_measurement_chunk_pool()
		if change == 'style' {
			mut element := document.create_element('div') or { panic(err) }
			element.set_attribute_value('style', 'display:grid;grid-template-columns:1fr 1fr;font-size:23px')
			mut mutable_root := unsafe { &NodeWithStyle(root) }
			mutable_root.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
		} else if change == 'font' {
			mut fonts := css.css_style_computer_for(document).font_computer()
			fonts.did_load_font('PreviousMeasurementUnrelatedFace')
		} else if change == 'environment' {
			document.bump_style_environment_version()
		} else if change == 'policy' {
			document.set_font_rendering_policy(.chromium)
		}
		mut consumer := LayoutState.new()
		consumer.enable_measurement_chunk_pool()
		defer { consumer.release_measurement_chunk_pool() }
		consumer.seed_previous_measurements(producer, if change == 'root' { root } else { initial.root })
		assert !previous_measurement_test_probe(mut consumer, root, 240, false)
	}
}

fn test_previous_measurements_reject_changed_root_location_and_item_role() {
	for change in ['sibling', 'item'] {
		mut document := html.parse_document('<!doctype html><div id="box" style="display:grid;grid-template-columns:1fr 1fr"><p>first text</p><p>second text</p></div><div>other sibling</div>')
		defer { document.finalize() }
		initial := run_document_layout(document, 800, 600) or { panic('layout failed') }
		root := previous_measurement_test_node(document, 'box')
		mut producer := LayoutState.new()
		producer.enable_measurement_chunk_pool()
		assert !previous_measurement_test_probe(mut producer, root, 240, false)
		producer.retain_measurements_for_next_layout(initial.root)
		producer.release_measurement_chunk_pool()
		if change == 'sibling' {
			mut parent := root.parent() or { panic('missing parent') }
			parent.replace_children(parent.children().reverse())
			assign_layout_indexes(initial.root)
		} else {
			mut mutable_root := unsafe { &Node(root) }
			mutable_root.is_flex_item_ = true
		}
		mut consumer := LayoutState.new()
		consumer.enable_measurement_chunk_pool()
		consumer.seed_previous_measurements(producer, initial.root)
		assert !previous_measurement_test_probe(mut consumer, root, 240, false)
		consumer.release_measurement_chunk_pool()
	}
}

fn test_previous_measurements_keep_svg_path_ownership_and_attribute_guards() {
	for kind in ['grid', 'flex'] {
		mut document := html.parse_document('<!doctype html><div id="box" style="display:${kind};grid-template-columns:1fr 1fr"><svg width="40" height="30" viewBox="0 0 40 30"><path id="shape" d="M2 2L25 2L25 20Z" fill="green"/></svg><p>Several wrapping text words.</p></div>')
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer { owner.finish(); document.finalize(); document.release_native_storage() }
		initial := run_document_layout(document, 800, 600) or { panic('layout failed') }
		root := previous_measurement_test_node(document, 'box')
		mut producer := LayoutState.new()
		producer.enable_measurement_chunk_pool()
		producer.measurement_chunk_pool_.scratch_enabled_ = true
		assert !previous_measurement_test_probe(mut producer, root, 240, kind == 'flex')
		producer.retain_measurements_for_next_layout(initial.root)
		producer.release_measurement_chunk_pool()
		mut consumer := LayoutState.new()
		consumer.enable_measurement_chunk_pool()
		consumer.measurement_chunk_pool_.scratch_enabled_ = true
		consumer.seed_previous_measurements(producer, initial.root)
		assert previous_measurement_test_probe(mut consumer, root, 240, kind == 'flex') == !disable_previous_measurement_reuse
		consumer.release_measurement_chunk_pool()
		mut shape := document.get_element_by_id('shape') or { panic('missing SVG path') }
		shape.set_attribute_value('d', 'M3 4L35 4L35 25Z')
		mut changed := LayoutState.new()
		changed.enable_measurement_chunk_pool()
		changed.seed_previous_measurements(producer, initial.root)
		assert !previous_measurement_test_probe(mut changed, root, 240, kind == 'flex')
		changed.release_measurement_chunk_pool()
	}
}

fn test_previous_measurement_membership_checks_precede_saved_node_dereferences() {
	mut document := html.parse_document('<!doctype html><div id="box">text</div>')
	defer { document.finalize() }
	_ = run_document_layout(document, 800, 600) or { panic('layout failed') }
	root := previous_measurement_test_node(document, 'box')
	inputs := [
		RetainedInlineInput{node: root, style: root.computed_values()},
		RetainedInlineInput{node: unsafe { &Node(voidptr(u64(0x12340))) }, style: unsafe { nil }},
	]
	assert !previous_measurement_inputs_are_current(inputs, {u64(voidptr(root)): true})
}

fn test_previous_measurement_bookkeeping_grows_outside_released_probe_scratch() {
	mut contents := ''
	for index in 0 .. 96 {
		contents += '<section id="box${index}" style="display:grid;grid-template-columns:1fr 1fr"><div>first wrapping words</div><div>second wrapping words</div></section>'
	}
	mut document := html.parse_document('<!doctype html>${contents}')
	document.enable_native_storage()
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	initial := run_document_layout(document, 800, 600) or { panic('layout failed') }
	mut producer := LayoutState.new()
	producer.enable_measurement_chunk_pool()
	producer.measurement_chunk_pool_.scratch_enabled_ = true
	for index in 0 .. 96 {
		assert !previous_measurement_test_probe(mut producer, previous_measurement_test_node(document, 'box${index}'), 240, false)
	}
	producer.retain_measurements_for_next_layout(initial.root)
	producer.release_measurement_chunk_pool()
	mut consumer := LayoutState.new()
	consumer.enable_measurement_chunk_pool()
	consumer.measurement_chunk_pool_.scratch_enabled_ = true
	if !disable_previous_measurement_reuse { assert producer.measurement_layouts_.grids.len == 96 }
	consumer.seed_previous_measurements(producer, initial.root)
	for index in 0 .. 96 {
		assert previous_measurement_test_probe(mut consumer, previous_measurement_test_node(document, 'box${index}'), 240, false) == !disable_previous_measurement_reuse, 'root ${index}'
	}
	if !disable_previous_measurement_reuse {
		assert consumer.measurement_chunk_pool_.previous_grid_attempts_.len == 96
	}
	consumer.release_measurement_chunk_pool()
}

fn test_previous_measurements_reject_changed_text_and_actual_child_slots() {
	for replace_slot in [false, true] {
		mut document := html.parse_document('<!doctype html><div id="box">original text</div>')
		defer { document.finalize() }
		_ = run_document_layout(document, 800, 600) or { panic('layout failed') }
		root := previous_measurement_test_node(document, 'box')
		mut inputs := []RetainedInlineInput{}
		mut rejected := map[u64]bool{}
		assert collect_grid_measurement_inputs(root, mut inputs, mut rejected)
		mut nodes := map[u64]bool{}
		collect_current_measurement_nodes(root, mut nodes)
		assert previous_measurement_inputs_are_current(inputs, nodes)
		old_child := root.children()[0]
		if replace_slot {
			mut mutable_root := unsafe { &Node(root) }
			replacement := unsafe { &Node(TextNode.new(document, document.create_text_node('replacement').as_node(), 'replacement')) }
			mutable_root.replace_children([replacement])
			// Model a stale reverse link in an old projection. Merely trusting
			// its parent/index and a live-address set would accept the old child.
			mut stale := unsafe { &Node(old_child) }
			stale.parent_ = root
			stale.index_in_parent_ = 0
			assert inline_measurement_inputs_are_current(inputs)
			assert !previous_measurement_inputs_are_current(inputs, nodes)
			stale.parent_ = none
			stale.index_in_parent_ = -1
		} else {
			mut text := old_child.as_text_node() or { panic('missing text') }
			text_owner := text.dom_node() or { panic('missing text owner') }
			mut data := text_owner.as_character_data() or { panic('missing data') }
			data.set_data('changed text with additional words')
			text.invalidate_text_for_rendering()
			assert !previous_measurement_inputs_are_current(inputs, nodes)
		}
	}
}

fn previous_measurement_test_pixels(height int) html.DecodedImageData {
	return html.BitmapDecodedImageData.create([html.BitmapDecodedImageFrame{
		frame: dom.DecodedImageFrame_.create(&dom.Bitmap_{
			width: 8
			height: height
			pitch: 32
			data: []u8{len: 32 * height, init: 255}
		})
	}], 0, false)
}

fn test_previous_measurements_preserve_pending_absolute_and_live_image_guards() {
	for kind in ['grid', 'flex'] {
		for change in ['pending', 'absolute', 'natural', 'source'] {
			address := dom.URL{value: 'https://previous-images.example/'}
			mut document := html.parse_navigation_document('<!doctype html><div id="box" style="display:${kind};position:relative;grid-template-columns:1fr 1fr"><img id="photo" src="a.png" style="width:40px;height:auto;${if change == 'absolute' { 'position:absolute;left:0;top:0' } else { '' }}"><p>Several wrapping text words.</p></div>', address, address.origin(), none) or { panic(err) }
			element := document.get_element_by_id('photo') or { panic('missing image') }
			mut image := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
			if change == 'pending' {
				image.set_async_fetch_hook(fn (_ dom.URL, _ html.HTMLImageFetchCompletion) {})
			} else {
				image.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData { return previous_measurement_test_pixels(6) })
			}
			image.update_the_image_data(false, false)
			document.enable_native_storage()
			mut owner := document.enter_native_storage()
			defer { owner.finish(); document.finalize(); document.release_native_storage() }
			initial := run_document_layout(document, 800, 600) or { panic('layout failed') }
			root := previous_measurement_test_node(document, 'box')
			mut producer := LayoutState.new()
			producer.enable_measurement_chunk_pool()
			assert !previous_measurement_test_probe(mut producer, root, 240, kind == 'flex')
			producer.retain_measurements_for_next_layout(initial.root)
			producer.release_measurement_chunk_pool()
			if change == 'natural' {
				mut request := image.current_request()
				request.set_image_data(html.SharedResourceImageData{data: previous_measurement_test_pixels(12)})
				request.set_state(.completely_available)
				new_height := html.html_image_element_intrinsic_height(unsafe { &dom.HTMLImageElement(element) }) or { panic('missing changed natural height') }
				assert new_height == 12
			} else if change == 'source' {
				mut dom_image := unsafe { &dom.Element(element) }
				dom_image.set_attribute_value('src', 'other.png')
				image.update_the_image_data(false, false)
				assert html.html_image_element_current_src(unsafe { &dom.HTMLImageElement(element) }).ends_with('/other.png')
			}
			mut image_box := previous_measurement_test_node(document, 'photo').as_image_box() or { panic('missing image box') }
			image_box.reset_for_relayout()
			mut consumer := LayoutState.new()
			consumer.enable_measurement_chunk_pool()
			consumer.seed_previous_measurements(producer, initial.root)
			assert !previous_measurement_test_probe(mut consumer, root, 240, kind == 'flex'), '${kind} ${change}'
			consumer.release_measurement_chunk_pool()
		}
	}
}
