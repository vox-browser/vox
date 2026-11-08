module main

import css
import dom
import os

// A benchmark can wait for asynchronous application content before starting
// the existing screenshot settle timer. Empty preserves the normal boundary.
const capture_ready_selector = os.getenv('VOX_CAPTURE_READY_SELECTOR')

fn capture_ready_selector_matches(document &dom.Document, selector string) bool {
	if selector == '' { return true }
	if document == unsafe { nil } { return false }
	return css.query_selector_all(document.as_node(), selector).len > 0
}

fn (app &BrowserApp) capture_selector_ready() bool {
	return capture_ready_selector_matches(app.document, capture_ready_selector)
}
