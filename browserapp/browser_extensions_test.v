module main

import adblock
import browserextensions
import html
import os
import page
import time

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
