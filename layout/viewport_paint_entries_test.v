module layout

import dom
import html
import painting
import platform

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn viewport_test_commands(mut document dom.Document) []PaintCommand {
	return display_list_commands(document.record_viewport_display_list() or { panic('missing viewport list') })
}

fn test_viewport_recording_defers_offscreen_entries_and_populates_them_after_scroll() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}div{height:100px}#first{background:red}#last{background:blue}</style><div id="first">first</div><div>middle</div><div id="last">last</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	initial_list := document.record_viewport_display_list()?
	initial_scene := retain_display_list_scene(initial_list)
	defer { release_display_list_scene(initial_scene) }
	initial := display_list_commands(initial_list)
	assert initial.any(it.color == 'rgb(255 0 0)')
	assert !initial.any(it.color == 'rgb(0 0 255)')
	mut result := document_layout_result(document)?
	assert result.paint_phase_entry_valid.any(!it)
	storage := result.paint_tree.children.data
	snapshot := initial.map('${it.kind}:${it.color}:${it.text}:${it.transform}')
	document.set_viewport_rect(dom.Rect{0, 200, 320, 100})
	scrolled_list := document.record_viewport_display_list()?
	scrolled_scene := retain_display_list_scene(scrolled_list)
	defer { release_display_list_scene(scrolled_scene) }
	scrolled := display_list_commands(scrolled_list)
	assert scrolled.any(it.color == 'rgb(0 0 255)')
	assert !scrolled.any(it.color == 'rgb(255 0 0)')
	assert result.paint_tree.children.data == storage
	assert initial.map('${it.kind}:${it.color}:${it.text}:${it.transform}') == snapshot
	full_list := document.record_display_list()?
	full := display_list_commands(full_list)
	assert full.any(it.color == 'rgb(255 0 0)') && full.any(it.color == 'rgb(0 0 255)')
	assert result.paint_phase_entry_valid.all(it)
	again := viewport_test_commands(mut document)
	assert again.map('${it.kind}:${it.color}:${it.text}:${it.transform}') == scrolled.map('${it.kind}:${it.color}:${it.text}:${it.transform}')
}

fn test_viewport_recording_keeps_overflowing_transformed_and_fixed_descendants() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#parent{position:absolute;top:1000px;width:20px;height:20px;background:red}#child{position:absolute;top:-1000px;width:20px;height:20px;background:green}#transformed{position:absolute;top:1200px;transform:translateY(-1200px);width:20px;height:20px;background:blue}#fixed{position:fixed;top:30px;width:20px;height:20px;background:purple}</style><div id="parent"><div id="child"></div></div><div id="transformed"></div><div id="fixed"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	commands := viewport_test_commands(mut document)
	assert !commands.any(it.color == 'rgb(255 0 0)')
	for color in ['rgb(0 128 0)', 'rgb(0 0 255)', 'rgb(128 0 128)'] {
		assert commands.any(it.color == color)
	}
}

fn test_viewport_recording_preserves_complete_effect_inputs_and_svg_resources() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#effect{position:absolute;top:1000px;filter:drop-shadow(0 -1000px 0 red)}#child{width:20px;height:20px;background:green}</style><div id="effect"><div id="child"></div></div><svg style="position:absolute;top:1200px" width="20" height="20"><rect width="20" height="20" fill="blue"/></svg>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	full := (document.record_display_list()?).dump()
	assert (document.record_viewport_display_list()?).dump() == full
}

fn test_viewport_ink_guards_keep_native_precision_and_unbounded_text_inputs() {
	mut ink_probe := PaintCommand{blur: 10, outer_shadow: true}
	assert !viewport_rect_is_outside(LayoutRect{1_000_001, 10, 20, 20}, [f64(1), 0, 0, 1, -1_000_001, 0]!, 320, 100, mut ink_probe)
	assert viewport_rect_is_outside(LayoutRect{10, 1000, 20, 20}, [f64(1), 0, 0, 1, 0, 0]!, 320, 100, mut ink_probe)
	fragment := TextFragment{x: 10, y: 1000, width: 20, height: 20, text: 'text'}
	assert !viewport_fragment_ink_is_outside(&fragment, [f64(1), 0, 0, 1, 0, 0]!, 320, 100, mut ink_probe)
}

fn test_viewport_ink_probes_reuse_storage_for_rectangles_and_glyph_bounds() {
	run := &platform.GlyphRun{
		font_: &platform.Font{font_rendering_policy: .chromium}
		bounding_box_: platform.GlyphRunBounds{-4, -12, 40, 18}
	}
	fragment := TextFragment{
		x: 10, y: 1000, width: 20, height: 20, text: 'text', baseline_set: true
		baseline: 13, decoration: 'none'
		paintable_fragment: painting.PaintableFragment{glyph_run: run}
	}
	mut ink_probe := PaintCommand{}
	identity := [f64(1), 0, 0, 1, 0, 0]!
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut outside := 0
	for _ in 0 .. 4096 {
		if viewport_rect_is_outside(LayoutRect{10, 1000, 20, 20}, identity, 320, 100, mut ink_probe) { outside++ }
		if viewport_fragment_ink_is_outside(&fragment, identity, 320, 100, mut ink_probe) { outside++ }
	}
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert outside == 8192
	assert allocated < 8192, 'viewport ink probes allocated ${allocated} bytes'
	// A previous glyph command must not affect a later rectangle, or a changed
	// transform reuse an earlier result.
	assert viewport_rect_is_outside(LayoutRect{10, 1000, 20, 20}, identity, 320, 100, mut ink_probe)
	assert !viewport_fragment_ink_is_outside(&fragment, [f64(1), 0, 0, 1, 0, -1000]!, 320, 100, mut ink_probe)
}

