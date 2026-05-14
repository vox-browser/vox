module main

import css
import dom
import html
import infra
import namespace_
import selection

fn main() {
	_ = css.StyleInvalidationReason.dom_mutation
	_ = dom.NodeType.invalid
	_ = html.event_load
	_ = infra.ascii_whitespace
	_ = namespace_.html
	_ = selection.selection_create
}
