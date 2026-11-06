module main

import devtools
import dom
import gg
import page
import ui2

fn devtools_test_app() &BrowserApp {
	return devtools_test_app_with('<!doctype html><style>body{margin:0}div,section{display:block;width:300px;height:40px}</style><body><main id="app" class="shell"><div id="target" title="Target">Target text</div><div id="other">Other</div></main><!-- end --></body>')
}

fn devtools_test_app_with(markup string) &BrowserApp {
	owner := page.Page.create(1) or { panic(err) }
	mut app := &BrowserApp{
		page_model:      owner
		script_policy:   .disabled
		viewport_width:  800
		viewport_height: 516
	}
	app.install_loaded_page(LoadedPage{
		url:          'https://devtools.example/'
		markup:       markup
		content_type: 'text/html'
	}, false)
	return app
}

fn devtools_test_point(app &BrowserApp, id string) (f32, f32) {
	rect := app.document.get_element_by_id(id) or { panic('missing ${id}') }.get_bounding_client_rect()
	assert rect.width > 0 && rect.height > 0, 'missing hit geometry for ${id}'
	return f32((rect.x + rect.width / 2) * app.page_zoom), f32((rect.y + rect.height / 2) * app.page_zoom) +
		app.page_top()
}

fn devtools_test_panel(app &BrowserApp) &devtools.DevTools {
	return app.devtools_panel() or { panic('developer tools were never opened') }
}

fn devtools_test_id(app &BrowserApp, id string) i64 {
	element := app.document.get_element_by_id(id) or { panic('missing ${id}') }
	return devtools.node_id(element.as_node())
}

fn test_auto_open_devtools_launch_switch_follows_chrome() {
	options := parse_launch_options(['--auto-open-devtools-for-tabs', 'page.html']) or { panic(err) }
	assert options.auto_open_devtools
	assert options.source == 'page.html'
	assert !(parse_launch_options(['page.html']) or { panic(err) }).auto_open_devtools
}

fn test_devtools_dock_below_the_document_and_take_viewport_height() {
	mut app := devtools_test_app()
	defer { app.dispose_browser_tab() }
	closed_chrome := app.chrome_height()
	app.relayout(800, 900)
	closed_viewport := app.viewport_height
	app.show_devtools(false)
	assert app.devtools_open()
	assert app.devtools_height() == int(devtools.default_height)
	assert app.chrome_height() == closed_chrome + app.devtools_height()
	app.relayout(800, 900)
	assert app.viewport_height == closed_viewport - app.devtools_height()
	tools := devtools_test_panel(app)
	body := app.document.body() or { panic('missing body') }
	assert tools.selected == devtools.node_id(unsafe { &dom.Node(body) })
	elements := app.devtools_elements(800, 900)
	assert elements.len == 1 && elements[0].id == 'devtools'
	assert elements[0].frame.y == 900 - status_bar_height - devtools.default_height
	// The pointer over the panel never reaches the document.
	panel_y := f32(app.page_top()) + f32(app.viewport_height) + 60
	assert app.element_at_window_point(40, panel_y) == none
	app.handle_event(&gg.Event{ typ: .mouse_move, mouse_x: 40, mouse_y: panel_y })
	assert tools.pointer_in_pane
	app.close_devtools()
	assert !app.devtools_open()
	assert app.chrome_height() == closed_chrome
	assert app.devtools_elements(800, 900).len == 0
	app.relayout(800, 900)
	assert app.viewport_height == closed_viewport
}

fn test_context_menu_inspect_reveals_the_clicked_element() {
	mut app := devtools_test_app()
	defer { app.dispose_browser_tab() }
	x, y := devtools_test_point(app, 'target')
	app.handle_event(&gg.Event{ typ: .mouse_down, mouse_button: .right, mouse_x: x, mouse_y: y })
	app.handle_event(&gg.Event{ typ: .mouse_up, mouse_button: .right, mouse_x: x, mouse_y: y })
	popup := app.browser_ui().popup or { panic('missing page context menu') }
	assert popup.rows.map(it.id) == ['inspect']
	app.browser_popup_action(popup.action(0))
	assert app.browser_ui().popup == none
	assert app.devtools_open()
	tools := devtools_test_panel(app)
	assert tools.selected == devtools_test_id(app, 'target')
	assert tools.row_index(tools.selected) >= 0
	assert tools.breadcrumbs().map(devtools.node_label(it)) == ['html', 'body', 'main#app.shell',
		'div#target']
	assert app.document.get_highlighted_node() == none
}

