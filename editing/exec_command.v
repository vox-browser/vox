// Copyright (c) 2024-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/ExecCommand.cpp: Document's execCommand(), queryCommandEnabled(), queryCommandIndeterm(),
// queryCommandState(), queryCommandSupported(), and queryCommandValue(). DOM owns the IDL entry points and reaches
// these algorithms through its editing command hook, which avoids a DOM -> Editing package cycle.
module editing

import dom

pub enum DispatchInputEvent {
	no
	yes
}

// https://w3c.github.io/editing/docs/execCommand/#execcommand()
pub fn exec_command(mut document dom.Document, command string, show_ui bool, value string) !bool {
	return exec_command_internal(mut document, command, show_ui, value, .yes, none)
}

pub fn exec_command_internal(mut document dom.Document, command string, _ bool, value string, dispatch_input_event DispatchInputEvent, user_input_type ?string) !bool {
	// AD-HOC: This is not directly mentioned in the spec, but all major browsers limit editing API calls to HTML documents
	if !document.is_html_document() {
		return error('InvalidStateError: execCommand is only supported on HTML documents')
	}

	// AD-HOC: All major browsers refuse to recursively execute execCommand() (e.g. inside input event handlers).
	if document.inside_exec_command {
		return false
	}
	document.inside_exec_command = true
	defer {
		document.inside_exec_command = false
	}

	// 1. If only one argument was provided, let show UI be false.
	// 2. If only one or two arguments were provided, let value be the empty string.
	// NOTE: these steps are dealt by the default values for both show_ui and value

	// 3. If command is not supported or not enabled, return false.
	// NOTE: query_command_enabled() also checks if command is supported
	if !(query_command_enabled(document, command) or { false }) {
		return false
	}

	// 4. If command is not in the Miscellaneous commands section:
	//
	//    We don't fire events for copy/cut/paste/undo/redo/selectAll because they should all have their own events. We
	//    don't fire events for styleWithCSS/useCSS because it's not obvious where to fire them, or why anyone would
	//    want them. We don't fire events for unsupported commands, because then if they became supported and were
	//    classified with the miscellaneous events, we'd have to stop firing events for consistency's sake.
	//
	// AD-HOC: The defaultParagraphSeparator command is also in the Miscellaneous commands section
	definition := find_command_definition(command) or { return false }
	mut affected_editing_host := ?&dom.Node(none)
	if definition.command !in [command_copy, command_cut, command_default_paragraph_separator, command_paste,
		command_redo, command_select_all, command_style_with_css, command_undo, command_use_css] {
		// 1. Let affected editing host be the editing host that is an inclusive ancestor of the active range's start
		//    node and end node, and is not the ancestor of any editing host that is an inclusive ancestor of the active
		//    range's start node and end node.
		//
		// NOTE: Because either the start or end node of the range could be inside an editing host that is part of the
		//       other node's editing host, we can probe both and see if either one is the other's ancestor.
		// NOTE: We can reuse ->editing_host() here since query_command_enabled() above already checked that both the
		//       start and end nodes are either editable or an editing host.
		if range_ := active_range(document) {
			if start_node_editing_host := range_.start_container().editing_host() {
				if end_node_editing_host := range_.end_container().editing_host() {
					affected_editing_host = if start_node_editing_host.is_ancestor_of(end_node_editing_host) {
						end_node_editing_host
					} else {
						start_node_editing_host
					}
				}
			}
		}

		// 2. Fire an event named "beforeinput" at affected editing host using InputEvent, with its
		//    bubbles and cancelable attributes initialized to true, and its data attribute
		//    initialized to null.
		// 3. If the value returned by the previous step is false, return false.
		// 4. If command is not enabled, return false.
		// 5. Let affected editing host be the editing host that is an inclusive ancestor of the active range's start
		//    node and end node, and is not the ancestor of any editing host that is an inclusive ancestor of the active
		//    range's start node and end node.
		//
		// AD-HOC: No, we don't. Neither Chrome nor Firefox fire the "beforeinput" event for execCommand(). This is an
		//         open discussion for the spec: https://github.com/w3c/editing/issues/200
	}

	// https://w3c.github.io/editing/docs/execCommand/#preserves-overrides
	// If a command preserves overrides, then before taking its action, the user agent must record current overrides.
	mut overrides := []RecordedOverride{}
	if definition.preserves_overrides {
		overrides = record_current_overrides(document)
	}

	// INTEROP: Chromium distinguishes pastes that begin inside text from pastes at an element boundary when deciding
	//          whether a trailing line break is merely a placeholder. Record this before caret canonicalization can
	//          turn an element-level boundary into an equivalent text position.
	range_before_command := active_range(document)
	mut paste_started_in_text_node := false
	if input_type := user_input_type {
		if range_ := range_before_command {
			// INTEROP: An Apple-interchange-newline represents an intentional paragraph boundary, not a fragment-ending
			//          placeholder. Blink and WebKit preserve the destination paragraph's trailing break in this case.
			paste_started_in_text_node = input_type == dom.input_type_insert_from_paste
				&& range_.start_container().is_text() && !value.contains('Apple-interchange-newline')
		}
	}
	mut paste_start_block := ?&dom.Node(none)
	if paste_started_in_text_node {
		if range_ := range_before_command {
			paste_start_block = block_node_of_node(range_.start_container())
		}
	}

	// NOTE: Step 7 below asks us whether the DOM tree was modified, so keep track of the document versions.
	old_dom_tree_version := document.dom_tree_version()
	old_character_data_version := document.character_data_version()

	// NB: Canonicalize the caret before the command acts and records its starting selection, so that e.g. typing at an
	//     element-level caret inserts into the adjacent content like Chromium does. Inline formatting commands with a
	//     collapsed selection only set overrides, and Chromium does not move the caret for those.
	command_edits_at_caret := definition.command in [command_delete, command_format_block,
		command_forward_delete, command_indent, command_insert_horizontal_rule, command_insert_html,
		command_insert_image, command_insert_line_break, command_insert_ordered_list,
		command_insert_paragraph, command_insert_text, command_insert_unordered_list,
		command_justify_center, command_justify_full, command_justify_left, command_justify_right,
		command_outdent]
	if affected_editing_host != none && command_edits_at_caret {
		if selection := document.get_selection() {
			mut mutable_selection := unsafe { &dom.Selection(selection) }
			canonicalize_collapsed_selection_for_editing(mut mutable_selection)
		}
	}
	// Focusing the editing host while moving the caret can remove the selection.
	// Commands with an affected editing host require an active range.
	if affected_editing_host != none && active_range(document) == none {
		return false
	}

	// AD-HOC: Record the mutations performed by the command action on the editing history, so the user can undo them.
	//         end_recording() is a no-op if the guard below already ended the recording.
	is_cut_or_paste := if input_type := user_input_type {
		input_type in [dom.input_type_delete_by_cut, dom.input_type_insert_from_paste]
	} else {
		false
	}
	if host := affected_editing_host {
		mut category := UndoStepCategory.other
		// INTEROP: Cut and paste are standalone undo units in Chromium: they never coalesce with typing or deletion
		//          runs, so they categorize as Other even though they run the delete and insertText commands.
		if !is_cut_or_paste {
			if definition.command in [command_insert_text, command_insert_line_break, command_insert_paragraph] {
				category = .insertion
			} else if definition.command == command_delete {
				category = .backward_deletion
			} else if definition.command == command_forward_delete {
				category = .forward_deletion
			}
		}
		history_pointer := install_editing_history(document)
		mut history := unsafe { &EditingHistory(history_pointer) }
		history.begin_recording(host, category)
	}
	defer {
		if history_pointer := editing_history_if_exists(document) {
			mut history := unsafe { &EditingHistory(history_pointer) }
			history.end_recording()
		}
	}

	// 5. Take the action for command, passing value to the instructions as an argument.
	document.set_running_editing_command_action(true)
	command_result := if definition.action == unsafe { nil } {
		false
	} else {
		definition.action(mut document, value)
	}
	document.set_running_editing_command_action(false)

	// INTEROP: Chromium removes the trailing placeholder line break after pasting into an existing text node. The
	//          execCommand draft only removes it when insertion creates a new text node. Perform this while the paste
	//          history transaction is still open so undo restores the placeholder and redo removes it again.
	if paste_started_in_text_node {
		if range_ := active_range(document) {
			// INTEROP: A trailing break remains the list item's line terminator after a block fragment is merged into
			//          that item. Blink removes paragraph placeholders here, but preserves list-item terminators.
			if block := block_node_of_node(range_.start_container()) {
				if editing_same_node(block, paste_start_block) && !block.is_html_li_element() {
					remove_extraneous_line_breaks_at_the_end_of_node(block)
				}
			}
		}
	}

	// NB: Canonicalize the caret the command produced before the ending selection is recorded, but only if the
	//     command actually performed an edit; Chromium leaves the caret alone otherwise.
	// INTEROP: A user cut or paste counts as an edit whenever its command ran: Chromium fires the input event and
	//          settles the caret even when the pasted fragment reduces to nothing but transport markers.
	tree_was_modified := document.dom_tree_version() != old_dom_tree_version
		|| document.character_data_version() != old_character_data_version
		|| (is_cut_or_paste && command_result)
	if affected_editing_host != none && tree_was_modified {
		if selection := document.get_selection() {
			mut mutable_selection := unsafe { &dom.Selection(selection) }
			canonicalize_collapsed_selection_for_editing(mut mutable_selection)
		}
	}

	// https://w3c.github.io/editing/docs/execCommand/#preserves-overrides
	// After taking the action, if the active range is collapsed, it must restore states and values from the recorded
	// list. Do this after canonicalizing the caret, since moving it unsets the overrides.
	if overrides.len > 0 {
		if selection := document.get_selection() {
			if selection.is_collapsed() {
				restore_states_and_values(mut document, overrides)
			}
		}
	}

	// NB: End the recording before dispatching the input event below, so that the undo step's ending selection is the
	//     selection produced by the command itself, not whatever an input event handler changed it to.
	if history_pointer := editing_history_if_exists(document) {
		mut history := unsafe { &EditingHistory(history_pointer) }
		history.end_recording()
	}

	// 6. If the previous step returned false, return false.
	if !command_result {
		return false
	}

	// 7. If the action modified DOM tree, then fire an event named "input" at affected editing host using InputEvent,
	//    with its isTrusted and bubbles attributes initialized to true, inputType attribute initialized to the mapped
	//    value of command, and its data attribute initialized to null.
	if host := affected_editing_host {
		if dispatch_input_event == .yes && tree_was_modified {
			// INTEROP: When the command runs on behalf of a user cut or paste, the input event carries the user's input
			//          type (deleteByCut or insertFromPaste) rather than the command's mapped value, like other browsers.
			input_type := user_input_type or { definition.mapped_value or { '' } }

			// AD-HOC: For insertText, we do what other browsers do and set data to value. A paste carries null data even
			//         though it runs the insertText command.
			input_data := if input_type in [dom.input_type_insert_text, dom.input_type_insert_composition_text] {
				?string(value)
			} else {
				none
			}

			// https://w3c.github.io/uievents/#dom-inputevent-iscomposing
			// true if the input event occurs as part of a composition session; that is, after a compositionstart event and
			// before the corresponding compositionend event.
			event := dom.InputEvent.create_from_platform_event('input', dom.InputEventInit{
				bubbles:      true
				input_type:   input_type
				data:         input_data
				is_composing: document.is_input_method_composing()
			}, [], dom.current_event_timestamp())

			document.set_preserve_selection_offsets_during_identical_character_data_replacement(true)
			event_target := unsafe { &dom.EventTarget(host) }
			event_target.dispatch_event(unsafe { &dom.Event(event) })
			document.set_preserve_selection_offsets_during_identical_character_data_replacement(false)
		}
	}

	// AD-HOC: Scroll the cursor into view after executing a command.
	if selection := document.get_selection() {
		selection.scroll_focus_into_view()
	}

	// 8. Return true.
	return true
}

