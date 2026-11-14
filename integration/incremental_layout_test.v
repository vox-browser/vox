module integration

import dom
import html
import layout

fn incremental_layout_document(markup string) &dom.Document {
	address := dom.URL{
		value: 'https://incremental-layout.example.test/'
	}
	document := html.parse_navigation_document('<!doctype html><style>html,body{margin:0;font:16px/20px sans-serif}</style>' +
		markup, address, address.origin(), none) or { panic(err) }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	// First use can discover fonts and advance the font environment. Commit
	// that environment before testing reuse against unchanged layout inputs.
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	assert document.layout_is_up_to_date()
	return document
}

fn incremental_layout_set_style(document &dom.Document, id string, style string) {
	mut element := document.get_element_by_id(id) or { panic('missing ${id}') }
	element.set_attribute_value('style', style)
}

// Lays out the pending change, reports whether it ran incrementally, and
// checks the result against a complete layout-tree rebuild.
fn incremental_layout_apply(document &dom.Document) bool {
	mut mutable := unsafe { &dom.Document(document) }
	before := layout.incremental_layout_pass_count()
	mismatches := layout.incremental_layout_verification_mismatch_count()
	mutable.update_layout(.debugging)
	incremental := layout.incremental_layout_pass_count() > before
	list := mutable.record_display_list() or { panic('missing list') }
	retained := list.dump()
	mutable.set_needs_full_layout_tree_update(true)
	mutable.update_layout(.debugging)
	rebuilt := mutable.record_display_list() or { panic('missing rebuilt list') }
	assert rebuilt.dump() == retained
	assert layout.incremental_layout_verification_mismatch_count() == mismatches
	return incremental
}

fn test_change_inside_a_fixed_height_box_relays_out_only_that_box() {
	mut document := incremental_layout_document('<div id="box" style="height:60px;overflow:hidden"><span id="text" style="padding-left:2px">hello world with some wrapping text inside a fixed box</span></div><p>after</p>')
	defer { document.finalize() }
	incremental_layout_set_style(document, 'text', 'padding-left:120px')
	assert incremental_layout_apply(document)
	// Repeated changes keep using the committed records.
	incremental_layout_set_style(document, 'text', 'padding-left:7px')
	assert incremental_layout_apply(document)
}

fn test_change_keeping_an_automatic_height_relays_out_incrementally() {
	mut document := incremental_layout_document('<p>before</p><div id="box" style="overflow:hidden;width:300px"><span id="text" style="padding-left:2px">short</span></div><p>after</p>')
	defer { document.finalize() }
	incremental_layout_set_style(document, 'text', 'padding-left:40px')
	assert incremental_layout_apply(document)
}

fn test_changed_automatic_height_escalates_to_a_complete_pass() {
	mut document := incremental_layout_document('<div id="outer" style="display:flow-root"><div id="box" style="overflow:hidden;width:200px"><span id="text">one two three</span></div></div><p>after</p>')
	defer { document.finalize() }
	// The text wraps to more lines, so every ancestor's height changes.
	incremental_layout_set_style(document, 'text', 'padding-left:180px')
	assert !incremental_layout_apply(document)
}

fn test_measured_flex_item_relays_out_from_its_container() {
	mut document := incremental_layout_document('<div style="display:flex;height:40px"><div id="item" style="overflow:hidden"><span id="text">abc</span></div><div>sibling</div></div><p>after</p>')
	defer { document.finalize() }
	// The item's width follows its content, which the container measured.
	incremental_layout_set_style(document, 'text', 'padding-left:90px')
	assert incremental_layout_apply(document)
}

fn test_change_inside_a_shrink_to_fit_float_matches_a_complete_pass() {
	mut document := incremental_layout_document('<div style="float:left"><div id="box" style="overflow:hidden"><span id="text">abc</span></div></div><p>text beside the float</p>')
	defer { document.finalize() }
	incremental_layout_set_style(document, 'text', 'padding-left:60px')
	_ = incremental_layout_apply(document)
}

fn test_new_natural_size_relays_out_the_image_box_container() {
	mut document := incremental_layout_document('<div id="box" style="height:80px;overflow:hidden"><img id="image" src="https://incremental-layout.example.test/a.png"></div><p>after</p>')
	defer { document.finalize() }
	incremental_layout_finish_image(document)
	assert incremental_layout_apply(document)
}

