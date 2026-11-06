module main

import devtools
import dom
import gg
import platform
import time
import ui2

// The docked Elements panel. Its state and UI live in devtools/; this file
// connects them to the tab's document, input, chrome and viewport.

fn (app &BrowserApp) devtools_panel() ?&devtools.DevTools {
	if app.browser_ui_ == unsafe { nil } || app.browser_ui_.devtools_panel == unsafe { nil } {
		return none
	}
	return app.browser_ui_.devtools_panel
}

fn (app &BrowserApp) devtools_open() bool {
	tools := app.devtools_panel() or { return false }
	return tools.open
}

// devtools_height is the panel's share of the window, between the document
// viewport and the status bar. The viewport follows it through chrome_height().
fn (app &BrowserApp) devtools_height() int {
	tools := app.devtools_panel() or { return 0 }
	if !tools.open {
		return 0
	}
	if app.browser_chrome.height <= 0 {
		return int(tools.height)
	}
	available := f64(app.browser_chrome.height) - f64(app.page_top()) - status_bar_height
	return int(devtools.pane_height(tools.height, available))
}

fn (app &BrowserApp) devtools_top() f32 {
	if app.browser_chrome.height > 0 {
		return f32(app.browser_chrome.height) - f32(status_bar_height) - f32(app.devtools_height())
	}
	return app.page_top() + f32(app.viewport_height)
}

fn (mut app BrowserApp) ensure_devtools() &devtools.DevTools {
	mut state := app.browser_ui()
	if state.devtools_panel == unsafe { nil } {
		// Start with 40% of the space below the toolbar, near Chrome's docked
		// default. Later resizes persist for the tab.
		mut height := devtools.default_height
		if app.browser_chrome.height > 0 {
			available := f64(app.browser_chrome.height) - f64(app.page_top()) - status_bar_height
			height = devtools.pane_height(f64(int(available * 0.4)), available)
		}
		persistent := platform.enter_persistent()
		state.devtools_panel = &devtools.DevTools{
			height: height
		}
		platform.leave_persistent(persistent)
	}
	return state.devtools_panel
}

// sync_devtools rebuilds the rows from the live document, first discarding
// state that belonged to a previous document.
fn (app &BrowserApp) sync_devtools() {
	mut tools := app.devtools_panel() or { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	tools.sync(app.document, app.navigation_generation)
	tools.rebuild(app.document)
}

fn (mut app BrowserApp) show_devtools(picking bool) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut tools := app.ensure_devtools()
	opening := !tools.open
	tools.open = true
	tools.picking = picking
	tools.set_picked(none)
	app.sync_devtools()
	if opening {
		tools.reveal = true
		app.devtools_layout_changed()
	} else {
		app.refresh_devtools()
	}
	app.update_devtools_highlight()
}

