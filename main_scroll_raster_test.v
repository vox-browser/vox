module main

import html
import dom
import layout
import math
import page
import painting
import time

fn test_scroll_raster_revision_tracks_content_but_not_viewport_translation() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{height:1000px;background:green}</style><div id="target"></div>')
	defer { document.finalize() }
	mut app := BrowserApp{ document: document }
	app.relayout(200, 232)
	initial := document.paint_content_revision()
	before := document.cached_display_list() or { panic('missing initial display list') }
	app.begin_frame_preparation()
	app.set_scroll_y(25, 232)
	has_scrolled_list := document.cached_display_list() != none
	assert !has_scrolled_list
	app.finish_frame_preparation()
	after := document.cached_display_list() or { panic('missing scrolled display list') }
	assert voidptr(before) != voidptr(after)
	assert document.paint_content_revision() == initial
	assert layout.viewport_scroll_raster_reusable(document, app.paint_commands, 200, app.viewport_height)
	mut target := document.get_element_by_id('target') or { panic('missing target') }
	target.set_attribute_value('style', 'background:blue')
	app.relayout(200, 232)
	assert document.paint_content_revision() > initial
	changed := document.paint_content_revision()
	document.set_needs_repaint_with_invalidation(.no)
	assert document.paint_content_revision() > changed
	retained := document.paint_content_revision()
	document.invalidate_display_list()
	assert document.paint_content_revision() > retained
}

fn test_scroll_raster_resource_completion_invalidates_pixels_without_rebuilding_geometry() {
	mut document := html.parse_document('<!doctype html><div style="height:1000px;background:green"></div>')
	defer { document.finalize() }
	mut app := BrowserApp{
		document:                    document
		background_resource_results: chan PreloadedResource{cap: 1}
	}
	app.relayout(200, 232)
	root := document.layout_root
	list := document.cached_display_list() or { panic('missing display list') }
	initial := document.paint_content_revision()
	app.poll_background_resources()
	assert document.paint_content_revision() == initial
	address := 'https://image.example.test/background.png'
	for resource in [PreloadedResource{ url: address, body: 'new raster pixels' },
		PreloadedResource{ url: address, error: 'replacement failed' }] {
		before := document.paint_content_revision()
		app.background_resource_results <- resource
		app.poll_background_resources()
		assert document.paint_content_revision() > before
		assert voidptr(document.layout_root) == voidptr(root)
		after := document.cached_display_list() or { panic('lost retained display list') }
		assert voidptr(after) == voidptr(list)
	}
}

