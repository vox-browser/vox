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

// replace_with_html swaps an element for parsed markup. It returns the node
// that takes over the selection: the first new node, or the parent when the
// markup was empty.
pub fn replace_with_html(node &dom.Node, markup string) !i64 {
	mut element := node.as_element() or { return error('Only elements can be edited as HTML') }
	parent := node.parent() or { return error('The element is not in the document') }
	if parent.is_document() {
		return error('The document element cannot be replaced; edit its children instead')
	}
	previous := node.previous_sibling()
	next := node.next_sibling()
	element.set_outer_html(markup)!
	mut current := if sibling := previous { sibling.next_sibling() } else { parent.first_child() }
	for {
		candidate := current or { break }
		if sibling := next {
			if voidptr(candidate) == voidptr(sibling) {
				break
			}
		}
		if !is_whitespace_text(candidate) {
			return node_id(candidate)
		}
		current = candidate.next_sibling()
	}
	return node_id(parent)
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
			tools.selected = replace_with_html(node, text) or { return tools.fail(err.msg()) }
		}
		.text {
			mut data := node.as_character_data() or {
				return tools.fail('Only text and comments have editable text')
			}
			data.set_data(text)
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
	element.set_attribute_for_bindings(trimmed, value) or { return tools.fail(err.msg()) }
	tools.error = ''
	tools.version++
	return true
}

pub fn (mut tools DevTools) remove_attribute(id i64, name string) bool {
	node := tools.node(id) or { return false }
	mut element := node.as_element() or { return false }
	element.remove_attribute(name)
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
	mut target := unsafe { &dom.Node(node) }
	target.remove(false)
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