// https://w3c.github.io/editing/docs/execCommand/#querycommandenabled()
pub fn query_command_enabled(document &dom.Document, command string) !bool {
	// AD-HOC: This is not directly mentioned in the spec, but all major browsers limit editing API calls to HTML documents
	if !document.is_html_document() {
		return error('InvalidStateError: queryCommandEnabled is only supported on HTML documents')
	}

	// 2. Return true if command is both supported and enabled, false otherwise.
	if !(query_command_supported(document, command) or { false }) {
		return false
	}
	lowercase_command := command_ascii_lowercase(command)

	// https://w3c.github.io/editing/docs/execCommand/#enabled
	// Among commands defined in this specification, those listed in Miscellaneous commands are always enabled, except
	// for the cut command and the paste command.
	// NOTE: cut and paste are actually in the Clipboard commands section
	if lowercase_command in ['defaultparagraphseparator', 'stylewithcss', 'usecss'] {
		if range_ := active_range(document) {
			return range_.start_container().is_editable_or_editing_host()
		}
		return true
	}

	// INTEROP: The spec lists undo and redo among the always-enabled miscellaneous commands, but in Chromium
	//          queryCommandEnabled("undo") is true only when there is a step to undo, and execCommand("undo") on an
	//          empty history returns false. Redo behaves symmetrically.
	if lowercase_command == 'undo' {
		history_pointer := editing_history_if_exists(document) or { return false }
		mut history := unsafe { &EditingHistory(history_pointer) }
		return history.can_undo()
	}
	if lowercase_command == 'redo' {
		history_pointer := editing_history_if_exists(document) or { return false }
		mut history := unsafe { &EditingHistory(history_pointer) }
		return history.can_redo()
	}

	// AD-HOC: selectAll requires a selection object to exist.
	if lowercase_command == 'selectall' {
		return document.get_selection() != none
	}

	// The other commands defined here are enabled if the active range is not null,
	range_ := active_range(document) or { return false }

	// its start node is either editable or an editing host,
	start_node := range_.start_container()
	if !start_node.is_editable_or_editing_host() {
		return false
	}

	// FIXME: the editing host of its start node is not an EditContext editing host,

	// its end node is either editable or an editing host,
	end_node := range_.end_container()
	if !end_node.is_editable_or_editing_host() {
		return false
	}

	// FIXME: the editing host of its end node is not an EditContext editing host,

	// and there is some editing host that is an inclusive ancestor of both its start node and its end node.
	mut inclusive_ancestor_editing_host := ?&dom.Node(none)
	mut ancestor := ?&dom.Node(start_node)
	for {
		current := ancestor or { break }
		if current.is_editing_host() && current.is_inclusive_ancestor_of(end_node) {
			inclusive_ancestor_editing_host = current
			break
		}
		ancestor = current.parent()
	}
	host := inclusive_ancestor_editing_host or { return false }

	// NOTE: Commands can define additional conditions for being enabled, and currently the only condition mentioned in
	//       the spec is that certain commands must not be enabled if the editing host is in the plaintext-only state.
	if host.is_html_element() && host.editing_host_is_plaintext_only() && lowercase_command in ['backcolor',
		'bold', 'createlink', 'fontname', 'fontsize', 'forecolor',
		'formatblock', // AD-HOC: https://github.com/w3c/editing/issues/478
		'hilitecolor', 'indent', 'inserthorizontalrule', 'insertimage', 'insertorderedlist',
		'insertunorderedlist', 'italic', 'justifycenter', 'justifyfull', 'justifyleft', 'justifyright',
		'outdent', 'removeformat', 'strikethrough', 'subscript', 'superscript', 'underline', 'unlink'] {
		return false
	}

	return true
}

