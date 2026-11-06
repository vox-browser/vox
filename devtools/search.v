module devtools

import dom

pub const search_id = 'devtools-search-input'
const max_search_results = 1000

// search_text is what a find-by-string query matches: an element's opening
// tag with its attributes, or a text, comment or doctype node's text.
fn search_text(node &dom.Node) string {
	if element := node.as_element() {
		mut text := '<' + tag_name(element)
		for attribute in attributes(element) {
			text += ' ${attribute.name}="${attribute.value}"'
		}
		return text + '>'
	}
	if node.is_text() || node.is_comment() {
		return node.node_value() or { '' }
	}
	if node.is_document_type() {
		return doctype_segment(node).text
	}
	return ''
}

pub fn (mut tools DevTools) open_search() {
	tools.search_open = true
	tools.version++
}

pub fn (mut tools DevTools) close_search() {
	tools.search_open = false
	tools.search_query = ''
	tools.search_results = []i64{}
	tools.search_nodes = map[i64]&dom.Node{}
	tools.search_index = -1
	tools.version++
}

// search finds nodes whose markup or text contains `query` case-insensitively,
// and the elements it selects as a CSS selector (`selector_matches`), in tree
// order. A text node shown on its element's row counts as that element.
pub fn (mut tools DevTools) search(document &dom.Document, query string, selector_matches []&dom.Node) {
	tools.search_query = query
	tools.search_results = []i64{}
	tools.search_nodes = map[i64]&dom.Node{}
	tools.search_index = -1
	tools.version++
	needle := query.trim_space().to_lower()
	if needle == '' || document == unsafe { nil } {
		return
	}
	mut selected := map[i64]bool{}
	for node in selector_matches {
		selected[node_id(node)] = true
	}
	tools.collect_matches(unsafe { &dom.Node(document) }, needle, selected)
	if tools.search_results.len > 0 {
		tools.search_index = 0
		tools.reveal_search_result()
	}
}

fn (mut tools DevTools) collect_matches(node &dom.Node, needle string, selected map[i64]bool) {
	if tools.search_results.len >= max_search_results {
		return
	}
	if !node.is_document() && !is_whitespace_text(node) && ((selected[node_id(node)] or { false })
		|| search_text(node).to_lower().contains(needle)) {
		mut target := node
		if node.is_text() {
			if parent := node.parent() {
				if text := inline_text(visible_children(parent)) {
					if voidptr(text) == voidptr(node) {
						target = parent
					}
				}
			}
		}
		id := node_id(target)
		if id !in tools.search_nodes {
			tools.search_results << id
			tools.search_nodes[id] = target
		}
	}
	for child in visible_children(node) {
		tools.collect_matches(child, needle, selected)
	}
}

fn (mut tools DevTools) reveal_search_result() {
	if tools.search_index < 0 || tools.search_index >= tools.search_results.len {
		return
	}
	node := tools.search_nodes[tools.search_results[tools.search_index]] or { return }
	tools.reveal_node(node)
}

// search_step moves to the next or previous match, wrapping around.
pub fn (mut tools DevTools) search_step(forward bool) bool {
	count := tools.search_results.len
	if count == 0 {
		return false
	}
	tools.search_index = if forward {
		(tools.search_index + 1) % count
	} else {
		(tools.search_index - 1 + count) % count
	}
	tools.reveal_search_result()
	return true
}

pub fn (tools &DevTools) search_status() string {
	if tools.search_query.trim_space() == '' {
		return ''
	}
	if tools.search_results.len == 0 {
		return 'No matches'
	}
	return '${tools.search_index + 1} of ${tools.search_results.len}'
}

pub fn (tools &DevTools) is_search_result(id i64) bool {
	return id in tools.search_nodes
}
