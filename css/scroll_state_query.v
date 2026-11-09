module css

import dom

pub struct ScrollStateQuerySnapshot {
pub:
	stuck u8
	snapped u8
	scrollable u8
	scrolled u8
}

@[heap]
pub struct ScrollStateQueryContainer {
pub:
	element &dom.Element
pub mut:
	snapshot ScrollStateQuerySnapshot
	has_been_snapshotted bool
}

pub fn scroll_state_query_containers(document &dom.Document) []&ScrollStateQueryContainer {
	computer := css_style_computer_for(document)
	return computer.scroll_state_query_containers_.values()
}

fn scroll_state_query_container(element &dom.Element) &ScrollStateQueryContainer {
	mut computer := css_style_computer_for(element.document())
	key := voidptr(element)
	if existing := computer.scroll_state_query_containers_[key] { return existing }
	entry := &ScrollStateQueryContainer{element: element}
	computer.scroll_state_query_containers_[key] = entry
	return entry
}

pub fn publish_scroll_state_query_snapshot(mut container ScrollStateQueryContainer, snapshot ScrollStateQuerySnapshot) bool {
	container.has_been_snapshotted = true
	if container.snapshot == snapshot { return false }
	container.snapshot = snapshot
	// The originating element also owns ::before/::after styles which may use
	// it as their query container.
	mut origin := unsafe { &dom.Element(container.element) }
	origin.set_needs_style_update(true)
	// These descendants include shadow and slotted subjects. Their rule caches
	// already retain element-dependent conditions; invalidate only this subtree.
	mut stack := []&dom.Node{}
	append_flat_tree_children(container.element.as_node(), mut stack)
	for stack.len > 0 {
		node := stack.pop()
		if mut element := node.as_element() { element.set_needs_style_update(true) }
		append_flat_tree_children(node, mut stack)
	}
	return true
}

fn (mut parser Parser) parse_scroll_state_feature(mut tokens SupportsTokenStream) ?&BooleanExpression {
	mut transaction := tokens
	transaction.discard_whitespace()
	first := transaction.consume_a_token() or { return none }
	if first.is_block() && first.block().is_paren() {
		mut inner := SupportsTokenStream.from_values(first.block().value)
		feature := parser.parse_scroll_state_feature(mut inner) or { return none }
		inner.discard_whitespace()
		if inner.has_next_token() { return none }
		tokens = transaction
		return BooleanExpression.create_in_parens(feature)
	}
	if !first.is(.ident) { return none }
	name := first.token().ident().to_lower()
	if name !in ['scrollable', 'scrolled', 'snapped', 'stuck'] { return none }
	transaction.discard_whitespace()
	mut value := ''
	if transaction.has_next_token() {
		colon := transaction.consume_a_token() or { return none }
		if !colon.is(.colon) { return none }
		transaction.discard_whitespace()
		keyword := transaction.consume_a_token() or { return none }
		if !keyword.is(.ident) { return none }
		value = keyword.token().ident().to_lower()
		allowed := if name == 'snapped' { ['none', 'x', 'y', 'block', 'inline', 'both'] }
			else { ['none', 'top', 'right', 'bottom', 'left', 'block-start', 'block-end', 'inline-start', 'inline-end', 'x', 'y', 'block', 'inline'] }
		if value !in allowed { return none }
	}
	transaction.discard_whitespace()
	if transaction.has_next_token() { return none }
	tokens = transaction
	return &BooleanExpression{kind: .general_enclosed, scroll_state_feature_name: name,
		scroll_state_feature_value: value, text: name + if value == '' { '' } else { ': ' + value }}
}

fn evaluate_scroll_state_feature(expression &BooleanExpression, context BooleanExpressionEvaluationContext) MatchResult {
	element := context.query_container or { return .unknown }
	snapshot := scroll_state_query_container(element).snapshot
	value := expression.scroll_state_feature_value
	style := computed_properties_for_element(element) or { return .unknown }
	horizontal := style.writing_mode() == .horizontal_tb
	if expression.scroll_state_feature_name == 'snapped' {
		axes := snapshot.snapped
		return as_match_result(match value {
			'' { axes != 0 }
			'none' { axes == 0 }
			'both' { axes == 3 }
			'x' { axes & 1 != 0 }
			'y' { axes & 2 != 0 }
			'inline' { axes & (if horizontal { u8(1) } else { u8(2) }) != 0 }
			'block' { axes & (if horizontal { u8(2) } else { u8(1) }) != 0 }
			else { false }
		})
	}
	edges := match expression.scroll_state_feature_name {
		'stuck' { snapshot.stuck }
		'scrolled' { snapshot.scrolled }
		else { snapshot.scrollable }
	}
	if value == '' { return as_match_result(edges != 0) }
	if value == 'none' { return as_match_result(edges == 0) }
	mask := match value {
		'top' { u8(1) }
		'right' { u8(2) }
		'bottom' { u8(4) }
		'left' { u8(8) }
		'x' { u8(10) }
		'y' { u8(5) }
		'inline' { if horizontal { u8(10) } else { u8(5) } }
		'block' { if horizontal { u8(5) } else { u8(10) } }
		else {
			// Logical query directions use the query container's own writing mode.
			mode := style.writing_mode()
			inline_start := if horizontal { if style.direction() == .rtl { u8(2) } else { u8(8) } }
				else if (style.direction() == .rtl) != (mode == .sideways_lr) { u8(4) } else { u8(1) }
			block_start := if horizontal { u8(1) } else if mode in [.vertical_rl, .sideways_rl] { u8(2) } else { u8(8) }
			start := if value.starts_with('inline') { inline_start } else { block_start }
			if value.ends_with('start') { start } else {
				match start { 1 { u8(4) } 2 { u8(8) } 4 { u8(1) } else { u8(2) } }
			}
		}
	}
	return as_match_result(edges & mask != 0)
}

pub fn record_relative_scroll_for_queries(document &dom.Document, element ?&dom.Element, delta dom.CSSPixelPoint_) {
	if delta.is_zero() { return }
	target := element or { document.document_element() or { return } }
	mut computer := css_style_computer_for(document)
	key := u64(target.as_node().unique_id())
	mut direction := computer.relative_scroll_query_directions_[key]
	if delta.x() != 0 { direction = (direction & ~u8(10)) | if delta.x() > 0 { u8(2) } else { u8(8) } }
	if delta.y() != 0 { direction = (direction & ~u8(5)) | if delta.y() > 0 { u8(4) } else { u8(1) } }
	computer.relative_scroll_query_directions_[key] = direction
}

// Direction survives a container-type change without retaining disconnected DOM
// nodes in the query registry.
pub fn relative_scroll_query_direction(element &dom.Element) u8 {
 return css_style_computer_for(element.document()).relative_scroll_query_directions_[u64(element.as_node().unique_id())]
}

pub fn forget_scroll_state_query_container(document &dom.Document, element &dom.Element) {
 mut computer := css_style_computer_for(document)
 computer.scroll_state_query_containers_.delete(voidptr(element))
}