fn (mut app BrowserApp) close_devtools() {
	mut tools := app.devtools_panel() or { return }
	if !tools.open {
		return
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	focused := ui2.focused_id()
	if focused.starts_with('devtools-') {
		ui2.blur_embedded_textbox()
	}
	tools.open = false
	tools.picking = false
	tools.hovered = 0
	tools.set_picked(none)
	tools.focused = false
	tools.editor = none
	tools.version++
	app.update_devtools_highlight()
	app.devtools_layout_changed()
}

fn (mut app BrowserApp) toggle_devtools() {
	if app.devtools_open() {
		app.close_devtools()
	} else {
		app.show_devtools(false)
	}
}

// start_devtools_picker opens the panel in element-picking mode, or stops a
// pick in progress, like Chrome's Cmd+Shift+C.
fn (mut app BrowserApp) start_devtools_picker() {
	mut tools := app.devtools_panel() or {
		app.show_devtools(true)
		return
	}
	if tools.open && tools.picking {
		tools.picking = false
		tools.set_picked(none)
		tools.version++
		app.update_devtools_highlight()
		app.refresh_devtools()
		return
	}
	app.show_devtools(true)
}

// inspect_devtools_node opens the panel with `node` revealed and selected.
fn (mut app BrowserApp) inspect_devtools_node(node &dom.Node) {
	app.show_devtools(false)
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut tools := app.devtools_panel() or { return }
	tools.reveal_node(node)
	tools.focused = true
	app.refresh_devtools()
}

// The document viewport changes height whenever the panel opens, closes or
// resizes; a cached full-window image no longer matches it.
fn (mut app BrowserApp) devtools_layout_changed() {
	$if macos {
		if app.snapshot_visible { C.native_hide_cached_snapshot() }
	}
	app.snapshot_visible = false
	app.snapshot_hold = false
	app.snapshot_hold_until = 0
	app.snapshot_cached = false
	app.refresh_devtools()
}

fn (mut app BrowserApp) refresh_devtools() {
	mut state := app.browser_ui()
	state.version++
	app.refresh_browser_ui()
	app.finish_devtools_render()
}

// finish_devtools_render applies requests that need the rendered controls:
// scrolling the selection into view and focusing an editor.
fn (mut app BrowserApp) finish_devtools_render() {
	mut tools := app.devtools_panel() or { return }
	if !tools.open {
		return
	}
	app.sync_devtools()
	if tools.reveal {
		index := tools.row_index(tools.selected)
		if index >= 0 {
			row := tools.rows[index]
			ui2.scroll_to_rect(devtools.tree_id, f64(row.depth) * devtools.indent_width,
				tools.row_top(index) - devtools.row_height, 240, tools.row_extent(row) +
				devtools.row_height * 2)
		}
		tools.reveal = false
	}
	mut state := app.browser_ui()
	if state.devtools_focus != '' {
		ui2.focus(state.devtools_focus)
		if ui2.focused_id() == state.devtools_focus {
			state.devtools_focus = ''
		}
	}
}

fn (mut app BrowserApp) focus_devtools_control(id string) {
	persistent := platform.enter_persistent()
	mut state := app.browser_ui()
	state.devtools_focus = id.clone()
	platform.leave_persistent(persistent)
}

// update_devtools_highlight draws the box-model overlay for the node under the
// pointer in the tree, or under the picker in the page.
fn (mut app BrowserApp) update_devtools_highlight() {
	if app.document == unsafe { nil } {
		return
	}
	mut target := ?&dom.Node(none)
	if tools := app.devtools_panel() {
		target = tools.highlight()
	}
	current := app.document.get_highlighted_node()
	if voidptr(current or { unsafe { nil } }) == voidptr(target or { unsafe { nil } }) {
		return
	}
	mut document := unsafe { &dom.Document(app.document) }
	document.set_highlighted_node(target, none)
	app.paint_commands_pending = true
	app.synchronize_javascript_task_paint(false)
	request_browser_frame()
}

// Edits mutate the document directly; relayout and repaint as script would.
fn (mut app BrowserApp) devtools_dom_changed() {
	app.sync_devtools()
	app.update_devtools_highlight()
	app.synchronize_javascript_task_paint(false)
	request_browser_frame()
}

// devtools_state_version changes whenever the panel must render again,
// including DOM mutations made by page script while it is open.
fn (app &BrowserApp) devtools_state_version() u64 {
	tools := app.devtools_panel() or { return 0 }
	if !tools.open {
		return 0
	}
	mut version := tools.version * 1000003 + u64(app.devtools_height())
	if app.document != unsafe { nil } {
		version += app.document.dom_tree_version() * 31 + app.document.attribute_version() * 17 +
			app.document.character_data_version()
	}
	return version
}

fn (app &BrowserApp) devtools_elements(width int, height int) []ui2.Element {
	if !app.devtools_open() {
		return []ui2.Element{}
	}
	app.sync_devtools()
	tools := app.devtools_panel() or { return []ui2.Element{} }
	pane_height := f64(app.devtools_height())
	return [tools.elements(ui2.rect(0, f64(height) - status_bar_height - pane_height, f64(width),
		pane_height))]
}

fn devtools_editor_kind(node &dom.Node) ?devtools.EditorKind {
	if node.is_element() {
		return .html
	}
	if node.is_text() || node.is_comment() {
		return .text
	}
	return none
}

fn (mut app BrowserApp) devtools_action(value string) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	action := devtools.parse_action(value) or { return }
	mut tools := app.devtools_panel() or { return }
	if !tools.open {
		return
	}
	app.sync_devtools()
	id := action.node
	match action.verb {
		'close' {
			app.close_devtools()
			return
		}
		'pick' {
			tools.picking = !tools.picking
			tools.set_picked(none)
			tools.version++
			app.update_devtools_highlight()
		}
		'select' {
			app.blur_address_bar()
			if ui2.focused_id() != '' {
				ui2.blur_embedded_textbox()
			}
			tools.focused = true
			double := tools.click(id, time.sys_mono_now())
			if double && tools.selected == id {
				if node := tools.node(id) {
					if kind := devtools_editor_kind(node) {
						if tools.begin_edit(id, kind) {
							app.focus_devtools_control(devtools.editor_id)
						}
					}
				}
			} else {
				tools.select(id)
			}
		}
		'toggle' {
			tools.focused = true
			tools.toggle(id)
		}
		'expand-all' {
			tools.expand_all(id)
		}
		'collapse-all' {
			tools.collapse_all(id)
		}
		'edit-html', 'edit-text' {
			if tools.begin_edit(id, if action.verb == 'edit-html' { .html } else { .text }) {
				app.focus_devtools_control(devtools.editor_id)
			}
		}
		'editor-apply' {
			app.apply_devtools_editor(ui2.text(devtools.editor_id))
			return
		}
		'editor-cancel' {
			tools.cancel_edit()
		}
		'delete' {
			app.delete_devtools_node(id)
			return
		}
		'copy' {
			if node := tools.node(id) {
				ui2.copy_embedded_text(devtools.copy_text(node))
			}
		}
		'add-attribute' {
			tools.select(id)
			app.focus_devtools_control(devtools.new_attribute_name_id(id))
		}
		'attr-set' {
			node := tools.node(id) or { return }
			element := node.as_element() or { return }
			index := devtools.attributes(element).map(it.name).index(action.arg)
			if index >= 0 {
				app.set_devtools_attribute(id, action.arg, ui2.text(devtools.attribute_value_id(id,
					index)))
			}
			return
		}
		'attr-remove' {
			app.remove_devtools_attribute(id, action.arg)
			return
		}
		'attr-add' {
			name_id := devtools.new_attribute_name_id(id)
			name := ui2.text(name_id)
			if name.trim_space() != '' && app.set_devtools_attribute(id, name,
				ui2.text(devtools.new_attribute_value_id(id))) {
				ui2.set_text(name_id, '')
				ui2.set_text(devtools.new_attribute_value_id(id), '')
			}
			app.focus_devtools_control(name_id)
			app.finish_devtools_render()
			return
		}
		else {
			return
		}
	}
	app.refresh_devtools()
}

