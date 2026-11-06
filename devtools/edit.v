module devtools

import dom

// editable_text is what the inline editor starts with.
pub fn editable_text(node &dom.Node, kind EditorKind) !string {
	match kind {
		.html {
			element := node.as_element() or { return error('Only elements can be edited as HTML') }
			parent := node.parent() or { return error('The element is not in the document') }
			if parent.is_document() {
				return error('The document element cannot be replaced; edit its children instead')
			}
			return element.outer_html()!
		}
		.text {
			data := node.as_character_data() or {
				return error('Only text and comments have editable text')
			}
			return data.data()
		}
	}
}

// Replacement is the result of replace_with_html.
pub struct Replacement {
pub:
	// The node that takes over the selection: the first new node, or the
	// parent when the markup was empty.
	selected i64
	parent   &dom.Node = unsafe { nil }
	// The original element's following sibling, or nil.
	next  &dom.Node = unsafe { nil }
	nodes []&dom.Node
}

// replace_with_html swaps an element for parsed markup.
pub fn replace_with_html(node &dom.Node, markup string) !Replacement {
	mut element := node.as_element() or { return error('Only elements can be edited as HTML') }
	parent := node.parent() or { return error('The element is not in the document') }
	if parent.is_document() {
		return error('The document element cannot be replaced; edit its children instead')
	}
	previous := node.previous_sibling()
	next := node.next_sibling()
	element.set_outer_html(markup)!
	mut nodes := []&dom.Node{}
	mut selected := i64(0)
	mut current := if sibling := previous { sibling.next_sibling() } else { parent.first_child() }
	for {
		candidate := current or { break }
		if sibling := next {
			if voidptr(candidate) == voidptr(sibling) {
				break
			}
		}
		nodes << candidate
		if selected == 0 && !is_whitespace_text(candidate) {
			selected = node_id(candidate)
		}
		current = candidate.next_sibling()
	}
	return Replacement{
		selected: if selected == 0 { node_id(parent) } else { selected }
		parent:   parent
		next:     next or { unsafe { nil } }
		nodes:    nodes
	}
}

// UndoEntry reverses and repeats one edit. Both return the node to select
// afterwards, or 0.
pub struct UndoEntry {
pub:
	label string
	undo  fn () !i64 = unsafe { nil }
	redo  fn () !i64 = unsafe { nil }
}

const max_undo_entries = 100

pub fn (mut tools DevTools) record(entry UndoEntry) {
	tools.undo_stack << entry
	if tools.undo_stack.len > max_undo_entries {
		tools.undo_stack.delete(0)
	}
	tools.redo_stack.clear()
}

// undo reverses the latest edit and reports whether it did.
pub fn (mut tools DevTools) undo() bool {
	if tools.undo_stack.len == 0 {
		return false
	}
	entry := tools.undo_stack.pop()
	selected := entry.undo() or {
		// The document changed under the edit; later entries no longer apply.
		tools.undo_stack.clear()
		tools.redo_stack.clear()
		return tools.fail('Cannot undo the ${entry.label} edit: ${err.msg()}')
	}
	tools.redo_stack << entry
	tools.finish_history(selected)
	return true
}

// redo repeats the latest undone edit and reports whether it did.
pub fn (mut tools DevTools) redo() bool {
	if tools.redo_stack.len == 0 {
		return false
	}
	entry := tools.redo_stack.pop()
	selected := entry.redo() or {
		tools.redo_stack.clear()
		return tools.fail('Cannot redo the ${entry.label} edit: ${err.msg()}')
	}
	tools.undo_stack << entry
	tools.finish_history(selected)
	return true
}

fn (mut tools DevTools) finish_history(selected i64) {
	if selected != 0 {
		tools.selected = selected
		tools.reveal = true
	}
	tools.editor = none
	tools.error = ''
	tools.focused = true
	tools.version++
}

fn set_or_remove_attribute(element &dom.Element, name string, present bool, value string) {
	mut target := unsafe { &dom.Element(element) }
	if present {
		target.set_attribute_value(name, value)
	} else {
		target.remove_attribute(name)
	}
}

fn attribute_entry(element &dom.Element, name string, before_present bool, before string, after_present bool, after string) UndoEntry {
	id := node_id(element.as_node())
	return UndoEntry{
		label: 'attribute'
		undo:  fn [element, name, before_present, before, id] () !i64 {
			set_or_remove_attribute(element, name, before_present, before)
			return id
		}
		redo:  fn [element, name, after_present, after, id] () !i64 {
			set_or_remove_attribute(element, name, after_present, after)
			return id
		}
	}
}

// stored_attribute_name is `name` as the element stores it (HTML lowercases).
fn stored_attribute_name(element &dom.Element, name string) string {
	for attribute in attributes(element) {
		if attribute.name.to_lower() == name.to_lower() {
			return attribute.name
		}
	}
	return name
}

fn insert_nodes(parent &dom.Node, nodes []&dom.Node, before &dom.Node) ! {
	mut target := unsafe { &dom.Node(parent) }
	mut reference := ?&dom.Node(none)
	if before != unsafe { nil } {
		reference = before
	}
	for node in nodes {
		target.pre_insert(node, reference)!
	}
}

