module main

import dom
import platform

fn document_heap_element_count(document &dom.Document) int {
	root := document.as_node()
	mut count := 0
	mut current := root.first_child()
	for {
		node := current or { break }
		if node.is_element() {
			count++
			if count == platform.document_heap_element_threshold { break }
		}
		current = node.next_in_pre_order(root)
	}
	return count
}

fn prepare_document_render_heap(document &dom.Document) bool {
	if !document.as_node().is_scripting_enabled() { return false }
	return platform.prepare_document_heap_for_scripting(document_heap_element_count(document), true)
}

// Each element of a parsed document comes from a start tag or is implied by
// the parser, so counting start tags sizes the heap before the first parse of
// a large document allocates its DOM, style and layout records.
fn markup_start_tag_count(markup string) int {
	mut count := 0
	for index := 0; index + 1 < markup.len; index++ {
		if markup[index] == `<` && markup[index + 1].is_letter() {
			count++
			if count == platform.document_heap_element_threshold { break }
		}
	}
	return count
}

fn prepare_markup_render_heap(markup string, scripting_enabled bool) bool {
	if !scripting_enabled { return false }
	return platform.prepare_document_heap_for_scripting(markup_start_tag_count(markup), true)
}

fn (app &BrowserApp) document_scripting_enabled_for_heap() bool {
	return app.document == unsafe { nil } || app.document.as_node().is_scripting_enabled()
}