// https://w3c.github.io/editing/docs/execCommand/#querycommandindeterm()
pub fn query_command_indeterm(document &dom.Document, command string) !bool {
	// AD-HOC: This is not directly mentioned in the spec, but all major browsers limit editing API calls to HTML documents
	if !document.is_html_document() {
		return error('InvalidStateError: queryCommandIndeterm is only supported on HTML documents')
	}

	// 1. If command is not supported or has no indeterminacy, return false.
	definition := find_command_definition(command) or { return false }
	if definition.indeterminate == unsafe { nil } {
		// If a command has inline command activated values defined but nothing else defines when it is indeterminate,
		// it is indeterminate if among formattable nodes effectively contained in the active range, there is at least
		// one whose effective command value is one of the given values and at least one whose effective command value
		// is not one of the given values.
		if definition.inline_activated_values.len > 0 {
			mut has_at_least_one_match := false
			mut has_at_least_one_mismatch := false
			for descendant in nodes_effectively_contained_in_range(active_range(document)) {
				if !is_formattable_node(descendant) {
					continue
				}
				node_value := effective_command_value(descendant, definition.command) or { continue }
				if node_value in definition.inline_activated_values {
					has_at_least_one_match = true
				} else {
					has_at_least_one_mismatch = true
				}
				if has_at_least_one_match && has_at_least_one_mismatch {
					break
				}
			}
			return has_at_least_one_match && has_at_least_one_mismatch
		}
		return false
	}

	// 2. Return true if command is indeterminate, otherwise false.
	return definition.indeterminate(document)
}

