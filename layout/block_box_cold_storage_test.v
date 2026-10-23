module layout

import css
import html
import painting
import platform

fn test_block_box_cold_headers_preserve_generic_and_ordinary_defaults() {
	assert sizeof(BlockBox) <= 1100
	println('BlockBox=${sizeof(BlockBox)} media=${sizeof(BlockBoxMediaData)} decoration=${sizeof(BlockBoxDecorationData)} filter=${sizeof(BlockBoxFilterData)} scroll_snap=${sizeof(BlockBoxScrollSnapData)} clip=${sizeof(BlockBoxClipData)} canvas=${sizeof(BlockBoxCanvasData)}')
	box := BlockBox{}
	assert isnil(box.media_data) && isnil(box.decoration_data) && isnil(box.filter_data)
	assert isnil(box.scroll_snap_data) && isnil(box.clip_data) && isnil(box.canvas_data)
	assert box.media().video_representation == .video_frame
	assert box.media().replaced_image_position_x == ''
	assert box.media().replaced_image_position_y == ''
	assert box.media().form_control_enabled
	assert box.decorations().background_color_clip == 'border-box'
	assert box.decorations().shadows.len == 0 && box.decorations().background_images.len == 0
	assert !box.filters().filter.has_filters() && !box.filters().backdrop_filter.has_filters()
	assert box.scroll_snap().scroll_snap_type.axis == .both
	assert box.scroll_snap().scroll_snap_type.strictness == .none_
	assert box.clips().css_clip == none && box.clips().clip_path == none
	assert box.clips().svg_clip == none && box.clips().svg_mask == none
	assert !box.canvas().paints_canvas_background && box.canvas().viewport_width == 0
	assert box.canvas().canvas_background_color.a == 255
	transparent_canvas := BlockBox{
		canvas_data: retained_block_box_canvas(BlockBoxCanvasData{
			canvas_background_color: css.Color{0, 0, 0, 0}
		})
	}
	assert !isnil(transparent_canvas.canvas_data)
	assert transparent_canvas.canvas().canvas_background_color.a == 0
	ordinary := BlockBox{
		media_data: retained_block_box_media(BlockBoxMediaData{
			video_representation:      .transparent_black
			replaced_image_position_x: '50%'
			replaced_image_position_y: '50%'
		})
	}
	assert voidptr(ordinary.media_data) == voidptr(ordinary_block_box_media)
	assert ordinary.media().video_representation == .transparent_black
	assert ordinary.media().replaced_image_position_x == '50%'
	assert ordinary.media().replaced_image_position_y == '50%'
	assert ordinary.media().form_control_enabled
}

fn test_default_block_box_cold_header_factories_do_not_allocate_per_call() {
	mut arena := platform.new_arena('empty block paint headers')
	entry := arena.enter()
	mut defaults := 0
	for _ in 0 .. 512 {
		if isnil(retained_block_box_media(BlockBoxMediaData{})) { defaults++ }
		if isnil(retained_block_box_decoration(BlockBoxDecorationData{})) { defaults++ }
		if isnil(retained_block_box_filter(BlockBoxFilterData{})) { defaults++ }
		if isnil(retained_block_box_scroll_snap(BlockBoxScrollSnapData{})) { defaults++ }
		if isnil(retained_block_box_clip(BlockBoxClipData{})) { defaults++ }
		if isnil(retained_block_box_canvas(BlockBoxCanvasData{})) { defaults++ }
		ordinary := retained_block_box_media(BlockBoxMediaData{
			video_representation:      .transparent_black
			replaced_image_position_x: '50%'
			replaced_image_position_y: '50%'
		})
		if voidptr(ordinary) == voidptr(ordinary_block_box_media) { defaults++ }
	}
	arena.leave(entry)
	assert defaults == 512 * 7
	$if prealloc {
		assert arena.usage().used < 4096, '${arena.usage().used} retained bytes for empty headers'
	}
	arena.release()
}