fn incremental_layout_finish_image(document &dom.Document) {
	element := document.get_element_by_id('image') or { panic('missing image') }
	mut model := html.html_image_element_model_for_dom_element(unsafe { &dom.HTMLImageElement(element) })
	model.set_fetch_hook(fn (_ dom.URL) !html.DecodedImageData {
		bitmap := &dom.Bitmap_{
			width:                             24
			height:                            18
			pitch:                             24 * 4
			data:                              []u8{len: 24 * 18 * 4, init: 255}
			native_resource_replay_compatible: true
		}
		return html.BitmapDecodedImageData.create([
			html.BitmapDecodedImageFrame{
				frame: dom.DecodedImageFrame_.create(bitmap)
			},
		], 0, false)
	})
	model.update_the_image_data(false, false)
	assert model.complete()
}

fn test_clean_sibling_is_reused_when_the_page_relays_out() {
	mut document := incremental_layout_document('<div id="changing"><span id="text">one two three</span></div>' +
		'<div id="clean" style="position:relative;overflow:hidden;width:250px"><p style="position:relative;top:5px;left:3px">moved by its insets</p>' +
		'<div style="position:absolute;right:4px;bottom:2px;width:20px;height:10px;background:red"></div>' +
		'<div style="display:flex"><span>flex</span><span>items</span></div></div><p>after</p>')
	defer { document.finalize() }
	before := layout.incremental_layout_reused_subtree_count()
	// More lines in the first block move every later block down.
	incremental_layout_set_style(document, 'text', 'padding-left:350px')
	assert !incremental_layout_apply(document)
	assert layout.incremental_layout_reused_subtree_count() > before
	// Moving it back reuses it again.
	again := layout.incremental_layout_reused_subtree_count()
	incremental_layout_set_style(document, 'text', 'padding-left:0')
	_ = incremental_layout_apply(document)
	assert layout.incremental_layout_reused_subtree_count() > again
}

fn test_changed_box_inside_a_clean_ancestor_is_laid_out_again() {
	mut document := incremental_layout_document('<div style="overflow:hidden;width:300px"><div id="inner" style="overflow:hidden"><span id="text">inner text</span></div><p>sibling paragraph</p></div><p id="tail">tail</p>')
	defer { document.finalize() }
	incremental_layout_set_style(document, 'text', 'padding-left:290px')
	_ = incremental_layout_apply(document)
	incremental_layout_set_style(document, 'tail', 'padding-top:30px')
	_ = incremental_layout_apply(document)
}

fn test_bounded_relayout_preserves_untouched_inline_block_line_geometry() {
	for inner in [
		'<span style="display:inline-block;overflow:hidden;font-size:13px">inner<br>two</span>',
		'<span style="display:inline-block;vertical-align:middle;padding:3px"><img width="10" height="7"> x</span>',
		'<span style="display:inline-flex;align-items:center;height:26px">flex <b>bold</b></span>',
		'<button style="font-size:11px;padding:1px 5px">Code</button>',
	] {
		mut document := incremental_layout_document('<div id="changing" style="height:80px;overflow:hidden"><span id="text">one two three</span></div><div style="overflow:hidden"><p style="line-height:normal">before ' +
			inner + ' after</p><div style="display:flex;gap:4px"><span>a</span>' + inner + '</div></div><p>tail</p>')
		defer { document.finalize() }
		incremental_layout_set_style(document, 'text', 'padding-left:350px')
		assert incremental_layout_apply(document), inner
	}
}

fn test_disjoint_changes_relayout_both_fixed_height_containers() {
	mut document := incremental_layout_document('<div style="overflow:hidden;height:60px"><span id="first">first</span></div>' +
		'<div style="overflow:hidden;height:80px"><span id="second">second</span></div><p>tail</p>')
	defer { document.finalize() }
	incremental_layout_set_style(document, 'first', 'padding-left:40px')
	incremental_layout_set_style(document, 'second', 'padding-left:100px')
	assert incremental_layout_apply(document)
}

fn test_changed_height_escalates_to_a_fixed_height_ancestor() {
	mut document := incremental_layout_document('<div style="overflow:hidden;height:100px"><div style="overflow:hidden;width:200px">' +
		'<span id="text">one two three</span></div><p>inside</p></div><p>outside</p>')
	defer { document.finalize() }
	incremental_layout_set_style(document, 'text', 'padding-left:180px')
	assert incremental_layout_apply(document)
}

fn test_external_containing_block_positions_are_recomputed() {
	mut document := incremental_layout_document('<div style="position:relative;height:200px"><div id="changing"><span id="text">one two three</span></div>' +
		'<div style="overflow:hidden"><p>clean text</p><span style="position:absolute;bottom:10px;right:5px">positioned outside</span></div></div>')
	defer { document.finalize() }
	incremental_layout_set_style(document, 'text', 'padding-left:350px')
	_ = incremental_layout_apply(document)
}

