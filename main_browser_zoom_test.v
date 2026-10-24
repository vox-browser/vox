module main

import dom
import gg
import layout
import page

fn test_zoom_shortcuts_preserve_selected_address_and_ignore_shortcut_characters() {
	modifier := $if macos { gg.Modifier.super } $else { gg.Modifier.ctrl }
	mut app := BrowserApp{ address: 'https://example.test/unfinished' }
	app.focus_address_bar()
	app.handle_key(.equal, modifier | .shift)
	assert app.page_zoom == 1.1
	app.handle_key(.kp_add, modifier | .shift)
	assert app.page_zoom == 1.25
	app.handle_key(.kp_equal, modifier | .shift)
	assert app.page_zoom == 1.5
	app.handle_key(._0, modifier)
	assert app.page_zoom == 1
	app.handle_key(.minus, modifier)
	assert app.page_zoom == 0.9
	app.handle_key(.kp_add, modifier)
	assert app.page_zoom == 1
	app.handle_key(.kp_subtract, modifier)
	assert app.page_zoom == 0.9
	app.handle_key(.kp_0, modifier)
	assert app.page_zoom == 1
	app.platform_pointer_modifiers = $if macos { dom.modifier_super } $else { dom.modifier_ctrl }
	for character in '0+-='.runes() { app.handle_character(u32(character)) }
	assert app.address == 'https://example.test/unfinished'
	assert app.address_active && app.address_select
	assert app.address_cursor == app.address.len
	assert browser_zoom_shortcut(.equal, unsafe { gg.Modifier(0) }) == ''
	assert browser_zoom_shortcut(.equal, modifier | .alt) == ''
	assert browser_zoom_shortcut(._0, modifier | .shift) == ''
	assert browser_zoom_shortcut(.minus, modifier | .shift) == ''
	$if macos {
		assert browser_zoom_shortcut(.equal, .ctrl) == ''
	}
}

fn test_zoom_is_bounded_invalidates_snapshots_and_is_not_deferred_as_page_input() {
	modifier := $if macos { gg.Modifier.super } $else { gg.Modifier.ctrl }
	mut app := BrowserApp{}
	for _ in 0 .. 40 { app.handle_key(.equal, modifier) }
	assert app.page_zoom == 5
	for _ in 0 .. 40 { app.handle_key(.minus, modifier) }
	assert app.page_zoom == 0.25
	app.handle_key(._0, modifier)
	assert app.page_zoom == 1
	path := app.browser_chrome_snapshot_path('https://example.test/')
	app.snapshot_cached = true
	app.snapshot_hold = true
	app.snapshot_hold_until = 1
	app.navigation_work_depth = 1
	app.handle_event(&gg.Event{ typ: .key_down, key_code: .equal, modifiers: u32(modifier) })
	assert app.deferred_page_input.len == 0
	assert app.page_zoom == 1.1
	assert !app.snapshot_cached && !app.snapshot_hold
	assert app.snapshot_hold_until == 0
	assert app.browser_chrome_snapshot_path('https://example.test/') != path
}