fn test_scroll_raster_excludes_nontranslating_and_independent_content() {
	for style in ['perspective:100px'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{width:40px;height:40px;background:green;${style}}</style><div id="target"><div style="transform:rotateY(30deg)">text</div></div><div style="height:1000px"></div>')
		mut app := BrowserApp{ document: document }
		app.relayout(200, 232)
		assert !layout.viewport_scroll_raster_reusable(document, app.paint_commands, 200, app.viewport_height), style
		document.finalize()
	}
	// Fixed, sticky and scroll-compensated content is admitted: the content
	// damage diff repaints it on every scrolled frame.
	for style in ['position:sticky;top:0', 'position:fixed;top:0',
		'background-attachment:fixed;background-image:linear-gradient(red,blue)'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{width:40px;height:40px;background:green;${style}}</style><div id="target"><div style="transform:rotateY(30deg)">text</div></div><div style="height:1000px"></div>')
		mut app := BrowserApp{ document: document }
		app.relayout(200, 232)
		assert layout.viewport_scroll_raster_reusable(document, app.paint_commands, 200, app.viewport_height), style
		document.finalize()
	}
	mut document := html.parse_document('<!doctype html><div style="height:1000px;background:green"></div>')
	defer { document.finalize() }
	mut app := BrowserApp{ document: document }
	app.relayout(200, 232)
	ordinary := layout.PaintCommand{ kind: 'fill_rect', width: 30, height: 30 }
	assert layout.viewport_scroll_raster_reusable(document, [ordinary], 200, 200)
	assert layout.viewport_scroll_raster_reusable(document, [layout.PaintCommand{ ...ordinary, kind: 'paint_uniform_border' }], 200, 200)
	assert layout.viewport_scroll_raster_reusable(document, [layout.PaintCommand{ ...ordinary, kind: 'draw_svg_path' }], 200, 200)
	begin := layout.PaintCommand{ kind: 'begin_skia_command_group' }
	end := layout.PaintCommand{ kind: 'end_skia_command_group' }
	assert layout.viewport_scroll_raster_reusable(document, [begin, ordinary, end], 200, 200)
	for commands in [[begin, ordinary], [ordinary, end], [begin, begin, ordinary, end, end]] {
		assert !layout.viewport_scroll_raster_reusable(document, commands, 200, 200)
	}
	for kind in ['draw_nested_document', 'begin_css_effect_layer', 'apply_backdrop_filter'] {
		assert !layout.viewport_scroll_raster_reusable(document, [layout.PaintCommand{ ...ordinary, kind: kind }], 200, 200), kind
	}
	// Canvases and nested display lists translate; their content changes are
	// repainted through per-frame keys rather than by rejecting the page.
	for kind in ['draw_video', 'draw_canvas', 'paint_nested_display_list'] {
		assert layout.viewport_scroll_raster_reusable(document, [layout.PaintCommand{ ...ordinary, kind: kind }], 200, 200), kind
	}
	assert !layout.viewport_scroll_raster_reusable(document, [layout.PaintCommand{ ...ordinary, scrollbar_axis: 'vertical', x: 60 }], 200, 200)
	bar := layout.PaintCommand{ ...ordinary, scrollbar_axis: 'vertical', x: 190, width: 6 }
	// A bar followed by content belongs to a nested scroller and is content.
	assert layout.viewport_scroll_raster_reusable(document, [bar, ordinary], 200, 200)
	assert layout.viewport_scroll_raster_reusable(document, [layout.PaintCommand{ ...ordinary, scrollbar_axis: 'horizontal', y: 40 }, ordinary], 200, 200)
	assert !layout.viewport_scroll_raster_reusable(document, [layout.PaintCommand{ ...ordinary, kind: 'draw_text', scrollbar_axis: 'horizontal' }, ordinary], 200, 200)
	assert !layout.viewport_scroll_raster_reusable(document, [begin, bar, end], 200, 200)
	assert layout.viewport_scroll_raster_reusable(document, [layout.PaintCommand{ ...ordinary, scrollbar_axis: 'vertical', x: 190, width: 6 }], 200, 200)
}

fn test_scroll_raster_overlay_tail_preserves_eligibility_order_and_layer_indices() {
	mut document := html.parse_document('<!doctype html><div style="height:1000px;background:green"></div>')
	defer { document.finalize() }
	mut app := BrowserApp{ document: document }
	app.relayout(200, 232)
	content := layout.PaintCommand{ kind: 'fill_rect', width: 30, height: 30 }
	vertical := layout.PaintCommand{
		kind: 'fill_rect', x: 190, width: 6, height: 30, scrollbar_axis: 'vertical'
	}
	horizontal := layout.PaintCommand{
		kind: 'fill_rect', y: 190, width: 30, height: 6, scrollbar_axis: 'horizontal'
	}
	assert scroll_raster_scrollbar_start([]layout.PaintCommand{}) == 0
	for commands in [[content], [vertical], [content, content, vertical, horizontal]] {
		assert layout.viewport_scroll_raster_reusable(document, commands, 200, 200)
		mut expected_axes := []string{}
		mut expected_indices := []int{}
		for index, command in commands {
			if command.scrollbar_axis != '' {
				expected_axes << command.scrollbar_axis
				expected_indices << index
			}
		}
		mut actual_axes := []string{}
		mut actual_indices := []int{}
		for index in scroll_raster_scrollbar_start(commands) .. commands.len {
			actual_axes << commands[index].scrollbar_axis
			actual_indices << index
		}
		assert actual_axes == expected_axes
		// Layer selection uses the original command index, even after skipping
		// the document prefix. Sorting or rebasing this suffix changes painting.
		assert actual_indices == expected_indices
	}
	// A leading bar is nested content: it stays in the ring and the trailing
	// run that is replayed after caching is empty.
	assert layout.viewport_scroll_raster_reusable(document, [vertical, content], 200, 200)
	assert scroll_raster_scrollbar_start([vertical, content]) == 2
	nested := scroll_raster_frame_keys([vertical, content], 0, 1, 1024, 768)
	assert !nested[0].skip_diff && nested[0].has_ink
	assert scroll_raster_frame_keys([vertical, content], 0, 0.5, 1024, 768)[0].hash != nested[0].hash
	assert scroll_raster_frame_keys([content, vertical], 0, 1, 1024, 768)[1].skip_diff
}

