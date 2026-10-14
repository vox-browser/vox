module main

import browserjs
import dom
import html

fn test_browser_scripts_use_the_owning_windows_native_navigator() {
	$if !darwin { return }
	document := parse_browser_navigation_document('<!doctype html><p id="target"></p>', dom.URL{
		value: 'https://navigator-owner.example.test/'
	}, none)
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	mut messages := []string{}
	run_document_javascript(document, document.url.serialize(), [
		r'
 target.textContent=navigator.language;globalThis.navigatorOwnerValid=navigator===window.navigator&&navigator===clientInformation&&navigator instanceof Navigator&&Object.isFrozen(navigator.languages);
 ',
	], runtime, mut messages)
	assert messages == []
	assert runtime.evaluate_host('navigatorOwnerValid')! == 'true'
	window_pointer := document.get_window() or { panic('missing Window') }
	window := unsafe { &html.WindowModel(window_pointer) }
	assert document.get_element_by_id('target')?.as_node().text_content() or { '' } == window.navigator().language()
}
