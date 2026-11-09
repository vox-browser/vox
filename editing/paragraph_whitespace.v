// Translated from LibWeb/Editing/Internal/Algorithms.cpp at 2919bf87a5e5.
module editing

import css
import dom

struct ResolvedWhiteSpace {
	collapse  ?string
	wrap_mode ?string
}

struct RecordedWhiteSpace {
	node        &dom.Node
	white_space ResolvedWhiteSpace
}

fn resolved_white_space(node &dom.Node) ResolvedWhiteSpace {
	return ResolvedWhiteSpace{resolved_keyword(node, 'white-space-collapse'), resolved_keyword(node, 'text-wrap-mode')}
}

fn (space ResolvedWhiteSpace) preserves_line_breaks() bool {
	return (space.collapse or { '' }) in ['preserve', 'preserve-breaks', 'break-spaces']
}

fn (space ResolvedWhiteSpace) white_space_value() ?string {
	collapse := space.collapse or { return none }
	wrap_mode := space.wrap_mode or { return none }
	nowrap := wrap_mode == 'nowrap'
	return match collapse {
		'collapse' {
			if nowrap { 'nowrap' } else { 'normal' }
		}
		'preserve' {
			if nowrap { 'pre' } else { 'pre-wrap' }
		}
		'preserve-breaks' {
			if nowrap { return none }
			'pre-line'
		}
		else { return none }
	}
}

// Joining paragraphs removes their first line break, including a preserved
// newline nested in inline formatting, and leaves subsequent lines in place.
fn isolate_first_line_of_inline_run(container &dom.Node, first &dom.Node) []&dom.Node {
	mut line_end := ?dom.BoundaryPoint(none)
	mut child := ?&dom.Node(first)
	for {
		current_child := child or { break }
		if line_end != none || !is_inline_node(current_child) { break }
		mut descendant := ?&dom.Node(current_child)
		for {
			node := descendant or { break }
			if node.is_html_br_element() && node.is_editable() {
				line_end = dom.BoundaryPoint{node.parent() or { break }, node.index()}
				remove_node(node)
				break
			}
			if node.is_text() {
				text := unsafe { &dom.Text(node) }
				if text.is_editable() && resolved_white_space(node).preserves_line_breaks() {
					mut newline := -1
					mut offset := 0
					for character in text.data().runes() {
						if character == `\n` {
							newline = offset
							break
						}
						offset += if u32(character) > 0xffff { 2 } else { 1 }
					}
					if newline >= 0 {
						delete_data(editing_character_data(node), newline, 1) or { panic(err) }
						if text.length() == 0 {
							line_end = dom.BoundaryPoint{node.parent() or { break }, node.index()}
							remove_node(node)
						} else {
							line_end = dom.BoundaryPoint{node, newline}
						}
						break
					}
				}
			}
			descendant = node.next_in_pre_order(current_child)
		}
		child = current_child.next_sibling()
	}
	if end := line_end {
		mut point := end
		for voidptr(point.node) != voidptr(container) {
			node := point.node
			parent := node.parent() or { break }
			index := node.index()
			if point.offset == 0 {
				point = dom.BoundaryPoint{parent, index}
			} else if point.offset >= node.length() {
				point = dom.BoundaryPoint{parent, index + 1}
			} else if node.is_text() {
				text := unsafe { &dom.Text(node) }
				split_text(text, point.offset) or { panic(err) }
				point = dom.BoundaryPoint{parent, index + 1}
			} else {
				clone := clone_node_for_editing(node, false) or { panic(err) }
				insert_node_before(clone, parent, node.next_sibling())
				for node.child_count() > point.offset {
					move_node_preserving_ranges(node.child_at_index(point.offset) or { break }, clone, clone.child_count())
				}
				point = dom.BoundaryPoint{parent, index + 1}
			}
		}
		line_end = point
	}
	mut line := []&dom.Node{}
	mut next := if first.is_connected() { ?&dom.Node(first) } else { none }
	for {
		node := next or { break }
		if end := line_end {
			if node.index() >= end.offset { break }
		} else if !is_inline_node(node) {
			break
		}
		line << node
		next = node.next_sibling()
	}
	return line
}

fn sets_white_space_in_style_attribute(node &dom.Node) bool {
	element := node.as_element() or { return false }
	return property_in_style_attribute(element, 'white-space-collapse') != none
}