fn test_scroll_raster_damage_keeps_exposed_strips_overlay_edges_and_unknown_ink() {
	mut damage := ScrollRasterDamage{ reused: true, delta: 10, width: 200, height: 200 }
	ordinary := layout.PaintCommand{ kind: 'fill_rect', x: 30, y: 60, width: 20, height: 20 }
	assert damage.skips(&ordinary)
	for command in [
		layout.PaintCommand{ ...ordinary, underlays_next: true },
		layout.PaintCommand{ ...ordinary, kind: 'stroke_rounded_rect' },
		layout.PaintCommand{ ...ordinary, kind: 'draw_replaced_image' },
		layout.PaintCommand{ ...ordinary, kind: 'draw_background_image' },
		layout.PaintCommand{ ...ordinary, y: 180 },
		layout.PaintCommand{ ...ordinary, y: 168 }, // antialiasing guard at the exposed strip
		layout.PaintCommand{ kind: 'draw_text', text: 'unbounded fallback' },
	] {
		assert !damage.skips(&command)
	}
	assert damage.skips(&layout.PaintCommand{ ...ordinary, x: 184 })
	// The image's retained paintable can intersect damage even when its
	// compatibility command rectangle is outside the exposed strip.
	image := layout.PaintCommand{
		...ordinary
		kind:            'draw_replaced_image'
		image_paintable: &painting.ImagePaintable{
			image_rect: painting.Rect{30, 190, 20, 20}
		}
	}
	assert !damage.skips(&image)
	damage.delta = 0
	assert damage.skips(&ordinary)
	damage.delta = -10
	top := layout.PaintCommand{ ...ordinary, y: 1 }
	assert !damage.skips(&top)
	assert damage.skips(&ordinary)
	// Content damage away from the strip replays the commands it touches.
	damage.rects = [layout.LayoutRect{0, 55, 200, 10}]
	assert !damage.skips(&ordinary)
	assert damage.skips(&layout.PaintCommand{ ...ordinary, y: 100 })
	damage.rects = []
	damage.reused = false
	assert !damage.skips(&ordinary)
}

fn test_scroll_raster_culls_cached_images_using_retained_output_geometry() {
	mut damage := ScrollRasterDamage{ reused: true, delta: 10, width: 200, height: 200 }
	// Compatibility rectangles deliberately disagree with retained output.
	image := layout.PaintCommand{
		kind: 'draw_replaced_image', x: 20, y: 190, width: 20, height: 20
		image_paintable: &painting.ImagePaintable{
			image_rect: painting.Rect{20, 40, 20, 20}
		}
	}
	background := layout.PaintCommand{
		kind: 'draw_background_image', x: 20, y: 190, width: 20, height: 20
		image_data: &layout.PaintImageData{
			image_clip_x: 20, image_clip_y: 40, image_clip_width: 20, image_clip_height: 20
		}
	}
	for command in [image, background] {
		assert damage.skips(&command)
		// Retained transforms, rather than compatibility boxes, bring the
		// pixels back into the newly exposed bottom strip.
		assert !damage.skips(&layout.PaintCommand{
			...command, transform: [f64(1), 0, 0, 1, 0, 145]!
		})
		assert !damage.skips(&layout.PaintCommand{
			...command, transform: [f64(1), 0, 0, 1, 0, math.nan()]!
		})
	}
	// One pixel of image snapping plus the native raster fringe is retained.
	assert !damage.skips(&layout.PaintCommand{
		...image, image_paintable: &painting.ImagePaintable{
			image_rect: painting.Rect{20, 166, 20, 20}
		}
	})
	assert damage.skips(&layout.PaintCommand{
		...image, image_paintable: &painting.ImagePaintable{
			image_rect: painting.Rect{20, 165, 20, 20}
		}
	})
	damage.delta = -10
	for command in [image, background] {
		assert damage.skips(&command)
		assert !damage.skips(&layout.PaintCommand{
			...command, transform: [f64(1), 0, 0, 1, 0, -45]!
		})
	}
	damage.unoptimized = true
	assert !damage.skips(&image)
	assert !damage.skips(&background)
	damage.unoptimized = false
	damage.delta = 0
	assert damage.skips(&image)
	assert damage.skips(&background)
	damage.reused = false
	assert !damage.skips(&image)
}