// The edits below take their text from the caller rather than UI2 fields,
// then relayout and render the panel.

fn (mut app BrowserApp) set_devtools_attribute(id i64, name string, value string) bool {
	mut tools := app.devtools_panel() or { return false }
	app.sync_devtools()
	changed := tools.set_attribute(id, name, value)
	app.finish_devtools_edit(changed)
	return changed
}

fn (mut app BrowserApp) remove_devtools_attribute(id i64, name string) bool {
	mut tools := app.devtools_panel() or { return false }
	app.sync_devtools()
	changed := tools.remove_attribute(id, name)
	app.finish_devtools_edit(changed)
	return changed
}

fn (mut app BrowserApp) apply_devtools_editor(text string) bool {
	mut tools := app.devtools_panel() or { return false }
	app.sync_devtools()
	changed := tools.apply_edit(text)
	app.finish_devtools_edit(changed)
	return changed
}

fn (mut app BrowserApp) delete_devtools_node(id i64) bool {
	mut tools := app.devtools_panel() or { return false }
	app.sync_devtools()
	changed := tools.delete(id)
	app.finish_devtools_edit(changed)
	return changed
}

fn (mut app BrowserApp) finish_devtools_edit(changed bool) {
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	if changed {
		app.devtools_dom_changed()
	}
	app.refresh_devtools()
}

// resize_devtools follows a drag on the panel's top edge, in window coordinates.
fn (mut app BrowserApp) resize_devtools(y f64) {
	mut tools := app.devtools_panel() or { return }
	if !tools.open || app.browser_chrome.height <= 0 {
		return
	}
	window := f64(app.browser_chrome.height)
	height := devtools.pane_height(window - status_bar_height - y, window - f64(app.page_top()) - status_bar_height)
	if int(height) == int(tools.height) {
		return
	}
	tools.height = height
	app.devtools_layout_changed()
}