fn test_viewport_recording_culls_image_rows_beyond_one_viewport_of_prepaint() {
	// Comment threads repeat a background arrow and a spacer image on every row.
	// Entries whose pixels stay inside their border box are culled once they
	// are more than one viewport height away; their backgrounds are still listed
	// for the shell's prefetch.
	gif := 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'
	mut rows := ''
	for index in 0 .. 60 {
		rows += '<div class="row" style="background-image:url(http://example.test/r${index}.png),linear-gradient(red,blue)"><img src="${gif}" width="10" height="10"></div>'
	}
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}.row{height:50px;background-size:10px}img{display:block}</style>${rows}')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	near_list := document.record_viewport_display_list()?
	near_scene := retain_display_list_scene(near_list)
	defer { release_display_list_scene(near_scene) }
	near := display_list_commands(near_list)
	near_urls := near.filter(it.kind == 'draw_background_image' && it.image_data != unsafe { nil }).map(it.image_data.image_url)
	assert 'http://example.test/r0.png' in near_urls
	assert 'http://example.test/r4.png' in near_urls
	assert 'http://example.test/r5.png' !in near_urls
	assert 'http://example.test/r59.png' !in near_urls
	urls := document_background_image_urls(document)
	assert urls.len == 60
	for index in 0 .. 60 {
		assert 'http://example.test/r${index}.png' in urls
	}
	document.set_viewport_rect(dom.Rect{0, 1500, 320, 100})
	scrolled_list := document.record_viewport_display_list()?
	scrolled_scene := retain_display_list_scene(scrolled_list)
	defer { release_display_list_scene(scrolled_scene) }
	scrolled := display_list_commands(scrolled_list)
	scrolled_urls := scrolled.filter(it.kind == 'draw_background_image' && it.image_data != unsafe { nil }).map(it.image_data.image_url)
	for index in 28 .. 33 {
		assert 'http://example.test/r${index}.png' in scrolled_urls
	}
	assert 'http://example.test/r0.png' !in scrolled_urls
	assert 'http://example.test/r40.png' !in scrolled_urls
	full_list := document.record_display_list()?
	full_scene := retain_display_list_scene(full_list)
	defer { release_display_list_scene(full_scene) }
	full := display_list_commands(full_list)
	images := ['draw_replaced_image', 'draw_background_image', 'fill_gradient']
	assert full.filter(it.kind in images).len > scrolled.filter(it.kind in images).len * 5
	full_replaced := full.filter(it.kind == 'draw_replaced_image').len
	if full_replaced > 0 {
		visible := scrolled.filter(it.kind == 'draw_replaced_image').len
		assert visible > 0 && visible < full_replaced
	}
}

fn test_viewport_entry_blocks_select_exactly_the_per_entry_entries() {
	gif := 'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'
	mut rows := ''
	for index in 0 .. 80 {
		rows += '<tr><td><img src="${gif}" width="${(index % 7) * 10}" height="1"></td><td><div class="arrow" style="background-image:url(http://example.test/a.svg),linear-gradient(red,blue)"></div><span class="c"><a href="#">user${index}</a> | <u>reply</u></span><div>comment ${index} with words</div></td></tr>'
	}
	source := '<!doctype html><style>html,body{margin:0}.arrow{width:10px;height:10px}#scroller{height:60px;overflow:scroll}#scroller p{margin:0;height:20px}#turned{transform:rotate(8deg);width:120px}#fixed{position:fixed;top:5px;left:200px;width:20px;height:20px;background:blue}</style><div id="scroller">' + '<p>row</p>'.repeat(6) + '</div><div id="turned">turned text</div><div id="fixed"></div><table>${rows}</table><p style="filter:blur(1px)">filtered</p>'
	mut document := html.parse_document(source)
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 120)
	mut culled_by_blocks := 0
	for y in [f64(0), 37.5, 400, 1210.25, 2600, 4000] {
		document.set_viewport_rect(dom.Rect{0, y, 320, 120})
		_ = viewport_test_commands(mut document)
		mut result := document_layout_result(document)?
		blocks := viewport_visible_paint_entries(mut result).clone()
		assert result.record_scratch.viewport_ink_cache.blocks_valid
		cullable := result.record_scratch.viewport_ink_cache.blocks.filter(it.cullable).len
		assert cullable > 0
		result.record_scratch.viewport_ink_cache.blocks_valid = false
		mut per_entry := []bool{len: result.paint_order.len, init: true}
		viewport := document.viewport_rect()
		mark_viewport_invisible_entries(result, mut per_entry, viewport.width, viewport.height)
		assert blocks == per_entry, 'y=${y}'
		culled_by_blocks += blocks.filter(!it).len
	}
	assert culled_by_blocks > 0
}