fn test_scroll_profile_settles_once_and_keeps_scrolling_during_lazy_loads() {
	mut owner := page.Page.create(1)!
	owner.set_enable_autoscroll(false)
	mut document := parse_browser_navigation_document_for_page_with_response_time('<!doctype html><div style="height:1000px"></div>', dom.URL{
		value: 'https://old.reddit.com/'
	}, none, none, unsafe { &dom.Page(owner) }, time.sys_mono_now())
	defer { document.finalize() }
	mut app := &BrowserApp{ document: document, page_model: owner, document_presented: true }
	app.install_chrome_widget_input_bridge()
	app.relayout(200, 232)
	app.scroll_profile = BrowserScrollProfile{
		enabled:    true
		settle_ns:  1
		settled_at: time.sys_mono_now() - 10
	}
	app.background_resource_pending['lazy-image'] = true
	app.begin_scroll_profile_frame()
	assert !app.scroll_profile.active
	assert !app.scroll_profile.settled
	app.background_resource_pending.clear()
	app.scroll_profile.settled_at = time.sys_mono_now() - 10
	app.begin_scroll_profile_frame()
	assert app.scroll_profile.active
	assert app.scroll_profile.settled
	first := app.scroll_y
	assert first > 0
	app.scroll_profile.active = false
	app.background_resource_pending['next-lazy-image'] = true
	app.begin_scroll_profile_frame()
	assert app.scroll_profile.active
	assert app.scroll_y > first
}

fn blur_filter_begin(radius f64) layout.PaintCommand {
	return layout.PaintCommand{
		kind:              'begin_css_filter_layer'
		visual_layer_data: &layout.PaintVisualLayer{
			kind:   .css_filter
			filter: painting.GfxFilter{
				operations: [painting.GfxFilterOperation{ kind: 'blur', first: radius }]
			}
		}
	}
}

fn test_scroll_raster_admits_translating_effects_and_media() {
	mut document := html.parse_document('<!doctype html><div style="height:1000px;background:green"></div>')
	defer { document.finalize() }
	mut app := BrowserApp{ document: document }
	app.relayout(200, 232)
	ordinary := layout.PaintCommand{ kind: 'fill_rect', width: 30, height: 30 }
	for kind in ['fill_gradient', 'draw_video', 'draw_svg_image', 'fill_rect_transparent'] {
		assert layout.viewport_scroll_raster_reusable(document, [layout.PaintCommand{ ...ordinary, kind: kind }], 200, 200), kind
	}
	for kind in ['paint_outer_box_shadow', 'paint_inner_box_shadow', 'fill_inset_shadow', 'draw_text_shadow'] {
		assert layout.viewport_scroll_raster_reusable(document, [layout.PaintCommand{ ...ordinary, kind: kind, blur: 4 }], 200, 200), kind
	}
	// Blur outside a shadow leaf still needs complete replay.
	assert !layout.viewport_scroll_raster_reusable(document, [layout.PaintCommand{ ...ordinary, blur: 4 }], 200, 200)
	effect_begin := layout.PaintCommand{ kind: 'begin_css_effect_layer' }
	effect_end := layout.PaintCommand{ kind: 'end_css_effect_layer' }
	filter_end := layout.PaintCommand{ kind: 'end_css_filter_layer' }
	text_begin := layout.PaintCommand{ kind: 'begin_background_text_clip', width: 40, height: 20 }
	text_end := layout.PaintCommand{ kind: 'end_background_text_clip' }
	grayscale_begin := layout.PaintCommand{
		kind:              'begin_css_filter_layer'
		visual_layer_data: &layout.PaintVisualLayer{
			kind:   .css_filter
			filter: painting.GfxFilter{ operations: [painting.GfxFilterOperation{ kind: 'grayscale', first: 1 }] }
		}
	}
	assert layout.viewport_scroll_raster_reusable(document, [effect_begin, ordinary, effect_end], 200, 200)
	assert layout.viewport_scroll_raster_reusable(document, [grayscale_begin, ordinary, filter_end], 200, 200)
	assert layout.viewport_scroll_raster_reusable(document, [text_begin, layout.PaintCommand{ ...ordinary, kind: 'fill_gradient' }, text_end], 200, 200)
	assert layout.viewport_scroll_raster_reusable(document, [effect_begin, grayscale_begin, ordinary, filter_end, effect_end], 200, 200)
	assert layout.viewport_scroll_raster_reusable(document, [blur_filter_begin(10), ordinary, filter_end], 200, 200)
	for commands in [[effect_begin, ordinary], [ordinary, effect_end], [effect_begin, ordinary, filter_end],
		[blur_filter_begin(10), effect_begin, ordinary, filter_end, effect_end]] {
		assert !layout.viewport_scroll_raster_reusable(document, commands, 200, 200)
	}
	// A blur layer is rasterized at its device position, so its key never
	// matches a retained frame and the whole layer is repainted each frame;
	// a pointwise filter layer keeps a stable key.
	blur_keys := scroll_raster_frame_keys([blur_filter_begin(10), ordinary, filter_end], 0, 1, 1024, 768)
	assert scroll_raster_frame_keys([blur_filter_begin(10), ordinary, filter_end], 0, 1, 1024, 768)[0].hash != blur_keys[0].hash
	gray_keys := scroll_raster_frame_keys([grayscale_begin, ordinary, filter_end], 0, 1, 1024, 768)
	assert scroll_raster_frame_keys([grayscale_begin, ordinary, filter_end], 0, 1, 1024, 768)[0].hash == gray_keys[0].hash
	svg_filter := layout.PaintCommand{
		kind:              'begin_css_filter_layer'
		visual_layer_data: &layout.PaintVisualLayer{
			kind:   .css_filter
			filter: painting.GfxFilter{ nodes: [painting.GfxFilterNode{ id: 1, kind: 'feGaussianBlur' }], root_id: 1 }
		}
	}
	assert !layout.viewport_scroll_raster_reusable(document, [svg_filter, ordinary, filter_end], 200, 200)
}