fn test_svg_changes_invalidate_reusable_ancestors_at_device_scale() {
	mut document := incremental_layout_document('<div style="overflow:hidden;height:100px"><svg width="50" height="30" viewBox="0 0 50 30">' +
		'<rect id="shape" width="20" height="10" fill="red"/></svg></div><p>after</p>')
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	incremental_layout_set_style(document, 'shape', 'width:40px;height:25px;fill:green')
	_ = incremental_layout_apply(document)
}

fn test_rebuilt_tree_reuses_clean_subtrees_after_indices_change() {
	mut document := incremental_layout_document('<div id="changing">before</div><div style="overflow:hidden;width:200px">' +
		'<p>retained text</p><div style="display:flex"><span>one</span><span>two</span></div></div><p>tail</p>')
	defer { document.finalize() }
	before := layout.incremental_layout_reused_subtree_count()
	mut changing := document.get_element_by_id('changing') or { panic('missing changing') }
	changing.as_node().set_text_content('replacement text with a different layout tree') or { panic(err) }
	_ = incremental_layout_apply(document)
	assert layout.incremental_layout_reused_subtree_count() > before
}

fn test_viewport_changes_do_not_restore_old_subtree_widths() {
	mut document := incremental_layout_document('<div id="box" style="overflow:hidden;width:50%"><p>text wraps with the viewport</p></div>')
	defer { document.finalize() }
	before := layout.incremental_layout_reused_subtree_count()
	_ = layout.layout_document_typed_in_viewport(document, 600, 300)
	assert layout.incremental_layout_reused_subtree_count() == before
	mut box := document.get_element_by_id('box') or { panic('missing box') }
	assert box.get_bounding_client_rect().width == 300
	_ = incremental_layout_apply(document)
}

fn test_many_independent_changes_fall_back_to_full_layout() {
	mut markup := '<div style="overflow:hidden;height:80px">'
	for index in 0 .. 66 {
		markup += '<span id="item${index}">text </span>'
	}
	mut document := incremental_layout_document(markup + '</div><p>tail</p>')
	defer { document.finalize() }
	for index in 0 .. 66 {
		incremental_layout_set_style(document, 'item${index}', 'padding-left:2px')
	}
	assert !incremental_layout_apply(document)
}

fn test_nested_boundary_does_not_hide_an_ancestors_intrinsic_size_change() {
	mut document := incremental_layout_document('<div style="display:flex"><div><div style="overflow:hidden;height:50px">' +
		'<div style="overflow:hidden;height:30px"><span id="text">short</span></div></div></div><div>sibling</div></div><p>tail</p>')
	defer { document.finalize() }
	incremental_layout_set_style(document, 'text', 'padding-left:180px')
	_ = incremental_layout_apply(document)
}

fn test_new_image_size_and_reindexed_clean_tree_match_a_rebuild() {
	mut document := incremental_layout_document('<div id="remove"><p>before</p><p>more nodes</p></div>' +
		'<div style="overflow:hidden;height:80px"><img id="image" src="https://incremental-layout.example.test/a.png"></div><p>tail</p>')
	defer { document.finalize() }
	incremental_layout_set_style(document, 'remove', 'display:none')
	incremental_layout_finish_image(document)
	_ = incremental_layout_apply(document)
	image := document.get_element_by_id('image') or { panic('missing image') }
	assert image.get_bounding_client_rect().width == 24
	assert image.get_bounding_client_rect().height == 18
}

fn test_incremental_records_survive_native_geometry_scratch_retirement() {
	address := dom.URL{ value: 'https://incremental-layout.example.test/' }
	mut document := html.create_navigation_document(address, address.origin(), none) or { panic(err) }
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><style>html,body{margin:0;font:16px/20px sans-serif}</style>' +
		'<div style="height:100px;overflow:hidden"><span id="text">one two three</span></div>' +
		'<div style="overflow:hidden;position:relative"><p style="position:relative;top:3px">clean text</p>' +
		'<div style="display:grid;grid-template-columns:1fr 1fr"><span>one</span><span>two</span></div></div>')
	allocations.finish()
	layout.enable_native_paint_tree_storage(document)
	defer {
		handle := document.layout_engine_handle()
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		layout.retire_native_document_layout(handle)
		document.release_native_storage()
	}
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	for padding in [100, 3, 350, 7] {
		incremental_layout_set_style(document, 'text', 'padding-left:${padding}px')
		assert incremental_layout_apply(document)
	}
}