// handle_devtools_key runs before browser shortcuts. Navigation keys reach the
// tree only after it was clicked and while no text control has focus.
fn (mut app BrowserApp) handle_devtools_key(event ui2.KeyEvent) bool {
	mut tools := app.devtools_panel() or { return false }
	if !tools.open {
		return false
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	focused := ui2.focused_id()
	command := $if macos { event.cmd } $else { event.ctrl }
	if focused == devtools.editor_id {
		if event.code == .escape {
			tools.cancel_edit()
			ui2.blur_embedded_textbox()
			app.refresh_devtools()
			return true
		}
		if event.code in [.enter, .kp_enter] && command {
			app.devtools_action(devtools.action('editor-apply', 0, ''))
			return true
		}
		return false
	}
	if event.code == .escape && tools.picking {
		tools.picking = false
		tools.set_picked(none)
		tools.version++
		app.update_devtools_highlight()
		app.refresh_devtools()
		return true
	}
	if focused.starts_with('devtools-attr-') {
		if event.code == .escape {
			ui2.blur_embedded_textbox()
			tools.version++
			app.refresh_devtools()
			return true
		}
		return false
	}
	if !tools.focused || focused != '' || event.cmd || event.ctrl || event.alt {
		return false
	}
	app.sync_devtools()
	match event.code {
		.up, .down, .left, .right, .home, .end {
			tools.key(event.code.name())
		}
		.backspace, .delete {
			app.delete_devtools_node(tools.selected)
			return true
		}
		.enter, .kp_enter, .f2 {
			node := tools.selected_node() or { return true }
			kind := devtools_editor_kind(node) or { return true }
			if tools.begin_edit(tools.selected, kind) {
				app.focus_devtools_control(devtools.editor_id)
			}
		}
		.escape {
			tools.focused = false
		}
		else {
			return false
		}
	}
	app.refresh_devtools()
	return true
}

// handle_devtools_page_event gives the element picker the page's pointer
// input and keeps pointer input over the panel away from the document.
fn (mut app BrowserApp) handle_devtools_page_event(event &gg.Event) bool {
	mut tools := app.devtools_panel() or { return false }
	if !tools.open || event.typ !in [.mouse_move, .mouse_down, .mouse_up, .mouse_scroll, .mouse_leave] {
		return false
	}
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	top := app.devtools_top()
	in_pane := event.typ != .mouse_leave && event.mouse_y >= top
		&& event.mouse_y < top + f32(app.devtools_height())
	match event.typ {
		.mouse_move {
			if in_pane {
				if !tools.pointer_in_pane {
					// The document no longer has the pointer.
					tools.pointer_in_pane = true
					app.hovered_link = ''
					if app.page_model != unsafe { nil } {
						app.page_model.event_handler.handle_mouseleave()
					}
				}
				app.hover_devtools_tree(f64(event.mouse_x), f64(event.mouse_y - top))
				return true
			}
			tools.pointer_in_pane = false
			app.hover_devtools_tree(-1, -1)
			if tools.picking {
				mut target := ?&dom.Node(none)
				if element := app.element_at_window_point(event.mouse_x, event.mouse_y) {
					target = element.as_node()
				}
				if tools.set_picked(target) {
					app.update_devtools_highlight()
				}
				return true
			}
		}
		.mouse_down {
			if in_pane {
				return true
			}
			if tools.picking && event.mouse_y >= app.page_top() {
				tools.suppress_pointer_up = true
				app.suppress_next_click_for_chrome = true
				if event.mouse_button == .left {
					if element := app.element_at_window_point(event.mouse_x, event.mouse_y) {
						tools.picking = false
						tools.set_picked(none)
						app.inspect_devtools_node(element.as_node())
						app.update_devtools_highlight()
						return true
					}
				}
				return true
			}
			if event.mouse_y >= app.page_top() {
				tools.focused = false
			}
		}
		.mouse_up {
			if tools.suppress_pointer_up {
				tools.suppress_pointer_up = false
				return true
			}
			if in_pane {
				return true
			}
		}
		.mouse_scroll {
			return in_pane
		}
		.mouse_leave {
			tools.pointer_in_pane = false
			if tools.hovered != 0 || tools.picked != 0 {
				tools.hovered = 0
				tools.set_picked(none)
				tools.version++
				app.update_devtools_highlight()
				app.refresh_devtools()
			}
		}
		else {}
	}
	return false
}

// hover_devtools_tree maps a pointer position in the panel to a tree row.
// Negative coordinates clear the hover.
fn (mut app BrowserApp) hover_devtools_tree(x f64, y f64) {
	mut tools := app.devtools_panel() or { return }
	l := devtools.layout(f64(app.browser_chrome.width), f64(app.devtools_height()))
	mut hovered := i64(0)
	if x >= 0 && x < l.tree_width && y >= devtools.toolbar_height
		&& y < devtools.toolbar_height + l.tree_height {
		index := tools.row_at(y - devtools.toolbar_height + ui2.scroll_offset(devtools.tree_id))
		if index >= 0 && tools.rows[index].kind != .editor {
			hovered = tools.rows[index].node
		}
	}
	if hovered == tools.hovered {
		return
	}
	tools.hovered = hovered
	tools.version++
	app.update_devtools_highlight()
	app.refresh_devtools()
}

// Right-clicking the page remembers its element for the context menu's Inspect row.
fn (mut app BrowserApp) remember_devtools_inspect_target(x f32, y f32) {
	mut state := app.browser_ui()
	state.inspect_node = unsafe { nil }
	element := app.element_at_window_point(x, y) or { return }
	state.inspect_node = element.as_node()
	state.inspect_document = voidptr(app.document)
	state.inspect_generation = app.navigation_generation
}

fn (mut app BrowserApp) inspect_remembered_devtools_target(node &dom.Node, document voidptr, generation int) {
	if node != unsafe { nil } && document == voidptr(app.document)
		&& generation == app.navigation_generation {
		app.inspect_devtools_node(node)
	} else {
		app.show_devtools(false)
	}
}