fn test_scroll_raster_leaf_ink_bounds_cover_shadows_and_media() {
	shadow := layout.PaintCommand{ kind: 'paint_outer_box_shadow', x: 50, y: 60, width: 100, height: 40, blur: 5 }
	assert (layout.scroll_raster_leaf_ink_bounds(&shadow) or { panic('missing shadow ink') }) == layout.LayoutRect{40, 50, 120, 60}
	inner := layout.PaintCommand{
		kind:            'paint_inner_box_shadow'
		width:           300
		height:          300
		blur:            9
		box_shadow_data: &layout.PaintBoxShadowData{ content_rect: layout.LayoutRect{10, 20, 30, 40} }
	}
	assert (layout.scroll_raster_leaf_ink_bounds(&inner) or { panic('missing inner ink') }) == layout.LayoutRect{10, 20, 30, 40}
	video := layout.PaintCommand{ kind: 'draw_video', x: 5, y: 6, width: 7, height: 8 }
	assert (layout.scroll_raster_leaf_ink_bounds(&video) or { panic('missing video ink') }) == layout.LayoutRect{4, 5, 9, 10}
	// The viewport scroll folded into the transform moves the ink.
	scrolled := layout.PaintCommand{ ...shadow, transform: [f64(1), 0, 0, 1, 0, -30]! }
	assert (layout.scroll_raster_leaf_ink_bounds(&scrolled) or { panic('missing scrolled ink') }) == layout.LayoutRect{40, 20, 120, 60}
	blur := blur_filter_begin(10)
	assert (layout.scroll_raster_filter_extent(&blur) or { panic('missing extent') }) == 31
	assert !layout.scroll_raster_filter_is_pointwise(&blur)
	grayscale := layout.PaintCommand{
		kind:              'begin_css_filter_layer'
		visual_layer_data: &layout.PaintVisualLayer{
			kind:   .css_filter
			filter: painting.GfxFilter{ operations: [painting.GfxFilterOperation{ kind: 'grayscale', first: 1 }] }
		}
	}
	assert layout.scroll_raster_filter_is_pointwise(&grayscale)
}

