module main

import dom
import html
import time

fn hibernation_test_app() &BrowserApp {
	app := browser_tabs_test_app()
	app.activate_tab_chrome('tab-new')
	mut second := app.active_browser_tab()
	second.install_loaded_page(LoadedPage{
		url:          'https://tabs.example/second'
		markup:       '<!doctype html><title>Second page</title><input id="editor" value="second"><script>var tabValue = 99;</script>'
		content_type: 'text/html'
	}, true)
	app.activate_tab_chrome('tab-select:0')
	return app
}

fn hibernation_test_cleanup(mut app BrowserApp) {
	defer { app.application.close() }
	for mut tab in app.tabs.pages { tab.dispose_browser_tab() }
}

fn test_hibernate_background_tab_discards_live_content_and_wakes_on_select() {
	mut app := hibernation_test_app()
	defer { hibernation_test_cleanup(mut app) }
	assert app.tabs.pages.len == 2
	assert app.tabs.selected == 0
	second := app.tabs.pages[1]
	second_document := second.document
	assert second_document != unsafe { nil }
	assert !app.is_browser_tab_hibernated(1)

	assert app.hibernate_browser_tab(1)
	assert app.is_browser_tab_hibernated(1)
	assert second.document == unsafe { nil }
	// The tab strip keeps showing the cached title and history.
	assert app.browser_display_tab_title(1, false) == 'Second page'
	assert second.history.len == 2
	assert second.address == 'https://tabs.example/second'
	assert !app.browser_tab_is_loading(1)
	assert app.browser_tab_hibernated_states() == [false, true]
	assert app.browser_tab_hibernate_action(1) == 'tab-wake:1'
	assert app.browser_tab_hibernate_action(0) == ''

	// A hibernated tab keeps no live content behind.
	assert app.active_browser_tab().browser_tab_title() == 'First page'

	// Selecting the tab restores its page, including script state and edits.
	app.activate_tab_chrome('tab-select:1')
	assert !app.is_browser_tab_hibernated(1)
	mut restored := app.active_browser_tab()
	assert restored.document != unsafe { nil }
	assert !restored.document.has_been_destroyed()
	assert restored.browser_tab_title() == 'Second page'
	assert restored.history.len == 2
	assert restored.js_runtime.evaluate('tabValue')! == '99'
	assert second_document.has_been_destroyed()
}

fn test_hibernate_guards_selection_navigation_and_duplicates() {
	mut app := hibernation_test_app()
	defer { hibernation_test_cleanup(mut app) }
	// The selected tab always keeps its live content.
	assert !app.hibernate_browser_tab(0)
	assert !app.hibernate_browser_tab(-1)
	assert !app.hibernate_browser_tab(99)
	assert app.tabs.hibernated.len == 0
	// Re-hibernating an already hibernated tab is a no-op.
	assert app.hibernate_browser_tab(1)
	assert !app.hibernate_browser_tab(1)
	// Waking a live tab is a no-op.
	assert !app.wake_browser_tab(0)
	assert app.wake_browser_tab(1)
	assert !app.is_browser_tab_hibernated(1)
	assert !app.wake_browser_tab(1)
}

fn test_hibernate_preserves_form_values_across_wake() {
	mut app := hibernation_test_app()
	defer { hibernation_test_cleanup(mut app) }
	mut second := app.tabs.pages[1]
	second.install_loaded_page(LoadedPage{
		url:          'https://tabs.example/forms'
		markup:       '<!doctype html><title>Forms</title><input id="text" value="old"><textarea id="area">old</textarea>'
		content_type: 'text/html'
	}, true)
	text_element := second.document.get_element_by_id('text') or { panic('missing text input') }
	mut text := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(text_element) })
	text.set_value('typed-value')!
	assert app.hibernate_browser_tab(1)
	app.activate_tab_chrome('tab-select:1')
	mut restored := app.active_browser_tab()
	restored_element := restored.document.get_element_by_id('text') or { panic('missing restored input') }
	mut restored_text := html.HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(restored_element) })
	assert restored_text.value() == 'typed-value'
}

fn test_hibernate_action_roundtrip_through_tab_chrome() {
	mut app := hibernation_test_app()
	defer { hibernation_test_cleanup(mut app) }
	app.activate_tab_chrome('tab-hibernate:1')
	assert app.is_browser_tab_hibernated(1)
	app.activate_tab_chrome('tab-wake:1')
	assert app.is_browser_tab_hibernated(1)
	assert app.tabs.selected == 1
	assert !app.is_browser_tab_hibernated(1)
}

fn test_auto_hibernate_only_retires_long_idle_background_tabs() {
	mut app := hibernation_test_app()
	defer { hibernation_test_cleanup(mut app) }
	now := i64(time.sys_mono_now())
	app.tabs.tab_activity[app.browser_tab_identity(1)] = now - tab_hibernation_timeout_ns - 1
	app.auto_hibernate_browser_tabs_at(now)
	assert app.is_browser_tab_hibernated(1)
	assert !app.is_browser_tab_hibernated(0)
}

fn test_auto_hibernate_skips_fresh_tabs_without_activity() {
	mut app := hibernation_test_app()
	defer { hibernation_test_cleanup(mut app) }
	app.tabs.tab_activity.delete(app.browser_tab_identity(1))
	app.auto_hibernate_browser_tabs_at(i64(time.sys_mono_now()))
	assert !app.is_browser_tab_hibernated(1)
}

fn test_close_drops_hibernation_records() {
	mut app := hibernation_test_app()
	defer { hibernation_test_cleanup(mut app) }
	assert app.hibernate_browser_tab(1)
	key := app.browser_tab_identity(1)
	app.activate_tab_chrome('tab-close:1')
	assert app.tabs.pages.len == 1
	assert key !in app.tabs.hibernated
	assert key !in app.tabs.tab_activity
}