// https://w3c.github.io/editing/docs/execCommand/#querycommandstate()
pub fn query_command_state(document &dom.Document, command string) !bool {
	// AD-HOC: This is not directly mentioned in the spec, but all major browsers limit editing API calls to HTML documents
	if !document.is_html_document() {
		return error('InvalidStateError: queryCommandState is only supported on HTML documents')
	}

	// 1. If command is not supported or has no state, return false.
	definition := find_command_definition(command) or { return false }
	state_override := document.command_state_override(definition.command)
	if definition.state == unsafe { nil } && state_override == none {
		// https://w3c.github.io/editing/docs/execCommand/#inline-command-activated-values
		// If a command has inline command activated values defined, its state is true if either no formattable node is
		// effectively contained in the active range, and the active range's start node's effective command value is one
		// of the given values;
		inline_values := definition.inline_activated_values
		if inline_values.len == 0 {
			return false
		}
		range_ := active_range(document) or { return false }
		formattable_nodes := nodes_effectively_contained_in_range(range_).filter(is_formattable_node(it))
		if formattable_nodes.len == 0 {
			return (effective_command_value(range_.start_container(), definition.command) or { '' }) in inline_values
		}

		// or if there is at least one formattable node effectively contained in the active range, and all of them have
		// an effective command value equal to one of the given values.
		return formattable_nodes.all((effective_command_value(it, definition.command) or { '' }) in inline_values)
	}

	// 2. If the state override for command is set, return it.
	if override_ := state_override {
		return override_
	}

	// 3. Return true if command's state is true, otherwise false.
	return definition.state(document)
}