fn test_picker_highlights_and_selects_without_activating_the_page() {
	mut app := devtools_test_app()
	defer { app.dispose_browser_tab() }
	app.start_devtools_picker()
	mut tools := devtools_test_panel(app)
	assert tools.open && tools.picking
	x, y := devtools_test_point(app, 'other')
	app.handle_event(&gg.Event{ typ: .mouse_move, mouse_x: x, mouse_y: y })
	other := app.document.get_element_by_id('other') or { panic('missing other') }
	highlighted := app.document.get_highlighted_node() or { panic('picker did not highlight') }
	assert voidptr(highlighted) == voidptr(other.as_node())
	app.handle_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: x, mouse_y: y })
	assert !tools.picking
	assert tools.selected == devtools.node_id(other.as_node())
	assert app.document.get_highlighted_node() == none
	assert app.suppress_next_click_for_chrome
	assert app.platform_pointer_buttons == 0
	app.handle_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: x, mouse_y: y })
	assert !tools.suppress_pointer_up
	assert app.platform_pointer_buttons == 0
	// Cmd+Shift+C again, or Escape, stops a pick in progress.
	app.start_devtools_picker()
	assert tools.picking
	app.start_devtools_picker()
	assert !tools.picking && tools.open
	app.start_devtools_picker()
	assert app.handle_devtools_key(ui2.KeyEvent{ code: .escape })
	assert !tools.picking
}

fn test_devtools_edits_change_the_rendered_document() {
	mut app := devtools_test_app()
	defer { app.dispose_browser_tab() }
	target := app.document.get_element_by_id('target') or { panic('missing target') }
	app.inspect_devtools_node(target.as_node())
	mut tools := devtools_test_panel(app)
	id := devtools.node_id(target.as_node())
	assert app.set_devtools_attribute(id, 'style', 'height:120px')
	assert target.get_attribute('style') or { '' } == 'height:120px'
	assert target.get_bounding_client_rect().height == 120
	assert app.remove_devtools_attribute(id, 'title')
	assert target.get_attribute('title') == none
	assert tools.begin_edit(id, .html)
	editor := tools.editor or { panic('editor did not open') }
	assert editor.text == '<div id="target" style="height:120px">Target text</div>'
	assert app.apply_devtools_editor('<section id="replaced" style="height:60px">New <b>markup</b></section>')
	assert tools.editor == none
	assert app.document.get_element_by_id('target') == none
	replaced := app.document.get_element_by_id('replaced') or { panic('missing replacement') }
	assert tools.selected == devtools.node_id(replaced.as_node())
	assert replaced.get_bounding_client_rect().height == 60
	assert tools.row_index(tools.selected) >= 0
	// Deleting moves the selection to the next sibling.
	assert app.delete_devtools_node(tools.selected)
	assert app.document.get_element_by_id('replaced') == none
	assert tools.selected == devtools_test_id(app, 'other')
	// Tree keys apply once a row has been clicked and no field has focus.
	app.devtools_action(devtools.action('select', tools.selected, ''))
	assert tools.focused
	assert app.handle_devtools_key(ui2.KeyEvent{ code: .up })
	assert tools.selected == devtools_test_id(app, 'app')
	assert app.handle_devtools_key(ui2.KeyEvent{ code: .left })
	assert !(tools.expanded[tools.selected] or { false })
	assert app.handle_devtools_key(ui2.KeyEvent{ code: .down })
	assert tools.rows[tools.row_index(tools.selected)].kind == .comment
	assert app.handle_devtools_key(ui2.KeyEvent{ code: .backspace })
	assert app.document.body() or { panic('missing body') }.as_node().children.all(!it.is_comment())
	// Clicking the page returns keys to it.
	x, y := devtools_test_point(app, 'other')
	app.handle_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: x, mouse_y: y })
	app.handle_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: x, mouse_y: y })
	assert !tools.focused
	assert !app.handle_devtools_key(ui2.KeyEvent{ code: .up })
}

