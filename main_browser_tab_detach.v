module main

import adblock
import browserjs
import css
import dom
import html
import json2
import os
import rand
import time

// The native renderer and chrome have one window owner per process. Transfer a
// session to another instance rather than sharing those global native owners.
struct DetachedTabSession {
	version       int = 1
	url           string
	markup        string
	content_type  string
	history       []HistoryEntry
	history_index int
	scroll_y      f64
	zoom          f64 = 1
	engine        string = 'javascriptcore'
	script_policy string = 'automatic'
	width         int
	height        int
	drop_x        f64
	drop_y        f64
	forms         []DetachedTabFormValue
}

struct DetachedTabFormValue {
	index         int
	tag           string
	id            string
	value         string
	checked       bool
	indeterminate bool
}

struct PendingTabDetach {
	page    &BrowserApp = unsafe { nil }
	folder  string
	started i64
}

fn (app &BrowserApp) detached_tab_session() DetachedTabSession {
	mut forms := []DetachedTabFormValue{}
	if app.document != unsafe { nil } {
		for index, element in css.query_selector_all(app.document.as_node(), 'input,textarea,option') {
			tag := element.local_name()
			mut value := ''
			mut checked := false
			mut indeterminate := false
			match tag {
				'input' {
					model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
					if model.type_state() == .file_upload { continue }
					value = model.value()
					checked = model.checked()
					indeterminate = model.indeterminate()
				}
				'textarea' {
					model := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) })
					value = model.api_value()
				}
				'option' {
					checked = html.html_option_element_selected(unsafe { &dom.HTMLOptionElement(element) })
				}
				else { continue }
			}
			forms << DetachedTabFormValue{
				index:         index
				tag:           tag
				id:            element.get_attribute('id') or { '' }
				value:         value
				checked:       checked
				indeterminate: indeterminate
			}
		}
	}
	mut drop_x := 0.0
	mut drop_y := 0.0
	$if macos {
		drop_x = C.native_tab_drop_x()
		drop_y = C.native_tab_drop_y()
	}
	return DetachedTabSession{
		url:           if app.document != unsafe { nil } { app.document.url_string() } else { app.address }
		markup:        app.markup
		content_type:  app.content_type
		history:       app.history.clone()
		history_index: app.history_index
		scroll_y:      app.scroll_y
		zoom:          app.page_zoom
		engine:        app.js_engine.str()
		script_policy: app.script_policy.str()
		width:         app.viewport_width
		height:        app.viewport_height + app.chrome_height()
		drop_x:        drop_x
		drop_y:        drop_y
		forms:         forms
	}
}

fn read_detached_tab_session(path string) !DetachedTabSession {
	if path == '' { return DetachedTabSession{ version: 0 } }
	session := json2.decode[DetachedTabSession](os.read_file(path)!)!
	if session.version != 1 || session.url == '' || session.zoom < 0.25 || session.zoom > 5
		|| session.width <= 0 || session.height <= 0
		|| session.history_index < -1 || session.history_index >= session.history.len
		|| session.script_policy !in ['automatic', 'enabled', 'disabled'] {
		return error('invalid detached tab session')
	}
	_ = browserjs.parse_engine(session.engine)!
	return session
}

fn (session DetachedTabSession) engine_value() browserjs.Engine {
	return browserjs.parse_engine(session.engine) or { browserjs.Engine.javascriptcore }
}

fn (session DetachedTabSession) policy_value() BrowserScriptPolicy {
	return match session.script_policy {
		'enabled' { BrowserScriptPolicy.enabled }
		'disabled' { BrowserScriptPolicy.disabled }
		else { BrowserScriptPolicy.automatic }
	}
}