// https://w3c.github.io/editing/docs/execCommand/#querycommandsupported()
pub fn query_command_supported(document &dom.Document, command string) !bool {
	// AD-HOC: This is not directly mentioned in the spec, but all major browsers limit editing API calls to HTML documents
	if !document.is_html_document() {
		return error('InvalidStateError: queryCommandSupported is only supported on HTML documents')
	}

	// When the queryCommandSupported(command) method on the Document interface is invoked, the user agent must return
	// true if command is supported and available within the current script on the current site, and false otherwise.
	// AD-HOC: Supported commands should have an action defined. Currently, ::preserveWhitespace does not have one.
	definition := find_command_definition(command) or { return false }
	return definition.action != unsafe { nil }
}

// https://w3c.github.io/editing/docs/execCommand/#querycommandvalue()
pub fn query_command_value(document &dom.Document, command string) !string {
	// AD-HOC: This is not directly mentioned in the spec, but all major browsers limit editing API calls to HTML documents
	if !document.is_html_document() {
		return error('InvalidStateError: queryCommandValue is only supported on HTML documents')
	}

	// 1. If command is not supported or has no value, return the empty string.
	definition := find_command_definition(command) or { return '' }
	if definition.value == unsafe { nil } {
		return ''
	}
	value_override := document.command_value_override(definition.command)

	// 2. If command is "fontSize" and its value override is set, convert the value override to an
	//    integer number of pixels and return the legacy font size for the result.
	if override_ := value_override {
		if definition.command == command_font_size {
			pixel_size := font_size_to_pixel_size(override_)
			return legacy_font_size(pixel_size.to_int())
		}

		// 3. If the value override for command is set, return it.
		return override_
	}

	// 4. Return command's value.
	return definition.value(document)
}
