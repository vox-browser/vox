module main

import css
import dom
import os

// Recorded interaction state is applied through the normal focus algorithm;
// author markup and styles remain unchanged in both capture engines.
fn restore_capture_focus(document &dom.Document, id string) !bool {
	if id == '' { return false }
	matches := css.query_selector_all(document.as_node(), '[id]').filter(it.get_attribute_value('id') == id)
	if matches.len != 1 { return error('Capture focus target is missing or ambiguous: ${id}') }
	target := matches[0]
	if !target.is_focusable() { return error('Capture target is not focusable: ${id}') }
	if target.is_focused() { return false }
	dom.run_focusing_steps_for_node(target.as_node(), none, .key)
	if !target.is_focused() { return error('Capture target did not accept focus: ${id}') }
	return true
}

fn (mut app BrowserApp) restore_capture_focus_if_requested() bool {
	id := os.getenv('VOX_CAPTURE_FOCUS_ID')
	if app.screenshot_path == '' || app.document == unsafe { nil } || id == '' { return false }
	return restore_capture_focus(app.document, id) or {
		eprintln(err.msg())
		exit(1)
	}
}
