module layout

import css
import dom
import os

fn retained_text_owner_fixture() (&dom.Document, &BlockContainer, &TextNode, &css.FontFaceObject) {
	mut document := dom.Document.create(dom.url_about_blank())
	mut computer := css.css_style_computer_for(document).font_computer()
	mut set := css.FontFaceSet.create_for_font_computer(computer)
	mut face := css.FontFaceObject.construct_impl('CaptureOwner',
		css.FontFaceSource.from_string('url(late.woff)'), css.FontFaceDescriptors{ display: 'swap' })
	set.add(face) or { panic(err) }
	// Hold the face pending without starting asynchronous transport or attaching
	// this private layout tree to FontFaceSet.ready's document update hook.
	face.status_ = .loading
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', 'display:block;font:16px/20px CaptureOwner,Arial')
	style := css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none))
	mut container := BlockContainer.new(document, none, style)
	container.set_children_are_inline(true)
	text := TextNode.new(document, document.create_text_node('A heading in a pending face').as_node(),
		'A heading in a pending face')
	container.append_child(unsafe { &Node(text) })
	assign_layout_indexes(unsafe { &Node(container) })
	retained_text_owner_shape(container)
	assert (text.cached_inline_font_owner_ or { panic('missing owner') }).pending_faces.len == 1
	return document, container, text, face
}

fn retained_text_owner_shape(container &BlockContainer) {
	mut state := LayoutState.new()
	mut used := state.get_mutable(unsafe { &NodeWithStyle(container) })
	used.set_content_width(CSSPixels.new(240))
	space := AvailableSpace.new(AvailableSize.make_definite(CSSPixels.new(240)), AvailableSize.make_indefinite())
	_ = run_uncached_inline_formatting_context_for_width(mut state, container, mut used,
		.intrinsic_sizing, space, none, false)
}

fn retained_text_owner_load(mut face css.FontFaceObject) string {
	path := os.join_path(@VMODROOT, 'Tests', 'Browser', 'Brave', 'resources', 'Ahem.ttf')
	face.finish_loading_from_typeface(&css.PlatformTypeface{
		family_name: 'CaptureOwner'
		source_path: path
		weight_:     400
	})
	assert face.status() == .loaded
	return path
}

fn test_retained_layout_does_not_certify_fallback_chunks_with_a_new_computed_font() {
	document, container, text, mut face := retained_text_owner_fixture()
	defer { document.finalize() }
	root := unsafe { &Node(container) }
	mut inputs := []RetainedInlineInput{}
	assert collect_retained_inline_inputs(root, true, mut inputs)
	assert retained_inline_inputs_are_current(inputs)
	assert inline_measurement_inputs_are_current(inputs)
	previous := text.cached_inline_font_owner_ or { panic('missing original owner') }
	chunks := text.cached_inline_chunks_ or { panic('missing fallback chunks') }
	path := retained_text_owner_load(mut face)
	assert chunks[0].font.source_path != path
	// Style/metric inspection may resolve the new cascade before layout enters
	// this TextNode. That newer metadata cannot certify the older geometry.
	mut style := root.computed_values()
	computer := css.css_style_computer_for(document).font_computer()
	current := style.computed_font_list(computer)
	assert current.pending_faces.len == 0
	assert voidptr(previous) != voidptr(current)
	assert !retained_inline_inputs_are_current(inputs)
	assert !inline_measurement_inputs_are_current(inputs)
	mut inline_inputs := []RetainedInlineInput{}
	assert collect_retained_inline_inputs(root, true, mut inline_inputs)
	assert !retained_inline_text_fonts_are_current(inline_inputs)
	mut block_inputs := []RetainedInlineInput{}
	mut rejected := map[u64]bool{}
	assert collect_retained_block_inputs(root, mut block_inputs, mut rejected)
	assert !retained_inline_text_fonts_are_current(block_inputs)
	// Certification is read-only; the ordinary text path owns reshaping.
	assert (text.cached_inline_chunks_ or { panic('chunks were cleared') }).data == chunks.data
	retained_text_owner_shape(container)
	assert (text.cached_inline_chunks_ or { panic('missing loaded chunks') })[0].font.source_path == path
	mut refreshed := []RetainedInlineInput{}
	assert collect_retained_inline_inputs(root, true, mut refreshed)
	assert retained_inline_text_fonts_are_current(refreshed)
	assert retained_inline_inputs_are_current(refreshed)
	assert inline_measurement_inputs_are_current(refreshed)
	rejected.clear()
	block_inputs.clear()
	assert collect_retained_block_inputs(root, mut block_inputs, mut rejected)
}

fn test_retained_text_owner_allows_live_pending_and_settled_cascades_after_unrelated_loads() {
	document, container, text, mut face := retained_text_owner_fixture()
	defer { document.finalize() }
	mut computer := css.css_style_computer_for(document).font_computer()
	for loaded in [false, true] {
		if loaded {
			_ = retained_text_owner_load(mut face)
			// Before computed inputs are refreshed, their expired original cascade
			// must also be rejected rather than comparing it equal to itself.
			assert !retained_text_font_owner_is_current(text)
			retained_text_owner_shape(container)
		}
		chunks := text.cached_inline_chunks_ or { panic('missing chunks') }
		computer.did_load_font('UnrelatedCaptureOwner')
		if !loaded && (disable_live_pending_text_reuse
			|| os.getenv('VOX_DISABLE_PENDING_INTRINSIC_FONT_REUSE') != '') {
			continue
		}
		assert retained_text_font_owner_is_current(text)
		mut inputs := []RetainedInlineInput{}
		assert collect_retained_inline_inputs(unsafe { &Node(container) }, true, mut inputs)
		assert retained_inline_inputs_are_current(inputs)
		assert inline_measurement_inputs_are_current(inputs)
		assert (text.cached_inline_chunks_ or { panic('chunks were cleared') }).data == chunks.data
	}
}
