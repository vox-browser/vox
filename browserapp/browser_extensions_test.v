module main

import adblock
import browserextensions
import html
import os
import page
import time

$if vox_ui2 ? {
	import ui2
	#include "@VMODROOT/native/include/native_browser_settings_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_parent(window voidptr) voidptr
	fn C.native_test_address_close(window voidptr)
	fn C.native_test_chrome_click(control voidptr)
}

fn testsuite_begin() {
	adblock.set_enabled(false)
}

fn browser_extension_test_profile() !string {
	path := os.join_path(os.temp_dir(), 'vox-extension-fixture-${os.getpid()}-${time.sys_mono_now()}')
	os.mkdir_all(path)!
	return path
}

fn restore_extension_test_profile(profile ?string) {
	if previous := profile {
		os.setenv('VOX_PROFILE_DIR', previous, true)
	} else {
		os.unsetenv('VOX_PROFILE_DIR')
	}
}

fn test_installed_extension_runs_in_navigation_order_and_changes_live_dom_and_css() {
	$if !darwin && !linux {
		return
	}
	profile := browser_extension_test_profile()!
	previous := os.getenv_opt('VOX_PROFILE_DIR')
	os.setenv('VOX_PROFILE_DIR', profile, true)
	defer {
		restore_extension_test_profile(previous)
		os.rmdir_all(profile) or {}
	}
	os.write_file(os.join_path(profile, 'manifest.json'), '{
		"manifest_version":3, "name":"Lifecycle", "version":"1",
		"content_scripts":[
			{"matches":["https://extensions.test/allowed"],"css":["extension.css"],"js":["start.js"],"world":"MAIN","run_at":"document_start"},
			{"matches":["https://extensions.test/allowed"],"js":["end.js"],"world":"MAIN","run_at":"document_end"},
			{"matches":["https://extensions.test/allowed"],"js":["idle.js"],"world":"MAIN"}
		]
	}')!
	os.write_file(os.join_path(profile, 'extension.css'), '#result { color: rgb(1, 2, 3) }')!
	os.write_file(os.join_path(profile, 'start.js'), 'globalThis.stages = [document.readyState, document.body === null];')!
	os.write_file(os.join_path(profile, 'end.js'), 'stages.push(document.readyState); document.getElementById("result").textContent = "changed";')!
	os.write_file(os.join_path(profile, 'idle.js'), 'stages.push(document.readyState, "idle");')!
	extension := browserextensions.install(browserextensions.profile_path(), profile)!
	mut app := BrowserApp{
		page_model:       page.Page.create(1)!
		script_policy:    .enabled
		layout_tree_only: true
		viewport_width:   320
		viewport_height:  200
	}
	defer { app.dispose_browser_tab() }
	loaded := LoadedPage{
		url:          'https://extensions.test/allowed'
		content_type: 'text/html'
		markup:       '<!doctype html><head><script>if (typeof stages !== "undefined") { stages.push("author"); addEventListener("load", () => stages.push("load")); }</script></head><body><p id=result>original</p>'
	}
	app.install_loaded_page(loaded, false)
	assert app.js_runtime != unsafe { nil }
	mut event_loop := html.main_thread_event_loop()
	for _ in 0 .. 12 {
		event_loop.process()
	}
	assert app.js_runtime.evaluate_host('stages.join("|")')! == 'loading|true|author|interactive|load|complete|idle'
	assert app.document.get_element_by_id('result')?.as_node().text_content()? == 'changed'
	assert app.js_runtime.evaluate_host('getComputedStyle(document.getElementById("result")).color')! == 'rgb(1, 2, 3)'
	assert app.js_messages == []string{}
	app.install_loaded_page(LoadedPage{ ...loaded, url: 'https://extensions.test/excluded' }, false)
	assert app.js_runtime.evaluate_host('typeof stages')! == 'undefined'
	assert app.document.get_element_by_id('result')?.as_node().text_content()? == 'original'
	browserextensions.set_enabled(browserextensions.profile_path(), extension.id, false)!
	app.install_loaded_page(loaded, false)
	assert app.js_runtime.evaluate_host('typeof stages')! == 'undefined'
	assert app.document.get_element_by_id('result')?.as_node().text_content()? == 'original'
}

fn test_extensions_panel_loads_disables_and_removes_an_extension() {
	$if vox_ui2 ? {
		profile := browser_extension_test_profile()!
		previous := os.getenv_opt('VOX_PROFILE_DIR')
		os.setenv('VOX_PROFILE_DIR', profile, true)
		defer {
			restore_extension_test_profile(previous)
			os.rmdir_all(profile) or {}
		}
		os.write_file(os.join_path(profile, 'manifest.json'), '{"manifest_version":3,"name":"CSS fixture","version":"1","content_scripts":[{"matches":["https://extensions.test/*"],"css":["extension.css"]}]}')!
		os.write_file(os.join_path(profile, 'extension.css'), '#result { display:none }')!
		window := C.native_test_address_window()
		mut app := &BrowserApp{}
		app.mount_ui2_chrome(C.native_test_address_parent(window), 800, 600)!
		defer {
			browser_extensions_event('extensions-close')
			app.unmount_address_bar()
			C.native_test_address_close(window)
		}
		show_browser_settings()
		open := ui2.embedded_browser_control('extensions-open')
		assert open != unsafe { nil }
		C.native_test_chrome_click(open)
		assert ui2.embedded_panel_visible('extensions')
		assert !browser_settings_visible()
		ui2.set_text('extensions-path', profile)
		C.native_test_chrome_click(ui2.embedded_browser_control('extensions-install'))
		extensions := browserextensions.installed(browserextensions.profile_path())!
		assert extensions.len == 1
		id := extensions[0].id
		disable := ui2.embedded_browser_control('extensions-disable:${id}')
		assert disable != unsafe { nil }
		C.native_test_chrome_click(disable)
		assert !browserextensions.installed(browserextensions.profile_path())![0].enabled
		C.native_test_chrome_click(ui2.embedded_browser_control('extensions-remove:${id}'))
		assert browserextensions.installed(browserextensions.profile_path())!.len == 0
	}
}