fn test_scroll_raster_frame_keys_ignore_viewport_translation_and_track_content() {
	base := layout.PaintCommand{ kind: 'fill_rect', x: 30, y: 60, width: 20, height: 20, color: 'red' }
	moved := layout.PaintCommand{ ...base, transform: [f64(1), 0, 0, 1, 0, -10]! }
	keys_a := scroll_raster_frame_keys([base], 0, 1, 1024, 768)
	keys_b := scroll_raster_frame_keys([moved], 10, 1, 1024, 768)
	assert keys_a[0].hash == keys_b[0].hash
	assert keys_a[0].has_ink && keys_a[0].ink == layout.LayoutRect{30, 60, 20, 20}
	assert keys_b[0].ink == layout.LayoutRect{30, 50, 20, 20}
	assert scroll_raster_frame_keys([layout.PaintCommand{ ...base, color: 'blue' }], 0, 1, 1024, 768)[0].hash != keys_a[0].hash
	assert scroll_raster_frame_keys([layout.PaintCommand{ ...base, opacity: 0.5 }], 0, 1, 1024, 768)[0].hash != keys_a[0].hash
	assert scroll_raster_frame_keys([layout.PaintCommand{ ...base, transform: [f64(2), 0, 0, 1, 0, 0]! }], 0, 1, 1024, 768)[0].hash != keys_a[0].hash
	// A scroll offset the transform does not reflect is a content move.
	assert scroll_raster_frame_keys([base], 10, 1, 1024, 768)[0].hash != keys_a[0].hash
	// Groups carry their complete extent, filters inflate it, ends close them.
	commands := [
		layout.PaintCommand{ kind: 'begin_css_effect_layer' },
		base,
		layout.PaintCommand{ ...base, x: 100, y: 100 },
		layout.PaintCommand{ kind: 'end_css_effect_layer' },
		blur_filter_begin(10),
		layout.PaintCommand{ ...base, x: 150, y: 150 },
		layout.PaintCommand{ kind: 'end_css_filter_layer' },
		layout.PaintCommand{ ...base, scrollbar_axis: 'vertical' },
	]
	keys := scroll_raster_frame_keys(commands, 0, 1, 1024, 768)
	assert keys[0].group_end == 3
	assert keys[0].has_ink && keys[0].ink == layout.LayoutRect{30, 60, 90, 60}
	assert keys[4].group_end == 6
	assert keys[4].has_ink && keys[4].ink == layout.LayoutRect{119, 119, 82, 82}
	// Group ends write nothing; they stay bounded (empty ink) so an entering
	// group reconciles through its begin's extent.
	assert keys[3].has_ink && keys[3].ink.width == 0 && keys[3].ink.height == 0
	assert keys[6].has_ink && keys[6].ink.width == 0 && keys[6].ink.height == 0
	assert keys[7].skip_diff
}

fn test_scroll_raster_keys_follow_video_frame_generation() {
	mut source := painting.VideoFrameSource.create()
	mut frame := painting.MediaVideoFrame.from_bitmap(&dom.Bitmap_{ width: 2, height: 2, pitch: 8, data: []u8{len: 16} })
	source.update(frame)
	video := layout.PaintCommand{ kind: 'draw_video', width: 2, height: 2, video_frame_source: source }
	before := scroll_raster_frame_keys([video], 0, 1, 1024, 768)[0].hash
	assert scroll_raster_frame_keys([video], 0, 1, 1024, 768)[0].hash == before
	frame.generation++
	assert scroll_raster_frame_keys([video], 0, 1, 1024, 768)[0].hash != before
}

