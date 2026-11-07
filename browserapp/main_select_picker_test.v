module main

import dom
import gg
import html
import page
import browserui

$if macos {
	#include "@VMODROOT/native_address_bar_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_close(window voidptr)
}

fn select_picker_test_app(markup string) &BrowserApp {
	owner := page.Page.create(1) or { panic(err) }
	mut app := &BrowserApp{
		page_model:      owner
		ctx:             &gg.Context{}
		script_policy:   .enabled
		viewport_width:  800
		viewport_height: 516
	}
	app.install_loaded_page(LoadedPage{
		url:          'https://boards.4chan.org/pol/catalog'
		content_type: 'text/html'
		markup:       '<!doctype html><style>select{width:180px;height:30px}</style>' + markup
	}, true)
	assert app.js_messages == [], app.js_messages.str()
	return app
}

fn select_picker_test_click(mut app BrowserApp, id string) {
	select_picker_test_click_at(mut app, id, 0.5)
}

fn select_picker_test_click_at(mut app BrowserApp, id string, inline_fraction f64) {
	assert app.navigation_work_depth == 0
	assert app.document.is_fully_active()
	element := app.document.get_element_by_id(id) or { panic('missing ${id}') }
	rect := element.get_bounding_client_rect()
	assert rect.width > 0 && rect.height > 0
	x := f32((rect.x + rect.width * inline_fraction) * app.page_zoom)
	y := f32((rect.y + rect.height / 2) * app.page_zoom) + app.page_top()
	app.handle_event(&gg.Event{ typ: .mouse_down, mouse_button: .left, mouse_x: x, mouse_y: y })
	app.handle_event(&gg.Event{ typ: .mouse_up, mouse_button: .left, mouse_x: x, mouse_y: y })
	if popup := app.browser_ui().popup {
		assert app.page_model.event_handler.last_click_allowed()
		// Compact JavaScript replay consumes the click receipt before the async popup.
		assert app.page_model.event_handler.last_click_target_node() == none
		assert app.browser_ui().select_document == app.document.unique_id()
		assert app.browser_ui().select_node != unsafe { nil }
		mut state := unsafe { select_ui_test_state }
		state.count++
		state.popup = popup
		if state.choice == -2 { return }
		app.browser_popup_action(if state.choice < 0 {
			'browser-menu:${popup.token}:dismiss'
		} else {
			popup.action(state.choice)
		})
	}
}

fn select_picker_test_drain(app &BrowserApp) {
	document := app.document
	mut queue := html.main_thread_event_loop().task_queue()
	for _ in 0 .. 8 {
		task := queue.take_first_runnable_matching(fn [document] (task &html.Task) bool {
			return task.source() == .user_interaction && voidptr(task.document() or { return false }) == voidptr(document)
		}) or { return }
		task.execute()
	}
	assert false, 'select notifications did not drain'
}

