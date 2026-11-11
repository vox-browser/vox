// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Connects Document's execCommand() and queryCommand*() entry points to the translated editing algorithms. DOM owns
// the IDL methods, while this package owns Editing/ExecCommand.cpp, avoiding a DOM -> Editing package cycle.
module editing

import dom

fn dom_editing_exec_command(_ voidptr, document &dom.Document, command string, show_ui bool, value string, user_input_type string) !bool {
	mut mutable_document := unsafe { &dom.Document(document) }
	input_type := if user_input_type == '' { ?string(none) } else { ?string(user_input_type) }
	return exec_command_internal(mut mutable_document, command, show_ui, value, .yes, input_type)!
}

fn dom_editing_query_command_enabled(_ voidptr, document &dom.Document, command string) !bool {
	return query_command_enabled(document, command)!
}

fn dom_editing_query_command_indeterm(_ voidptr, document &dom.Document, command string) !bool {
	return query_command_indeterm(document, command)!
}

fn dom_editing_query_command_state(_ voidptr, document &dom.Document, command string) !bool {
	return query_command_state(document, command)!
}

fn dom_editing_query_command_supported(_ voidptr, document &dom.Document, command string) !bool {
	return query_command_supported(document, command)!
}

fn dom_editing_query_command_value(_ voidptr, document &dom.Document, command string) !string {
	return query_command_value(document, command)!
}

fn dom_editing_sanitize_clipboard_html(_ voidptr, range &dom.Range, html string) !&dom.DocumentFragment {
	return sanitize_clipboard_html(range, html)
}

fn dom_editing_insert_pasted_fragment(_ voidptr, document &dom.Document, fragment &dom.DocumentFragment, user_input_type string) !bool {
	mut mutable_document := unsafe { &dom.Document(document) }
	input_type := if user_input_type == '' { ?string(none) } else { ?string(user_input_type) }
	return exec_command_with_fragment(mut mutable_document, 'insertHTML', false, '', .yes, input_type, fragment)
}

pub fn install_dom_editing_bridge(document &dom.Document) {
	if document.editing_command_hook() != none {
		return
	}
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_editing_command_hook(dom.DocumentEditingCommandHook{
		exec_command:            dom_editing_exec_command
		query_command_enabled:   dom_editing_query_command_enabled
		query_command_indeterm:  dom_editing_query_command_indeterm
		query_command_state:     dom_editing_query_command_state
		query_command_supported: dom_editing_query_command_supported
		query_command_value:     dom_editing_query_command_value
		sanitize_clipboard_html: dom_editing_sanitize_clipboard_html
		insert_pasted_fragment: dom_editing_insert_pasted_fragment
	})
}