fn test_scroll_raster_content_damage_covers_only_changed_commands() {
	base := layout.PaintCommand{ kind: 'fill_rect', x: 30, y: 60, width: 20, height: 20, color: 'red' }
	other := layout.PaintCommand{ ...base, x: 120, y: 20, color: 'green' }
	previous := ScrollRasterKeyFrame{
		valid:    true
		document: 7
		width:    200
		height:   200
		keys:     scroll_raster_frame_keys([base, other], 0, 1, 1024, 768)
	}
	scrolled := [f64(1), 0, 0, 1, 0, -10]!
	mut stats := ScrollRasterDiffStats{}
	unchanged := scroll_raster_frame_keys([layout.PaintCommand{ ...base, transform: scrolled },
		layout.PaintCommand{ ...other, transform: scrolled }], 10, 1, 1024, 768)
	none_changed := scroll_raster_content_damage(&previous, unchanged, 7, 10, 200, 200, mut stats) or {
		panic('unchanged frames must reconcile')
	}
	assert none_changed.len == 0
	assert stats.changed == 0
	changed := scroll_raster_frame_keys([layout.PaintCommand{ ...base, transform: scrolled, color: 'blue' },
		layout.PaintCommand{ ...other, transform: scrolled }], 10, 1, 1024, 768)
	rects := scroll_raster_content_damage(&previous, changed, 7, 10, 200, 200, mut stats) or {
		panic('one change must reconcile')
	}
	// Old and new ink of the changed command, both in current viewport space,
	// with the raster fringe snapped outward to whole pixels.
	assert rects.len == 2
	for rect in rects {
		assert rect == layout.LayoutRect{27, 47, 26, 26}
	}
	assert stats.changed == 2
	// Entries entering below the viewport add no visible damage.
	entering := scroll_raster_frame_keys([layout.PaintCommand{ ...base, transform: scrolled },
		layout.PaintCommand{ ...other, transform: scrolled },
		layout.PaintCommand{ ...base, y: 400, transform: scrolled }], 10, 1, 1024, 768)
	assert (scroll_raster_content_damage(&previous, entering, 7, 10, 200, 200, mut stats) or {
		panic('entering content must reconcile')
	}).len == 0
	// Reordered content, unbounded changes, other documents and absent
	// frames all need complete replay.
	reordered := scroll_raster_frame_keys([layout.PaintCommand{ ...other, transform: scrolled },
		layout.PaintCommand{ ...base, transform: scrolled }], 10, 1, 1024, 768)
	assert scroll_raster_content_damage(&previous, reordered, 7, 10, 200, 200, mut stats) == none
	assert stats.fallback == 'paint-order-changed'
	unbounded := scroll_raster_frame_keys([layout.PaintCommand{ ...base, transform: scrolled },
		layout.PaintCommand{ ...other, transform: scrolled },
		layout.PaintCommand{ kind: 'draw_text', text: 'late' }], 10, 1, 1024, 768)
	assert scroll_raster_content_damage(&previous, unbounded, 7, 10, 200, 200, mut stats) == none
	assert scroll_raster_content_damage(&previous, unchanged, 8, 10, 200, 200, mut stats) == none
	invalid := ScrollRasterKeyFrame{}
	assert scroll_raster_content_damage(&invalid, unchanged, 7, 10, 200, 200, mut stats) == none
	// Fixed content keeps its viewport position while the ring shifts, so an
	// unchanged fixed command is damaged at both its vacated and current place.
	fixed := layout.PaintCommand{ kind: 'fill_rect', x: 20, y: 100, width: 40, height: 10, fixed_to_viewport: true }
	fixed_previous := ScrollRasterKeyFrame{ valid: true, document: 7, width: 200, height: 200, keys: scroll_raster_frame_keys([fixed], 0, 1, 1024, 768) }
	fixed_rects := scroll_raster_content_damage(&fixed_previous, scroll_raster_frame_keys([fixed], 10, 1, 1024, 768), 7, 10, 200, 200, mut stats) or {
		panic('fixed content must reconcile')
	}
	assert fixed_rects.len == 2
	assert layout.LayoutRect{17, 87, 46, 16} in fixed_rects
	assert layout.LayoutRect{17, 97, 46, 16} in fixed_rects
	// Without a scroll change the same fixed command needs no repaint.
	assert (scroll_raster_content_damage(&fixed_previous, scroll_raster_frame_keys([fixed], 0, 1, 1024, 768), 7, 0, 200, 200, mut stats) or {
		panic('stationary fixed content must reconcile')
	}).len == 0
}

fn test_scroll_raster_skip_plan_handles_groups_and_filters() {
	leaf := layout.PaintCommand{ kind: 'fill_rect', x: 10, width: 50, height: 20 }
	commands := [
		layout.PaintCommand{ ...leaf, y: 10 },
		layout.PaintCommand{ kind: 'begin_css_effect_layer' },
		layout.PaintCommand{ ...leaf, y: 50 },
		layout.PaintCommand{ ...leaf, y: 150 },
		layout.PaintCommand{ kind: 'end_css_effect_layer' },
		blur_filter_begin(5),
		layout.PaintCommand{ ...leaf, y: 100 },
		layout.PaintCommand{ kind: 'end_css_filter_layer' },
		layout.PaintCommand{ ...leaf, y: 185 },
	]
	keys := scroll_raster_frame_keys(commands, 0, 1, 1024, 768)
	strip := scroll_raster_strip_region(10, 200, 200)
	assert strip == [layout.LayoutRect{0, 190, 200, 10}]
	assert plan_scroll_raster_skips(commands, keys, strip, false) == [true, true, true, true, true, true, true, true, false]
	// Damage touching one effect child replays the boundaries and that child.
	assert plan_scroll_raster_skips(commands, keys, [layout.LayoutRect{0, 45, 200, 10}], false) == [true, false, false, true, false, true, true, true, true]
	// A blur filter whose extent touches the damage replays all of its contents.
	assert plan_scroll_raster_skips(commands, keys, [layout.LayoutRect{0, 130, 200, 5}], false) == [true, false, true, true, false, false, false, false, true]
	underlay := [layout.PaintCommand{ ...leaf, y: 10, underlays_next: true }]
	assert !plan_scroll_raster_skips(underlay, scroll_raster_frame_keys(underlay, 0, 1, 1024, 768), strip, false)[0]
	image := [layout.PaintCommand{ ...leaf, kind: 'draw_replaced_image', y: 10 }]
	assert !plan_scroll_raster_skips(image, scroll_raster_frame_keys(image, 0, 1, 1024, 768), strip, true)[0]
	assert scroll_raster_strip_region(0, 200, 200).len == 0
	assert scroll_raster_strip_region(-10, 200, 200) == [layout.LayoutRect{0, 0, 200, 10}]
}