fn test_catalog_select_menu_changes_the_live_value_and_runs_sort_listeners() {
	$if macos {
		window := select_ui_test_begin()
		defer { select_ui_test_end(window) }
		mut app := select_picker_test_app(r'<div id="controls"><select id="order-ctrl" size="1" oninput="events.push(&quot;inline:&quot;+event.target.value)" onchange="events.push(&quot;replaced-handler&quot;)"><option value="alt">Bump order</option><option value="absdate">Creation date</option><option value="date">Last reply</option><option value="r">Reply count</option></select></div><p id="sorted"></p><script>
const Ae=document.getElementById("order-ctrl");
var events=[];
function ce(value){document.getElementById("sorted").textContent=value;}
function ue(){events.push("change:"+Ae.value+":"+Ae.selectedIndex);ce(Ae.options[Ae.selectedIndex].value);}
Ae.addEventListener("change",ue);
Ae.addEventListener("input",function(e){events.push("input:"+e.target.value);});
Ae.onchange=function(e){events.push("property:"+e.target.value);};
document.getElementById("controls").addEventListener("change",function(e){events.push("parent:"+e.target.value+":"+e.bubbles+":"+e.cancelable);});
document.addEventListener("change",function(e){events.push("document:"+e.target.id);});
</script>')
		defer { app.dispose_browser_tab() }
		control := app.document.get_element_by_id('order-ctrl')?
		app_handle := voidptr(app)
		for event_name in ['input', 'change'] {
			unsafe { &dom.EventTarget(control) }.add_event_listener_without_options(event_name,
				dom.IDLEventListener.create(&dom.CallbackType{
					handle_event: fn [app_handle, event_name] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
						mut app := unsafe { &BrowserApp(app_handle) }
						app.js_runtime.evaluate_host('events.push("native-${event_name}")') or { panic(err) }
						return dom.js_undefined()
					}
				}))
		}
		select_ui_test_choose(3)
		select_picker_test_click(mut app, 'order-ctrl')
		assert select_ui_test_count() == 1
		assert select_ui_test_length() == 4
		assert select_ui_test_item(0, c'Bump order', 10, 1, 0, 1) == 1
		assert select_ui_test_item(3, c'Reply count', 11, 1, 0, 0) == 1
		assert html.html_select_element_value(unsafe { &dom.HTMLSelectElement(control) }) == 'r'
		model := html.HTMLSelectElementModel.create(unsafe { &dom.HTMLSelectElement(control) })
		assert !model.is_open()
		select_picker_test_drain(app)
		assert app.js_runtime.evaluate_host('document.getElementById("sorted").textContent')! == 'r'
		// Page listeners register before the test's native listeners; both fire once.
		observed_events := app.js_runtime.evaluate_host('events.join("|")')!
		assert observed_events == 'input:r|native-input|inline:r|change:r:3|native-change|property:r|parent:r:true:false|document:order-ctrl', observed_events
		select_ui_test_choose(1)
		// The chevron must target the host just like the selected label.
		select_picker_test_click_at(mut app, 'order-ctrl', 0.95)
		assert select_ui_test_count() == 2
		assert select_ui_test_item(3, c'Reply count', 11, 1, 0, 1) == 1
		select_picker_test_drain(app)
		assert app.js_runtime.evaluate_host('document.getElementById("sorted").textContent')! == 'absdate'
		assert app.js_messages == [], app.js_messages.str()
	}
}

fn test_select_menu_cancel_disabled_and_cancelled_clicks_preserve_selection() {
	$if macos {
		window := select_ui_test_begin()
		defer { select_ui_test_end(window) }
		mut app := select_picker_test_app(r'<select id="sort"><option value="alt">Bump order</option><option value="r">Reply count</option></select><select id="disabled" disabled><option>Disabled</option></select><select id="cancelled" onclick="return false"><option>Cancelled</option></select><script>var changes=0;document.getElementById("sort").addEventListener("change",()=>changes++);</script>')
		defer { app.dispose_browser_tab() }
		select_picker_test_click(mut app, 'sort')
		assert select_ui_test_count() == 1
		select_picker_test_drain(app)
		assert app.js_runtime.evaluate_host('changes+":"+document.getElementById("sort").value')! == '0:alt'
		select_picker_test_click(mut app, 'disabled')
		select_picker_test_click(mut app, 'cancelled')
		assert select_ui_test_count() == 1
		select_ui_test_choose(1)
		select_picker_test_click(mut app, 'sort')
		assert select_ui_test_count() == 2
		select_picker_test_drain(app)
		assert app.js_runtime.evaluate_host('changes+":"+document.getElementById("sort").value')! == '1:r'
	}
}

