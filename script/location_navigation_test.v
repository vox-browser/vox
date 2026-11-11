module main

import browserjs
import html
import os
import page

// Location.assign(), replace() and reload() exist on the bridge's Location
// and report their navigation with the method that produced it.
fn test_location_methods_report_their_navigation_mode() {
	mut document := html.parse_document('<!doctype html><p>page</p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://www.example.com/search?q=time', []string{}, runtime, mut messages)
	assert runtime.evaluate_host('[typeof location.assign, typeof location.replace, typeof location.reload].join()')! == 'function,function,function'
	runtime.evaluate_host('location.replace("/search?q=time&sei=1");')!
	replaced := commit_compact_dom_task(document, runtime, mut messages)!
	assert replaced.navigation? == '/search?q=time&sei=1'
	assert runtime.evaluate_host('__ladybirdTakeNavigationMode("/search?q=time&sei=1")')! == 'replace'
	// The mode is consumed with its navigation.
	assert runtime.evaluate_host('__ladybirdTakeNavigationMode("/search?q=time&sei=1")')! == ''

	runtime.evaluate_host('location.assign("/next");')!
	assigned := commit_compact_dom_task(document, runtime, mut messages)!
	assert assigned.navigation? == '/next'
	assert runtime.evaluate_host('__ladybirdTakeNavigationMode("/next")')! == ''

	runtime.evaluate_host('location.reload();')!
	reloaded := commit_compact_dom_task(document, runtime, mut messages)!
	assert reloaded.navigation? == 'https://www.example.com/search?q=time'
	assert runtime.evaluate_host('__ladybirdTakeNavigationMode("https://www.example.com/search?q=time")')! == 'reload'

	// A later href assignment supersedes an earlier replace().
	runtime.evaluate_host('location.replace("/a"); location.href="/b";')!
	superseded := commit_compact_dom_task(document, runtime, mut messages)!
	assert superseded.navigation? == '/b'
	assert runtime.evaluate_host('__ladybirdTakeNavigationMode("/b")')! == ''
	assert runtime.evaluate_host('try{location.replace();"no"}catch(e){e instanceof TypeError?"TypeError":"other"}')! == 'TypeError'
	assert messages == []string{}
}

// A page that forwards itself with location.replace(), like a search engine's
// script challenge, is replaced in session history: Back skips it.
fn test_location_replace_commits_in_place_of_the_current_history_entry() {
	directory := os.join_path(os.temp_dir(), 'vox-location-replace-${os.getpid()}')
	os.mkdir_all(directory)!
	defer { os.rmdir_all(directory) or {} }
	os.write_file(os.join_path(directory, 'first.html'), '<!doctype html><title>first</title><p>first</p>')!
	os.write_file(os.join_path(directory, 'challenge.html'), '<!doctype html><title>challenge</title><script>location.replace("results.html")</script>')!
	os.write_file(os.join_path(directory, 'results.html'), '<!doctype html><title>results</title><p id="results">results</p>')!
	first := 'file://' + os.join_path(directory, 'first.html')
	challenge := 'file://' + os.join_path(directory, 'challenge.html')
	results := 'file://' + os.join_path(directory, 'results.html')
	mut app := &BrowserApp{
		page_model:      page.Page.create(1) or { panic(err) }
		viewport_width:  800
		viewport_height: 600
	}
	defer { app.dispose_browser_tab() }
	app.navigate(first, true)
	assert app.history.len == 1
	app.navigate(challenge, true)
	app.poll_deferred_navigation_input()
	assert app.document.get_element_by_id('results') != none
	assert app.history.map(it.url) == [first, results]
	assert app.history_index == 1
	assert !app.back_forward_cache.pages.any(it.entry_url == challenge)
	app.history_go(-1)
	assert app.address == first
	assert app.history_index == 0
}