fn (mut app BrowserApp) restore_detached_tab(session DetachedTabSession) {
	app.ensure_browser_zoom_levels()
	app.zoom_levels.set_for_url(session.url, session.zoom) or {
		eprintln('Vox: could not restore domain zoom: ${err.msg()}')
	}
	app.page_zoom = session.zoom
	app.js_engine = session.engine_value()
	app.script_policy = session.policy_value()
	mut client := app.page_model.client()
	client.zoom_level_ = session.zoom
	if session.markup == '' && session.url != browser_new_tab_url {
		app.navigate(session.url, true)
	} else {
		app.install_loaded_page(LoadedPage{
			url:          session.url
			markup:       session.markup
			content_type: session.content_type
			status:       'Moved to new window'
		}, false)
	}
	if session.history.len > 0 {
		app.history = session.history.clone()
		app.history_index = session.history_index
	}
	if app.document != unsafe { nil } {
		// Domainless pages keep their explicitly transferred session zoom too.
		app.set_browser_zoom(session.zoom)
		elements := css.query_selector_all(app.document.as_node(), 'input,textarea,option')
		for saved in session.forms {
			if saved.index < 0 || saved.index >= elements.len { continue }
			element := elements[saved.index]
			if element.local_name() != saved.tag || (element.get_attribute('id') or { '' }) != saved.id {
				continue
			}
			match saved.tag {
				'input' {
					mut model := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
					model.set_value(saved.value) or { continue }
					model.set_checked(saved.checked)
					model.set_indeterminate(saved.indeterminate)
				}
				'textarea' {
					mut model := html.html_text_area_element_model_for_dom_element(unsafe { &dom.HTMLTextAreaElement(element) })
					model.set_value(saved.value)
				}
				'option' {
					html.html_option_element_set_selected(unsafe { &dom.HTMLOptionElement(element) }, saved.checked)
				}
				else {}
			}
		}
		app.relayout(session.width, session.height)
	}
	app.set_scroll_y(session.scroll_y, session.height)
}

fn (mut app BrowserApp) detach_browser_tab(index int) {
	if index < 0 || index >= app.tabs.pages.len { return }
	mut tab := app.tabs.pages[index]
	for pending in app.tabs.pending_detaches {
		if voidptr(pending.page) == voidptr(tab) { return }
	}
	session := tab.detached_tab_session()
	folder := os.join_path(os.temp_dir(), 'vox-tab-${rand.uuid_v4()}')
	os.mkdir(folder) or {
		tab.status = 'Could not open window: ${err}'
		return
	}
	mut launched := false
	defer { if !launched { os.rmdir_all(folder) or {} } }
	os.chmod(folder, 0o700) or {
		tab.status = 'Could not open window: ${err}'
		return
	}
	path := os.join_path(folder, 'session.json')
	os.write_file(path, json2.encode(session)) or {
		tab.status = 'Could not open window: ${err}'
		return
	}
	os.chmod(path, 0o600) or {
		tab.status = 'Could not open window: ${err}'
		return
	}
	app.tabs.open_window(path) or {
		tab.status = 'Could not open window: ${err}'
		return
	}
	launched = true
	app.tabs.pending_detaches << PendingTabDetach{ page: tab, folder: folder, started: time.sys_mono_now() }
	app.poll_detached_tab_windows()
}

fn (mut app BrowserApp) poll_detached_tab_windows() {
	if app.tabs == unsafe { nil } { return }
	for i := app.tabs.pending_detaches.len - 1; i >= 0; i-- {
		pending := app.tabs.pending_detaches[i]
		ready := os.is_file(os.join_path(pending.folder, 'ready'))
		index := app.browser_tab_index(pending.page)
		expired := time.sys_mono_now() - pending.started > 60_000_000_000
		if !ready && !expired && index >= 0 { continue }
		app.tabs.pending_detaches.delete(i)
		os.rmdir_all(pending.folder) or {}
		if ready && index >= 0 {
			app.close_browser_tab(index)
		} else if expired && index >= 0 {
			mut tab := app.tabs.pages[index]
			tab.status = 'Could not open window: startup timed out'
		}
	}
	if app.tabs.pending_detaches.len > 0 {
		$if macos {
			C.native_wake_browser_after(50)
		} $else {
			request_browser_frame()
		}
	}
}

fn (mut app BrowserApp) finish_detached_tab_restore() {
	if app.restore_tab_path == '' { return }
	session := read_detached_tab_session(app.restore_tab_path) or { exit(1) }
	$if macos {
		C.native_position_detached_tab(session.drop_x, session.drop_y)
	}
	// Called only after the first frame, so the source stays open through startup.
	// A parent that cancelled or timed out removes this directory. Do not leave
	// an extra window behind if its acknowledgement can no longer be delivered.
	os.write_file(os.join_path(os.dir(app.restore_tab_path), 'ready'), 'ready') or { exit(1) }
	app.restore_tab_path = ''
}

fn open_detached_browser_window(path string) ! {
	executable := adblock.current_executable_path()!
	$if macos {
		if !C.native_open_tab_window(executable.str, path.str) {
			return error('could not launch Vox')
		}
	} $else {
		mut child := os.new_process(executable)
		child.set_args(['--restore-tab', path])
		child.run()
		if child.status == .aborted { return error(child.err) }
		spawn reap_detached_browser_window(mut child)
	}
}

$if !macos {
	fn reap_detached_browser_window(mut child os.Process) {
		child.wait()
		child.close()
	}
}