fn test_populated_block_box_headers_replace_without_mutating_value_copies() {
	mut box := BlockBox{
		media_data:       retained_block_box_media(BlockBoxMediaData{
			replaced_image_url:   'old.png'
			form_control_kind:    'checkbox'
			form_control_checked: true
			form_control_enabled: false
		})
		decoration_data:  retained_block_box_decoration(BlockBoxDecorationData{
			border_radius:     4
			outline_width:     2
			outline_offset:    3
			background_images: [BackgroundImageLayer{ url: 'background.png' }]
		})
		filter_data:      retained_block_box_filter(BlockBoxFilterData{
			filter: painting.ResolvedCSSFilter.with_svg_filter([], none, painting.Rect{1, 2, 30, 40})
		})
		scroll_snap_data: retained_block_box_scroll_snap(BlockBoxScrollSnapData{
			scroll_snap_align: css.ScrollSnapAlignData{ block_alignment: .center, inline_alignment: .end_ }
			scroll_snap_stop:  .always
			scroll_snap_type:  css.ScrollSnapType{ axis: .x, strictness: .mandatory }
			scroll_margin:     BoxEdges{ top: 5 }
			scroll_padding:    BoxEdges{ left: 6 }
		})
		clip_data:        retained_block_box_clip(BlockBoxClipData{
			css_clip:  &LayoutRect{1, 2, 30, 40}
			clip_path: &painting.ClipPathVisualData{ polygon: [painting.Point{1, 2}] }
			svg_clip:  &painting.SVGClipVisualData{ cache_key: 17 }
			svg_mask:  &painting.SVGMaskVisualData{ cache_key: 23 }
		})
		canvas_data:      retained_block_box_canvas(BlockBoxCanvasData{
			canvas_background_color:  css.Color{12, 34, 56, 255}
			canvas_x:                 3
			canvas_y:                 4
			canvas_width:             300
			canvas_height:            200
			paints_canvas_background: true
			viewport_width:           320
			viewport_height:          240
		})
	}
	old := box
	box.media_data = retained_block_box_media(BlockBoxMediaData{ ...*box.media(), replaced_image_url: 'new.png' })
	box.decoration_data = retained_block_box_decoration(BlockBoxDecorationData{ ...*box.decorations(), border_radius: 9 })
	box.filter_data = retained_block_box_filter(BlockBoxFilterData{})
	box.scroll_snap_data = retained_block_box_scroll_snap(BlockBoxScrollSnapData{})
	box.clip_data = retained_block_box_clip(BlockBoxClipData{ css_clip: &LayoutRect{8, 9, 10, 11} })
	box.canvas_data = retained_block_box_canvas(BlockBoxCanvasData{ viewport_width: 640 })
	gc_collect()
	assert old.media().replaced_image_url == 'old.png'
	assert old.media().form_control_checked && !old.media().form_control_enabled
	assert box.media().replaced_image_url == 'new.png'
	assert old.decorations().border_radius == 4 && box.decorations().border_radius == 9
	assert old.decorations().outline_width == 2 && old.decorations().outline_offset == 3
	assert old.decorations().background_images[0].url == 'background.png'
	assert !old.filters().filter.has_filters()
	bounds := old.filters().filter.svg_filter_bounds() or { panic('missing filter bounds') }
	assert bounds.x == 1 && bounds.width == 30
	assert box.filters().filter.svg_filter_bounds() == none
	assert old.scroll_snap().scroll_snap_align.block_alignment == .center
	assert old.scroll_snap().scroll_snap_align.inline_alignment == .end_
	assert old.scroll_snap().scroll_snap_stop == .always
	assert old.scroll_snap().scroll_snap_type.strictness == .mandatory
	assert old.scroll_snap().scroll_margin.top == 5 && old.scroll_snap().scroll_padding.left == 6
	assert box.scroll_snap().scroll_snap_type.strictness == .none_
	old_clip := old.clips().css_clip or { panic('missing old clip') }
	new_clip := box.clips().css_clip or { panic('missing new clip') }
	assert old_clip.x == 1 && new_clip.x == 8
	path := old.clips().clip_path or { panic('missing clip path') }
	assert path.polygon[0].x == 1
	svg_clip := old.clips().svg_clip or { panic('missing SVG clip') }
	svg_mask := old.clips().svg_mask or { panic('missing SVG mask') }
	assert svg_clip.cache_key == 17 && svg_mask.cache_key == 23
	assert old.canvas().canvas_background_color.r == 12
	assert old.canvas().canvas_x == 3 && old.canvas().canvas_y == 4
	assert old.canvas().canvas_width == 300 && old.canvas().canvas_height == 200
	assert old.canvas().paints_canvas_background
	assert old.canvas().viewport_width == 320 && old.canvas().viewport_height == 240
	assert box.canvas().viewport_width == 640 && !box.canvas().paints_canvas_background
}

fn test_block_box_shadow_fallback_does_not_write_empty_published_array_capacity() {
	mut backing := [BoxShadow{ offset_x: 71, color: css.Color{0, 0, 0, 255} }]
	empty := unsafe { backing[..0] }
	box := BlockBox{
		width:           40
		height:          20
		decoration_data: retained_block_box_decoration(BlockBoxDecorationData{
			shadow:  BoxShadow{ offset_x: 9, blur: 2, color: css.Color{0, 0, 0, 255} }
			shadows: empty
		})
	}
	commands := box.paint_commands()
	assert commands.any(it.kind == 'paint_outer_box_shadow')
	assert backing[0].offset_x == 71
	assert box.decorations().shadows.len == 0
}

fn test_retained_cold_block_headers_and_scene_survive_full_layout_rebuild() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{width:80px;height:30px;background:red;border-radius:4px;outline:2px solid blue;clip-path:inset(1px)}</style><div id="target">retained</div>')
	defer { document.finalize() }
	enable_native_paint_tree_storage(document)
	_ = layout_document_typed_in_viewport(document, 320, 200)
	previous := document_layout_result(document) or { panic('missing layout') }
	geometry := retain_document_paint_tree(document)
	list := document.record_display_list() or { panic('missing paint') }
	scene := retain_display_list_scene(list)
	defer {
		release_display_list_scene(scene)
		release_paint_tree(geometry)
	}
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	identity := i64(target.as_node().unique_id())
	old_box := previous.paint_tree.find_box(identity) or { panic('missing old box') }
	old_radius := old_box.decorations().border_radius
	old_radii := old_box.decorations().border_radii
	old_clip := old_box.clips().clip_path or { panic('missing old clip') }
	old_dump := list.dump()
	assert old_box.width == 80
	assert old_box.decorations().outline_width == 2
	target.set_attribute_value('style', 'width:120px;border-radius:9px;outline-width:5px;clip-path:inset(3px);background:green')
	document.update_layout(.debugging)
	current := document_layout_result(document) or { panic('missing replacement') }
	new_box := current.paint_tree.find_box(identity) or { panic('missing replacement box') }
	_ = document.record_display_list() or { panic('missing replacement paint') }
	assert new_box.width == 120 && new_box.decorations().outline_width == 5
	assert old_box.width == 80 && old_box.decorations().outline_width == 2
	assert old_box.decorations().border_radius == old_radius
	assert old_box.decorations().border_radii == old_radii
	assert voidptr(old_box.clips().clip_path or { panic('missing retained clip') }) == voidptr(old_clip)
	assert list.dump() == old_dump
}