fn test_select_menu_preserves_groups_disabled_options_separators_and_zoom_geometry() {
	$if macos {
		window := select_ui_test_begin()
		defer { select_ui_test_end(window) }
		mut app := select_picker_test_app('<select id="sort"><option>First</option><option hidden>Hidden</option><optgroup label="Dates"><option disabled>Disabled</option><option value="date">Last reply</option></optgroup><hr><optgroup label="Unavailable" disabled><option>Unavailable option</option></optgroup></select>')
		defer { app.dispose_browser_tab() }
		app.page_zoom = 1.5
		app.relayout(800, 600)
		select_ui_test_choose(3)
		select_picker_test_click(mut app, 'sort')
		assert select_ui_test_count() == 1
		assert select_ui_test_length() == 7
		assert select_ui_test_item(1, c'Dates', 5, 0, 0, 0) == 1
		assert select_ui_test_item(2, c'Disabled', 8, 0, 1, 0) == 1
		assert select_ui_test_item(3, c'Last reply', 10, 1, 1, 0) == 1
		assert select_ui_test_separator(4) == 1
		assert select_ui_test_item(6, c'Unavailable option', 18, 0, 1, 0) == 1
		control := app.document.get_element_by_id('sort')?
		rect := control.get_bounding_client_rect()
		assert select_ui_test_geometry(window, rect.x * app.page_zoom,
			(rect.y + rect.height) * app.page_zoom + app.page_top(), rect.width * app.page_zoom) == 1
		select_picker_test_drain(app)
		assert html.html_select_element_selected_index(unsafe { &dom.HTMLSelectElement(control) }) == 3
		assert app.js_runtime.evaluate_host('document.getElementById("sort").value')! == 'date'
	}
}

struct SelectUITestState {
mut:
	choice int = -1
	count  int
	popup  browserui.Popup
}

const select_ui_test_state = &SelectUITestState{}

fn select_ui_test_begin() voidptr {
	mut state := unsafe { select_ui_test_state }
	state.count = 0
	state.choice = -1
	return C.native_test_address_window()
}

fn select_ui_test_end(window voidptr) { C.native_test_address_close(window) }

fn select_ui_test_choose(index int) {
	mut state := unsafe { select_ui_test_state }
	state.choice = index
}

fn select_ui_test_count() int { return select_ui_test_state.count }

fn select_ui_test_length() int { return select_ui_test_state.popup.rows.len }

fn select_ui_test_separator(index int) int {
	return int(select_ui_test_state.popup.rows[index].separator)
}

fn select_ui_test_item(index int, bytes &u8, length int, enabled int, grouped int, checked int) int {
	row := select_ui_test_state.popup.rows[index]
	text := unsafe { tos(bytes, length) }
	return int(row.text == text && int(row.enabled && !row.group) == enabled && row.indent == grouped && int(row.checked) == checked)
}

fn select_ui_test_geometry(_ voidptr, x f64, y f64, width f64) int {
	popup := select_ui_test_state.popup
	return int(popup.x == x && popup.y == y && popup.width == width)
}

fn test_async_select_rejects_old_actions_and_dismisses_on_navigation() {
    $if macos {
        window := select_ui_test_begin()
        defer { select_ui_test_end(window) }
        mut app := select_picker_test_app('<select id="sort"><option>A</option><option>B</option></select>')
        defer { app.dispose_browser_tab() }
        select_ui_test_choose(-2)
        select_picker_test_click(mut app, 'sort')
        first := app.browser_ui().popup or { panic('missing first popup') }
        app.dismiss_browser_popup()
        select_picker_test_click(mut app, 'sort')
        second := app.browser_ui().popup or { panic('missing replacement popup') }
        assert first.token != second.token
        app.browser_popup_action(first.action(1))
        assert app.browser_ui().popup != none
        assert html.html_select_element_value(unsafe { &dom.HTMLSelectElement(app.document.get_element_by_id('sort')?) }) == 'A'
        assert app.handle_browser_popup_key('escape')
        assert app.browser_ui().popup == none
        select_picker_test_click(mut app, 'sort')
        app.install_loaded_page(LoadedPage{url: 'https://boards.4chan.org/pol/catalog', content_type: 'text/html', markup: '<p>replacement</p>'}, true)
        assert app.browser_ui().popup == none && app.browser_ui().select_node == unsafe { nil }
        app.browser_popup_action(second.action(1))
        assert app.browser_ui().popup == none
    }
}
