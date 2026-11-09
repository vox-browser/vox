module main

import browserjs
import html

// A script navigation is handed to the shell once. Later tasks of the same
// page, such as its interval ticks while the new page loads, must not report it
// again: each report restarted the pending navigation.
fn test_script_navigation_is_reported_by_one_task_commit() {
	mut document := html.parse_document('<!doctype html><p id="content">before</p>')
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, 'https://old.reddit.com/', []string{}, runtime, mut messages)
	runtime.evaluate_host('location.href="/next";')!
	first := commit_compact_dom_task(document, runtime, mut messages)!
	assert first.navigation? == '/next'
	runtime.evaluate_host('document.getElementById("content").textContent="tick";')!
	second := commit_compact_dom_task(document, runtime, mut messages)!
	assert second.navigation == none
	assert (document.get_element_by_id('content')?).as_node().text_content()? == 'tick'
	runtime.evaluate_host('location.href="/again";')!
	third := commit_compact_dom_task(document, runtime, mut messages)!
	assert third.navigation? == '/again'
	assert messages == []string{}
}