fn remove_nodes(nodes []&dom.Node) {
	for node in nodes {
		mut target := unsafe { &dom.Node(node) }
		target.remove(false)
	}
}

fn replacement_entry(original &dom.Node, replacement Replacement) UndoEntry {
	nodes := replacement.nodes.clone()
	parent := replacement.parent
	next := replacement.next
	selected := replacement.selected
	return UndoEntry{
		label: 'HTML'
		undo:  fn [original, nodes, parent, next] () !i64 {
			before := if nodes.len > 0 { nodes[0] } else { next }
			insert_nodes(parent, [original], before)!
			remove_nodes(nodes)
			return node_id(original)
		}
		redo:  fn [original, nodes, parent, selected] () !i64 {
			insert_nodes(parent, nodes, original)!
			remove_nodes([original])
			return selected
		}
	}
}

// copy_text is the clipboard form of a node: its markup, or its text.
pub fn copy_text(node &dom.Node) string {
	if element := node.as_element() {
		return element.outer_html() or { '' }
	}
	if node.is_comment() {
		return '<!--' + (node.node_value() or { '' }) + '-->'
	}
	if data := node.as_character_data() {
		return data.data()
	}
	if node.is_document_type() {
		return doctype_segment(node).text
	}
	return ''
}

fn (mut tools DevTools) fail(message string) bool {
	tools.error = message
	tools.version++
	return false
}

pub fn (mut tools DevTools) begin_edit(id i64, kind EditorKind) bool {
	node := tools.node(id) or { return false }
	text := editable_text(node, kind) or { return tools.fail(err.msg()) }
	tools.selected = id
	tools.editor = Editor{
		node: id
		kind: kind
		text: text
	}
	tools.error = ''
	tools.reveal = true
	tools.version++
	return true
}

pub fn (mut tools DevTools) cancel_edit() {
	if tools.editor == none {
		return
	}
	tools.editor = none
	tools.error = ''
	tools.focused = true
	tools.version++
}

// apply_edit commits the inline editor. Rejected markup keeps the editor
// open and reports the error.
pub fn (mut tools DevTools) apply_edit(text string) bool {
	editor := tools.editor or { return false }
	node := tools.node(editor.node) or {
		tools.editor = none
		return tools.fail('The node is no longer in the document')
	}
	match editor.kind {
		.html {
			replacement := replace_with_html(node, text) or { return tools.fail(err.msg()) }
			tools.record(replacement_entry(node, replacement))
			tools.selected = replacement.selected
		}
		.text {
			mut data := node.as_character_data() or {
				return tools.fail('Only text and comments have editable text')
			}
			before := data.data()
			data.set_data(text)
			after := data.data()
			id := editor.node
			tools.record(UndoEntry{
				label: 'text'
				undo:  fn [data, before, id] () !i64 {
					mut target := unsafe { &dom.CharacterData(data) }
					target.set_data(before)
					return id
				}
				redo:  fn [data, after, id] () !i64 {
					mut target := unsafe { &dom.CharacterData(data) }
					target.set_data(after)
					return id
				}
			})
		}
	}
	tools.editor = none
	tools.error = ''
	tools.focused = true
	tools.reveal = true
	tools.version++
	return true
}

pub fn (mut tools DevTools) set_attribute(id i64, name string, value string) bool {
	node := tools.node(id) or { return false }
	mut element := node.as_element() or { return false }
	trimmed := name.trim_space()
	if trimmed == '' {
		return tools.fail('Enter an attribute name')
	}
	before := element.get_attribute(trimmed)
	element.set_attribute_for_bindings(trimmed, value) or { return tools.fail(err.msg()) }
	stored := stored_attribute_name(element, trimmed)
	tools.record(attribute_entry(element, stored, before != none, before or { '' }, true,
		element.get_attribute(stored) or { value }))
	tools.error = ''
	tools.version++
	return true
}

pub fn (mut tools DevTools) remove_attribute(id i64, name string) bool {
	node := tools.node(id) or { return false }
	mut element := node.as_element() or { return false }
	if before := element.get_attribute(name) {
		stored := stored_attribute_name(element, name)
		element.remove_attribute(name)
		tools.record(attribute_entry(element, stored, true, before, false, ''))
	}
	tools.error = ''
	tools.version++
	return true
}

pub fn (mut tools DevTools) delete(id i64) bool {
	node := tools.node(id) or { return false }
	if node.is_document() || node.is_shadow_root() {
		return tools.fail('${node_label(node)} cannot be removed')
	}
	if node.parent() == none {
		return false
	}
	next := tools.selection_after_removal(id)
	parent := node.parent() or { return false }
	following := node.next_sibling() or { unsafe { nil } }
	mut target := unsafe { &dom.Node(node) }
	target.remove(false)
	tools.record(UndoEntry{
		label: 'delete'
		undo:  fn [parent, node, following, id] () !i64 {
			insert_nodes(parent, [node], following)!
			return id
		}
		redo:  fn [node, next] () !i64 {
			remove_nodes([node])
			return next
		}
	})
	tools.selected = next
	if editor := tools.editor {
		if editor.node == id {
			tools.editor = none
		}
	}
	tools.error = ''
	tools.focused = true
	tools.reveal = true
	tools.version++
	return true
}
