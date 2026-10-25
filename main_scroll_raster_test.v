module main

import html
import dom
import layout
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
	for style in ['position:sticky;top:0', 'position:fixed;top:0',
		'background-attachment:fixed;background-image:linear-gradient(red,blue)', 'filter:blur(2px)',
		'perspective:100px'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{width:40px;height:40px;background:green;${style}}</style><div id="target"><div style="transform:rotateY(30deg)">text</div></div><div style="height:1000px"></div>')
		mut app := BrowserApp{ document: document }
		app.relayout(200, 232)
		assert !layout.viewport_scroll_raster_reusable(document, app.paint_commands, 200, app.viewport_height), style
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
	for kind in ['draw_canvas', 'draw_video', 'draw_nested_document', 'begin_css_effect_layer'] {
		assert !layout.viewport_scroll_raster_reusable(document, [layout.PaintCommand{ ...ordinary, kind: kind }], 200, 200), kind
	}
	assert !layout.viewport_scroll_raster_reusable(document, [layout.PaintCommand{ ...ordinary, scrollbar_axis: 'vertical', x: 60 }], 200, 200)
	bar := layout.PaintCommand{ ...ordinary, scrollbar_axis: 'vertical', x: 190, width: 6 }
	assert !layout.viewport_scroll_raster_reusable(document, [bar, ordinary], 200, 200)
	assert !layout.viewport_scroll_raster_reusable(document, [begin, bar, end], 200, 200)
	assert layout.viewport_scroll_raster_reusable(document, [layout.PaintCommand{ ...ordinary, scrollbar_axis: 'vertical', x: 190, width: 6 }], 200, 200)
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
	damage.reused = false
	assert !damage.skips(&ordinary)
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