fn test_zoom_reflows_css_viewport_projects_paint_and_preserves_scroll_position() {
	mut owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_with_scripting('<!doctype html><style>
		html,body{margin:0} #fill{width:100%;height:1400px;background:rgb(17 34 51)}
		#link{position:absolute;left:100px;top:50px;width:60px;height:40px;background:red}
		</style><div id="fill"></div><a id="link" href="/target"></a>',
		dom.url_about_blank(), none, none, unsafe { &dom.Page(owner) }, 0, false)
	mut app := BrowserApp{ document: document, page_model: owner }
	defer {
		app.release_paint_commands()
		layout.release_paint_tree(app.paint_tree_storage)
		document.finalize()
	}
	app.relayout(800, 600 + app.chrome_height())
	fill := document.get_element_by_id('fill')?
	assert fill.get_bounding_client_rect().width == 800
	app.set_scroll_y(100, 600 + app.chrome_height())
	for _ in 0 .. 5 { app.activate_browser_zoom('zoom-in') }
	assert app.page_zoom == 2
	app.relayout(800, 600 + app.chrome_height())
	assert app.viewport_width == 800 && app.viewport_height == 600
	assert document.viewport_rect().width == 400
	assert document.viewport_rect().height == 300
	assert fill.get_bounding_client_rect().width == 400
	assert app.content_height == 2800
	assert app.scroll_y == 200 && document.viewport_rect().y == 100
	assert owner.client().zoom_level() == 2
	app.set_scroll_y(0, 600 + app.chrome_height())
	hit := app.hit_test_at_viewport_point(240, 140) or { panic('missing zoomed hit') }
	assert hit.element.get_attribute_value('id') == 'link'
	app.set_scroll_y(80, 600 + app.chrome_height())
	scrolled_hit := app.hit_test_at_viewport_point(240, 60) or { panic('missing scrolled zoomed hit') }
	assert scrolled_hit.element.get_attribute_value('id') == 'link'
	app.record_document_paint_commands()
	assert app.paint_commands.any(it.color == 'rgb(17 34 51)')
	for command in app.paint_commands {
		if command.color != 'rgb(17 34 51)' { continue }
		projected := app.zoomed_paint_command(command)
		assert projected.transform[0] == 2 * normalized_paint_transform(command.transform)[0]
		assert projected.transform[5] == 2 * normalized_paint_transform(command.transform)[5]
	}
	app.activate_browser_zoom('zoom-reset')
	app.relayout(800, 600 + app.chrome_height())
	assert document.viewport_rect().width == 800 && document.viewport_rect().height == 600
	assert app.scroll_y == 40 && document.viewport_rect().y == 40
	assert fill.get_bounding_client_rect().width == 800
	assert owner.client().zoom_level() == 1
}

fn test_zoom_projects_clips_without_mutating_retained_commands() {
	app := BrowserApp{ page_zoom: 2 }
	command := layout.PaintCommand{
		kind:        'fill_rect'
		transform:   [f64(1), 0, 0, 1, 10, 20]!
		has_clip:    true
		clip_x:      5
		clip_y:      6
		clip_width:  30
		clip_height: 40
		clip_list:   &layout.PaintClipList{
			items: [layout.PaintClip{
				transform: [f64(1), 0, 0, 1, 7, 8]!
			}]
		}
	}
	projected := app.zoomed_paint_command(command)
	assert projected.transform == [f64(2), 0, 0, 2, 20, 40]!
	assert projected.clip_x == 10 && projected.clip_y == 12
	assert projected.clip_width == 60 && projected.clip_height == 80
	assert projected.clip_list.items[0].transform == [f64(2), 0, 0, 2, 14, 16]!
	assert command.transform == [f64(1), 0, 0, 1, 10, 20]!
	assert command.clip_x == 5 && command.clip_width == 30
	assert command.clip_list.items[0].transform == [f64(1), 0, 0, 1, 7, 8]!
}

fn test_zoom_scales_inner_scrolling_and_viewport_wheel_coordinates() {
	mut owner := page.Page.create(1)!
	mut document := parse_browser_navigation_document_with_scripting('<!doctype html><style>
		html,body{margin:0}#scroller{width:200px;height:100px;overflow:auto}
		#inner{height:500px}#rest{height:1000px}</style>
		<div id="scroller"><div id="inner"></div></div><div id="rest"></div>',
		dom.url_about_blank(), none, none, unsafe { &dom.Page(owner) }, 0, false)
	mut app := BrowserApp{ document: document, page_model: owner, page_zoom: 2 }
	defer {
		app.release_paint_commands()
		layout.release_paint_tree(app.paint_tree_storage)
		document.finalize()
	}
	app.relayout(800, 600 + app.chrome_height())
	scroller := document.get_element_by_id('scroller')?
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{100, 100}, page.PixelPoint{},
		0, 0, 0, 0, 40, false) == .handled
	metadata := owner.event_handler.last_wheel_event()?
	assert metadata.visual_viewport_position == page.PixelPoint{50, 50}
	assert metadata.delta_y == 20
	assert scroller.el_scroll_offset().y() == 20
	assert app.scroll_y == 0
	assert app.handle_wheel_at_viewport_point(page.PixelPoint{100, 300}, page.PixelPoint{},
		0, 0, 0, 0, 40, false) == .handled
	assert app.scroll_y == 40 && document.viewport_rect().y == 20
	assert scroller.el_scroll_offset().y() == 20
}