fn test_navigation_resets_the_inspected_document() {
	mut app := devtools_test_app()
	defer { app.dispose_browser_tab() }
	target := app.document.get_element_by_id('target') or { panic('missing target') }
	app.inspect_devtools_node(target.as_node())
	tools := devtools_test_panel(app)
	stale := tools.selected
	app.navigation_generation++
	app.install_loaded_page(LoadedPage{
		url:          'https://devtools.example/next'
		markup:       '<!doctype html><body><p id="next">Next</p></body>'
		content_type: 'text/html'
	}, true)
	elements := app.devtools_elements(800, 900)
	assert elements.len == 1
	assert tools.node(stale) == none
	body := app.document.body() or { panic('missing body') }
	assert tools.selected == devtools.node_id(unsafe { &dom.Node(body) })
	assert tools.rows.any(it.node == devtools_test_id(app, 'next'))
}

fn devtools_test_rule(tools &devtools.DevTools, selector string) int {
	for index, rule in tools.styles.rules {
		if rule.selector == selector {
			return index
		}
	}
	panic('no rule ${selector} in ${tools.styles.rules.map(it.selector)}')
}

fn devtools_test_overridden(tools &devtools.DevTools, selector string, name string) bool {
	rule := tools.styles.rules[devtools_test_rule(tools, selector)]
	for declaration in rule.declarations {
		if declaration.name == name {
			return declaration.overridden
		}
	}
	panic('no ${name} in ${selector}')
}

fn test_styles_tab_lists_and_edits_matched_rules() {
	mut app := devtools_test_app_with('<!doctype html><style>body{margin:0} .card{padding:4px;color:blue} #target.card{color:green} div{margin:0;width:200px}</style><body><div id="target" class="card" style="height:40px">Target</div></body>')
	defer { app.dispose_browser_tab() }
	target := app.document.get_element_by_id('target') or { panic('missing target') }
	id := devtools.node_id(target.as_node())
	app.inspect_devtools_node(target.as_node())
	_ = app.devtools_elements(800, 900)
	mut tools := devtools_test_panel(app)
	assert tools.sidebar == .styles
	assert tools.styles.node == id
	selectors := tools.styles.rules.map(it.selector)
	assert selectors[..4] == ['element.style', '#target.card', '.card', 'div']
	assert tools.styles.rules[0].declarations.map('${it.name}: ${it.value}') == ['height: 40px']
	assert tools.styles.rules[1].source == '<style>'
	assert !devtools_test_overridden(tools, '#target.card', 'color')
	assert devtools_test_overridden(tools, '.card', 'color')
	assert !devtools_test_overridden(tools, '.card', 'padding')
	ua_index := tools.styles.rules.len - 1
	assert tools.styles.rules[ua_index].origin == .user_agent
	assert tools.styles.rules.filter(it.origin == .user_agent).any(it.declarations.any(it.name == 'display'))
	// Author rules change through the CSSOM and relayout the page.
	assert app.set_devtools_style(id, devtools_test_rule(tools, '.card'), 'padding', '10px')
	assert target.get_bounding_client_rect().height == 60
	assert tools.styles.key == 0 || tools.styles.rules.len > 0
	_ = app.devtools_elements(800, 900)
	card := tools.styles.rules[devtools_test_rule(tools, '.card')]
	assert card.declarations.any(it.name == 'padding' && it.value == '10px')
	// The inline style edits the style attribute.
	assert app.set_devtools_style(id, 0, 'height', '80px')
	assert app.set_devtools_style(id, 0, 'outline', '1px solid red !important')
	assert target.get_attribute('style') or { '' } == 'height: 80px; outline: 1px solid red !important;'
	assert target.get_bounding_client_rect().height == 100
	assert app.set_devtools_style(id, 0, 'outline', '')
	assert target.get_attribute('style') or { '' } == 'height: 80px;'
	_ = app.devtools_elements(800, 900)
	assert !app.set_devtools_style(id, tools.styles.rules.len - 1, 'display', 'none')
	// The Computed tab shows the box model and resolved values.
	app.devtools_action(devtools.action('sidebar', 0, 'computed'))
	assert tools.sidebar == .computed
	_ = app.devtools_elements(800, 900)
	box := tools.styles.box or { panic('missing box model') }
	assert box.padding == [10.0, 10, 10, 10]
	assert box.width == 200 && box.height == 80
	assert tools.styles.computed.any(it.name == 'color' && it.value == 'rgb(0, 128, 0)')
	names := tools.styles.computed.map(it.name)
	standard := names.filter(!it.starts_with('-'))
	assert standard == standard.sorted()
	assert names[..standard.len] == standard
}