fn element_establishing_white_space(node &dom.Node) ?&dom.Element {
	white_space := resolved_white_space(node)
	mut current := if node.is_element() { ?&dom.Node(node) } else { node.parent() }
	for {
		establishing := current or { return none }
		if sets_white_space_in_style_attribute(establishing) { break }
		parent := establishing.parent() or { break }
		if !parent.is_element() || resolved_white_space(parent) != white_space { break }
		current = parent
	}
	return (current or { return none }).as_element()
}

fn rule_list_sets_white_space(rules &css.CSSRuleList, element &dom.Element) bool {
	for index in 0 .. rules.length() {
		rule := rules.item(u32(index)) or { continue }
		if rule.type_ == .style {
			if style := rule.style() {
				if style.has_property(css.PropertyNameAndID.from_id(.white_space_collapse))
					&& (element.matches(rule.selector_text()) or { false }) {
					return true
				}
			}
		}
		if rule.type_ in css.css_grouping_rule_types {
			if nested := rule.css_rules() {
				if rule_list_sets_white_space(nested, element) { return true }
			}
		}
	}
	return false
}

fn white_space_is_from_default_style(node &dom.Node) bool {
	element := element_establishing_white_space(node) or { return false }
	if element.local_name() !in ['pre', 'listing', 'xmp', 'plaintext']
		|| sets_white_space_in_style_attribute(element.as_node()) {
		return false
	}
	scope := css.style_scope_for_dom_node(element.document().as_node())
	for sheet in scope.stylesheets_for_cascade_origin(.author) {
		if !sheet.base.disabled && sheet.base.origin_clean && rule_list_sets_white_space(sheet.rules, element) {
			return false
		}
	}
	return true
}

fn element_changes_formatting(element &dom.Element) bool {
	for command in [command_subscript, command_bold, command_font_name, command_font_size,
		command_fore_color, command_hilite_color, command_italic, command_strikethrough,
		command_underline] {
		if !values_are_equivalent(command, effective_command_value(element.as_node(), command),
			effective_command_value(element.parent(), command)) {
			return true
		}
	}
	return false
}

fn record_white_space_of_nodes(mut nodes []&dom.Node) []RecordedWhiteSpace {
	mut recorded := []RecordedWhiteSpace{}
	mut new_nodes := []&dom.Node{}
	for node in nodes {
		white_space := resolved_white_space(node)
		if white_space_is_from_default_style(node) {
			new_nodes << node
			continue
		}
		if mut span := node.as_element() {
			if is_html_element_named(node, ['span']) && editing_same_node((element_establishing_white_space(node) or { span }).as_node(), node)
				&& node.is_editable() && node.has_children() && !sets_white_space_in_style_attribute(node) {
				mut only_style_attributes := true
				for attribute in span.attributes().attrs {
					if attribute.namespace_uri() != none || attribute.local_name() !in [
						'class',
						'style',
					] {
						only_style_attributes = false
					}
				}
				if only_style_attributes && !element_changes_formatting(span) {
					for child in node.children_as_vector() {
						recorded << RecordedWhiteSpace{child, resolved_white_space(child)}
						new_nodes << child
					}
					unwrap_node_preserving_ranges(node)
					continue
				}
			}
		}
		recorded << RecordedWhiteSpace{node, white_space}
		new_nodes << node
	}
	nodes = new_nodes.clone()
	return recorded
}

fn restore_white_space_of_nodes(recorded []RecordedWhiteSpace) {
	if recorded.len == 0 { return }
	document := recorded[0].node.document()
	mut index := 0
	for index < recorded.len {
		first := recorded[index]
		value := first.white_space.white_space_value() or {
			index++
			continue
		}
		parent := first.node.parent() or {
			index++
			continue
		}
		if !first.node.is_editable() || resolved_white_space(first.node) == first.white_space
			|| white_space_is_from_default_style(parent) {
			index++
			continue
		}
		mut group := [first.node]
		index++
		for index < recorded.len {
			next := recorded[index]
			if !editing_same_node(next.node, group.last().next_sibling()) || next.white_space != first.white_space
				|| resolved_white_space(next.node) == next.white_space {
				break
			}
			group << next.node
			index++
		}
		if group.len == 1 && !first.node.is_html_br_element() {
			if element := first.node.as_element() {
				if element.is_html_element() {
					mut style := css.element_style(element)
					style.set_property('white-space', value, '') or { panic(err) }
					continue
				}
			}
		}
		span := editing_create_html_element(document, 'span')
		insert_node_before(span.as_node(), parent, first.node)
		mut style := css.element_style(span)
		style.set_property('white-space', value, '') or { panic(err) }
		for node in group {
			move_node_preserving_ranges(node, span.as_node(), span.as_node().child_count())
		}
	}
}
