module main

import css
import dom
import os
import time

// A benchmark can wait for asynchronous application content before starting
// the existing screenshot settle timer. Empty preserves the normal boundary.
const capture_ready_selector = os.getenv('VOX_CAPTURE_READY_SELECTOR')
// The capture checks the selector on every frame until it matches. A
// document whose tree and attributes are unchanged since the last check gives
// the same answer; check again at least this often regardless.
const capture_ready_selector_recheck_ns = u64(50 * time.millisecond)

struct CaptureReadySelectorAnswer {
mut:
	document   voidptr
	selector   string
	tree       u64
	attributes u64
	checked_ns u64
	matches    bool
}

__global capture_ready_selector_answer CaptureReadySelectorAnswer

fn capture_ready_selector_matches(document &dom.Document, selector string) bool {
	if selector == '' { return true }
	if document == unsafe { nil } { return false }
	now := time.sys_mono_now()
	tree := document.dom_tree_version()
	attributes := document.attribute_version()
	answer := capture_ready_selector_answer
	if answer.document == voidptr(document) && answer.selector == selector && answer.tree == tree
		&& answer.attributes == attributes && now - answer.checked_ns < capture_ready_selector_recheck_ns {
		return answer.matches
	}
	matches := css.query_selector(document.as_node(), selector) != none
	capture_ready_selector_answer = CaptureReadySelectorAnswer{
		document:   voidptr(document)
		selector:   selector
		tree:       tree
		attributes: attributes
		checked_ns: now
		matches:    matches
	}
	return matches
}

fn (app &BrowserApp) capture_selector_ready() bool {
	return capture_ready_selector_matches(app.document, capture_ready_selector)
}
