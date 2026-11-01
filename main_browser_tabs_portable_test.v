module main

import gg

fn test_shared_tab_declaration_reflects_selection_and_drag_without_moving_owners() {
	mut app := &BrowserApp{ ctx: &gg.Context{} }
	app.initialize_browser_tabs()
	second := &BrowserApp{ ctx: app.ctx }
	app.tabs.pages << second
	app.tabs.selected = 1
	strip := app.browser_tab_strip(app.browser_chrome_state(800, 600))
	assert strip.id == 'tab-strip'
	assert strip.children[3].id == 'tab-0'
	assert strip.children[3].accessibility_value == ''
	assert strip.children[4].accessibility_value == 'selected'
	app.tabs.drag = BrowserTabDrag{ page: app, first: 0, end: 2, width: 184, offset: 35, x: 220, target: 1, moving: true }
	preview := app.browser_tab_strip(app.browser_chrome_state(800, 600))
	assert preview.children[3].id == 'tab-1'
	assert preview.children[3].frame.x == 62
	assert preview.children[4].id == 'tab-0'
	assert preview.children[4].frame.x == 185
	assert voidptr(app.tabs.pages[0]) == voidptr(app)
	assert voidptr(app.tabs.pages[1]) == voidptr(second)
}
