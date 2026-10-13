module main

import browserjs
import dom
import css
import strconv

// Retain native node identity across insertions instead of serializing each
// ancestor's complete subtree into the compact script bridge's initial state.
fn install_compact_element_content_binding(document &dom.Document, mut runtime browserjs.Runtime) ! {
	elements := css.query_selector_all(unsafe { &dom.Node(document) }, '*')
	runtime.define_host_function('__ladybirdReadElementContent', fn [elements] (input string) !string {
		parts := input.split(':')
		if parts.len != 2 {
			return error('Invalid element content request')
		}
		index := strconv.atoi(parts[0])!
		if index < 0 || index >= elements.len {
			return error('Invalid element content index')
		}
		element := elements[index]
		return match parts[1] {
			'textContent' { element.as_node().text_content() or { '' } }
			'innerHTML' { element.inner_html() or { '' } }
			else { return error('Invalid element content property') }
		}
	})!
}