// Viewport-only recording folds the root scroll into each command transform.
fn scroll_raster_scrolled_commands(commands []layout.PaintCommand, scroll f64) []layout.PaintCommand {
	mut shifted := []layout.PaintCommand{cap: commands.len}
	for command in commands {
		mut matrix := layout.scroll_raster_normalized_transform(command.transform)
		matrix[5] -= scroll
		shifted << layout.PaintCommand{
			...command
			transform: matrix
		}
	}
	return shifted
}

fn test_scroll_raster_gradient_blur_keys_translate_with_content() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}.showcase{position:relative;height:500px;isolation:isolate}.showcase::before{content:"";position:absolute;inset:10% 0 5%;background:radial-gradient(ellipse at center,#263d5d28,transparent 68%);filter:blur(30px);pointer-events:none}</style><section class="showcase"></section>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	list := document.record_display_list() or { panic('missing showcase paint') }
	commands := layout.display_list_commands(list)
	mut begin := -1
	for index, command in commands {
		if command.kind == 'begin_css_filter_layer' { begin = index }
	}
	assert begin >= 0
	assert chromium_gradient_blur_input_supported(commands, begin)
	scrolled := scroll_raster_scrolled_commands(commands, 37)
	// A top-level single-gradient blur rasterizes anchored to its content, so
	// its retained pixels translate and its identity survives the scroll.
	first := scroll_raster_frame_keys(commands, 0, 1, 1024, 768)
	second := scroll_raster_frame_keys(scrolled, 37, 1, 1024, 768)
	assert first[begin].hash == second[begin].hash
	assert first[begin].has_ink && second[begin].has_ink
	assert second[begin].ink.y == first[begin].ink.y - 37
	key := chromium_gradient_blur_content_key(commands, begin, 0)
	assert key != 0
	assert chromium_gradient_blur_content_key(scrolled, begin, 37) == key
	// The content identity follows the blurred gradient itself.
	mut restopped := commands.clone()
	for index in begin + 1 .. restopped.len {
		if restopped[index].kind != 'fill_gradient' { continue }
		gradient := restopped[index].gradient or { panic('missing gradient') }
		mut stops := gradient.stops.clone()
		stops[0] = layout.GradientStop{
			...stops[0]
			offset: stops[0].offset + 0.25
		}
		restopped[index] = layout.PaintCommand{
			...restopped[index]
			gradient: &layout.LinearGradient{
				...*gradient
				stops: stops
			}
		}
	}
	assert chromium_gradient_blur_content_key(restopped, begin, 0) != key
	// Nested inside another group, the layer may composite through another
	// path; other blurred content keeps repainting every frame.
	mut nested := [layout.PaintCommand{ kind: 'begin_css_effect_layer' }]
	nested << commands[begin..]
	nested << layout.PaintCommand{ kind: 'end_css_effect_layer' }
	assert scroll_raster_frame_keys(nested, 0, 1, 1024, 768)[1].hash != scroll_raster_frame_keys(nested, 0, 1, 1024, 768)[1].hash
	plain := [blur_filter_begin(10), layout.PaintCommand{ kind: 'fill_rect', x: 10, y: 10, width: 20, height: 20, color: 'red' },
		layout.PaintCommand{ kind: 'end_css_filter_layer' }]
	assert scroll_raster_frame_keys(plain, 0, 1, 1024, 768)[0].hash != scroll_raster_frame_keys(plain, 0, 1, 1024, 768)[0].hash
}
