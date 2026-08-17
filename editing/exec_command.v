// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/ExecCommand.cpp and Document's editing API.
module editing

pub fn (mut document EditingDocument) exec_command(command string, show_ui bool, value string) !bool {
	_ = show_ui // The legacy showUI argument has no effect, as in upstream.
	if !document.is_html_document {
		return error('InvalidStateError: execCommand is only supported on HTML documents')
	}
	if document.inside_exec_command {
		return false
	}
	document.inside_exec_command = true
	defer {
		document.inside_exec_command = false
	}
	if !(document.query_command_enabled(command)!) {
		return false
	}
	definition := find_command_definition(command) or { return false }
	overrides := if definition.preserves_overrides {
		record_current_overrides(document)
	} else {
		[]RecordedOverride{}
	}
	old_markup := document.serialize_html()
	result := document.take_the_action_for_command(definition.command, value)
	if overrides.len > 0 && document.selection_collapsed() {
		restore_states_and_values(mut document, overrides)
	}
	if !result {
		return false
	}
	if old_markup != document.serialize_html() {
		document.input_events << InputRecord{
			input_type: definition.mapped_value
			data:       if definition.command == command_insert_text { value } else { none }
		}
	}
	return true
}

pub fn (document &EditingDocument) query_command_supported(command string) !bool {
	if !document.is_html_document {
		return error('InvalidStateError: queryCommandSupported is only supported on HTML documents')
	}
	definition := find_command_definition(command) or { return false }
	return definition.has_action
}

pub fn (document &EditingDocument) query_command_enabled(command string) !bool {
	if !document.is_html_document {
		return error('InvalidStateError: queryCommandEnabled is only supported on HTML documents')
	}
	if !(document.query_command_supported(command)!) {
		return false
	}
	canonical := canonical_command_name(command) or { return false }
	if canonical in [command_default_paragraph_separator, command_style_with_css, command_use_css] {
		return true
	}
	if canonical == command_select_all {
		// EditingDocument always owns a selection object. selectAll itself creates
		// the default empty block when the block list is empty.
		return true
	}
	if !document.editable || document.blocks.len == 0 {
		return false
	}
	if document.plaintext_only && canonical in rich_text_commands() {
		return false
	}
	return true
}

fn rich_text_commands() []string {
	return [command_back_color, command_bold, command_create_link, command_font_name,
		command_font_size, command_fore_color, command_format_block, command_hilite_color,
		command_indent, command_insert_horizontal_rule, command_insert_html, command_insert_image,
		command_insert_ordered_list, command_insert_unordered_list, command_italic,
		command_justify_center, command_justify_full, command_justify_left, command_justify_right,
		command_outdent, command_remove_format, command_strikethrough, command_subscript,
		command_superscript, command_underline, command_unlink]
}

pub fn (document &EditingDocument) query_command_state(command string) !bool {
	if !document.is_html_document {
		return error('InvalidStateError: queryCommandState is only supported on HTML documents')
	}
	definition := find_command_definition(command) or { return false }
	if !definition.has_action {
		return false
	}
	if override_ := document.command_state_overrides[definition.command] {
		return override_
	}
	return match definition.command {
		command_style_with_css {
			document.css_styling_flag
		}
		command_insert_ordered_list {
			document.all_selected_blocks_have_list(.ordered)
		}
		command_insert_unordered_list {
			document.all_selected_blocks_have_list(.unordered)
		}
		command_justify_left {
			document.all_selected_blocks_have_alignment(.left)
		}
		command_justify_center {
			document.all_selected_blocks_have_alignment(.center)
		}
		command_justify_right {
			document.all_selected_blocks_have_alignment(.right)
		}
		command_justify_full {
			document.all_selected_blocks_have_alignment(.justify)
		}
		command_bold {
			document.all_effective_values_match(command_bold, ['bold', '600', '700', '800', '900'])
		}
		command_italic {
			document.all_effective_values_match(command_italic, ['italic', 'oblique'])
		}
		command_underline {
			document.all_effective_values_match(command_underline, ['underline'])
		}
		command_strikethrough {
			document.all_effective_values_match(command_strikethrough, [
				'line-through',
			])
		}
		command_subscript {
			document.all_effective_values_match(command_subscript, ['subscript'])
		}
		command_superscript {
			document.all_effective_values_match(command_superscript, ['superscript'])
		}
		else {
			false
		}
	}
}

fn (document &EditingDocument) all_effective_values_match(command string, values []string) bool {
	effective := effective_command_values(document, command)
	return effective.len > 0 && effective.all(it in values)
}

fn (document &EditingDocument) all_selected_blocks_have_list(kind ListKind) bool {
	indices := document.selected_block_indices()
	return indices.len > 0 && indices.all(document.blocks[it].list_kind == kind)
}

fn (document &EditingDocument) all_selected_blocks_have_alignment(alignment JustifyAlignment) bool {
	indices := document.selected_block_indices()
	return indices.len > 0 && indices.all(document.blocks[it].alignment == alignment)
}

pub fn (document &EditingDocument) query_command_indeterm(command string) !bool {
	if !document.is_html_document {
		return error('InvalidStateError: queryCommandIndeterm is only supported on HTML documents')
	}
	definition := find_command_definition(command) or { return false }
	if !definition.has_indeterminate && definition.inline_activated_values.len == 0
		&& definition.command !in [command_back_color, command_font_name, command_fore_color, command_hilite_color] {
		return false
	}
	if definition.command in [command_insert_ordered_list, command_insert_unordered_list] {
		state := selections_list_state(document)
		return match definition.command {
			command_insert_ordered_list { state in [.mixed, .mixed_ol] }
			else { state in [.mixed, .mixed_ul] }
		}
	}
	if definition.command.starts_with('justify') {
		mut first := ?JustifyAlignment(none)
		for index in document.selected_block_indices() {
			if first_alignment := first {
				if first_alignment != document.blocks[index].alignment {
					return true
				}
			} else {
				first = document.blocks[index].alignment
			}
		}
		return false
	}
	if definition.command == command_format_block {
		first_tag := document.blocks[document.selection.start.block].tag
		return document.selected_block_indices().any(document.blocks[it].tag != first_tag)
	}
	values := effective_command_values(document, definition.command)
	if values.len < 2 {
		return false
	}
	if definition.command in [command_back_color, command_font_name, command_fore_color,
		command_hilite_color] {
		// Upstream compares the effective strings directly for standard inline
		// value commands. Equivalent CSS colors with distinct serializations are
		// still distinct for queryCommandIndeterm().
		return values[1..].any(it != values[0])
	}
	if !definition.has_indeterminate && definition.inline_activated_values.len > 0 {
		mut has_match := false
		mut has_mismatch := false
		for value in values {
			if value in definition.inline_activated_values {
				has_match = true
			} else {
				has_mismatch = true
			}
		}
		return has_match && has_mismatch
	}
	first_value := values[0]
	return values[1..].any(!values_are_equivalent(definition.command, first_value, it))
}

pub fn (document &EditingDocument) query_command_value(command string) !string {
	if !document.is_html_document {
		return error('InvalidStateError: queryCommandValue is only supported on HTML documents')
	}
	definition := find_command_definition(command) or { return '' }
	if override_ := document.command_value_overrides[definition.command] {
		if definition.command == command_font_size {
			return legacy_font_size(int(font_size_to_pixel_size(override_)))
		}
		return override_
	}
	// Commands such as bold, fontName, foreColor, and createLink have no value
	// callback in the upstream registry. Their effective value participates in
	// state/indeterminacy algorithms but queryCommandValue() must return empty.
	if !definition.has_value {
		return ''
	}
	return match definition.command {
		command_default_paragraph_separator {
			document.default_paragraph_separator
		}
		command_font_size {
			values := effective_command_values(document, definition.command)
			if values.len == 0 {
				''
			} else {
				legacy_font_size(int(font_size_to_pixel_size(values[0])))
			}
		}
		command_format_block {
			document.blocks[document.selection.start.block].tag
		}
		command_justify_left, command_justify_center, command_justify_right, command_justify_full {
			justify_alignment_to_string(document.blocks[document.selection.start.block].alignment)
		}
		else {
			values := effective_command_values(document, definition.command)
			if values.len == 0 {
				''
			} else {
				values[0]
			}
		}
	}
}

fn (mut document EditingDocument) take_the_action_for_command(command string, value string) bool {
	return match command {
		command_back_color, command_hilite_color, command_fore_color {
			resulting_value := normalized_color(value) or { return true }
			document.set_inline_value(command, resulting_value)
			true
		}
		command_bold, command_italic, command_underline, command_strikethrough {
			state := document.query_command_state(command) or { false }
			document.set_inline_bool(command, !state)
			true
		}
		command_create_link {
			if value == '' {
				false
			} else {
				document.set_inline_value(command_create_link, value)
				true
			}
		}
		command_default_paragraph_separator {
			separator := value.to_lower()
			if separator in ['p', 'div'] {
				document.default_paragraph_separator = separator
				true
			} else {
				false
			}
		}
		command_delete {
			document.delete_backward()
		}
		command_forward_delete {
			document.delete_forward()
		}
		command_font_name {
			document.set_inline_value(command_font_name, value)
			true
		}
		command_font_size {
			document.set_font_size(value)
		}
		command_format_block {
			tag := parse_format_block(value) or { return false }
			for block_index in document.selected_block_indices() {
				document.blocks[block_index].tag = tag
			}
			true
		}
		command_indent {
			for block_index in document.selected_block_indices() {
				document.blocks[block_index].indent++
			}
			true
		}
		command_outdent {
			for block_index in document.selected_block_indices() {
				if document.blocks[block_index].indent > 0 {
					document.blocks[block_index].indent--
				} else {
					document.blocks[block_index].list_kind = .none
				}
			}
			true
		}
		command_insert_horizontal_rule {
			document.insert_items([InlineItem{ kind: .horizontal_rule }])
			true
		}
		command_insert_html {
			if value != '' {
				document.insert_items([InlineItem{ kind: .html, data: value }])
			}
			true
		}
		command_insert_image {
			if value == '' {
				false
			} else {
				document.insert_items([InlineItem{ kind: .image, data: value }])
				true
			}
		}
		command_insert_line_break {
			document.insert_items([
				InlineItem{ kind: .line_break, style: document.insertion_style() },
			])
			true
		}
		command_insert_ordered_list {
			document.toggle_list(.ordered)
			true
		}
		command_insert_unordered_list {
			document.toggle_list(.unordered)
			true
		}
		command_insert_paragraph {
			document.split_paragraph()
			true
		}
		command_insert_text {
			document.insert_text(value)
			true
		}
		command_justify_left {
			document.justify(.left)
			true
		}
		command_justify_center {
			document.justify(.center)
			true
		}
		command_justify_right {
			document.justify(.right)
			true
		}
		command_justify_full {
			document.justify(.justify)
			true
		}
		command_remove_format {
			document.remove_format()
			true
		}
		command_select_all {
			document.select_all()
			true
		}
		command_style_with_css {
			document.css_styling_flag = value.to_lower() != 'false'
			true
		}
		command_use_css {
			document.css_styling_flag = value.to_lower() == 'false'
			true
		}
		command_subscript {
			state := document.query_command_state(command_subscript) or { false }
			document.set_script(if state { .normal } else { .subscript })
			true
		}
		command_superscript {
			state := document.query_command_state(command_superscript) or { false }
			document.set_script(if state { .normal } else { .superscript })
			true
		}
		command_unlink {
			document.unlink()
			true
		}
		else {
			false
		}
	}
}

fn (mut document EditingDocument) insert_text(value string) {
	// Upstream recursively invokes insertText for each UTF-16 code unit; newline
	// delegates to insertParagraph. V keeps scalar text intact while preserving
	// that observable newline behavior.
	parts := value.split('\n')
	for index, part in parts {
		if index > 0 {
			document.split_paragraph()
		}
		if part != '' {
			document.insert_items(text_items(part, document.insertion_style_with_overrides()))
		}
	}
}

fn (document &EditingDocument) insertion_style_with_overrides() InlineStyle {
	mut style := document.insertion_style()
	style.bold = document.command_state_overrides[command_bold] or { style.bold }
	style.italic = document.command_state_overrides[command_italic] or { style.italic }
	style.underline = document.command_state_overrides[command_underline] or { style.underline }
	style.strikethrough = document.command_state_overrides[command_strikethrough] or {
		style.strikethrough
	}
	if document.command_state_overrides[command_subscript] or { false } {
		style.script = .subscript
	} else if document.command_state_overrides[command_superscript] or { false } {
		style.script = .superscript
	}
	style.background = document.command_value_overrides[command_back_color] or { style.background }
	style.color = document.command_value_overrides[command_fore_color] or { style.color }
	style.font_name = document.command_value_overrides[command_font_name] or { style.font_name }
	style.font_size = document.command_value_overrides[command_font_size] or { style.font_size }
	style.link = document.command_value_overrides[command_create_link] or { style.link }
	return style
}

fn (mut document EditingDocument) delete_backward() bool {
	if document.delete_selection() {
		return true
	}
	point := document.selection.start
	if point.offset > 0 {
		document.blocks[point.block].items.delete(point.offset - 1)
		new_point := Boundary{point.block, point.offset - 1}
		document.selection = EditingRange{
			start: new_point
			end:   new_point
		}
		return true
	}
	if point.block > 0 {
		previous_length := document.blocks[point.block - 1].items.len
		current_items := document.blocks[point.block].items.clone()
		document.blocks[point.block - 1].items << current_items
		document.blocks.delete(point.block)
		new_point := Boundary{point.block - 1, previous_length}
		document.selection = EditingRange{
			start: new_point
			end:   new_point
		}
	}
	return true
}

fn (mut document EditingDocument) delete_forward() bool {
	if document.delete_selection() {
		return true
	}
	point := document.selection.start
	if point.offset < document.blocks[point.block].items.len {
		document.blocks[point.block].items.delete(point.offset)
		return true
	}
	if point.block + 1 < document.blocks.len {
		next_items := document.blocks[point.block + 1].items.clone()
		document.blocks[point.block].items << next_items
		document.blocks.delete(point.block + 1)
	}
	return true
}

fn (mut document EditingDocument) set_font_size(value string) bool {
	trimmed := value.trim(' \t\n\r\x0c')
	if trimmed == '' {
		return false
	}
	if !is_valid_font_size_floating_number(trimmed)
		&& (!trimmed.starts_with('+') || !is_valid_font_size_floating_number(trimmed[1..])) {
		return false
	}

	mut number_text := trimmed
	mut mode := 0
	if trimmed.starts_with('+') {
		number_text = trimmed[1..]
		mode = 1
	} else if trimmed.starts_with('-') {
		number_text = trimmed[1..]
		mode = -1
	}
	mut number := leading_non_negative_integer(number_text) or { return false }
	if mode == 1 {
		number += 3
	} else if mode == -1 {
		number = 3 - number
	}
	if number < 1 {
		number = 1
	} else if number > 7 {
		number = 7
	}
	document.set_inline_value(command_font_size, named_font_sizes()[number - 1])
	return true
}

fn is_valid_font_size_floating_number(input string) bool {
	mut position := 0
	if position < input.len && input[position] == `-` {
		position++
	}
	leading_start := position
	for position < input.len && input[position].is_digit() {
		position++
	}
	has_leading_digits := position > leading_start
	if position < input.len && input[position] == `.` {
		position++
		fraction_start := position
		for position < input.len && input[position].is_digit() {
			position++
		}
		if position == fraction_start {
			return false
		}
	} else if !has_leading_digits {
		return false
	}
	if position < input.len && input[position] in [`e`, `E`] {
		position++
		if position < input.len && input[position] in [`-`, `+`] {
			position++
		}
		exponent_start := position
		for position < input.len && input[position].is_digit() {
			position++
		}
		if position == exponent_start {
			return false
		}
	}
	return position == input.len
}

fn leading_non_negative_integer(input string) ?int {
	if input == '' || !input[0].is_digit() {
		return none
	}
	mut value := 0
	for character in input {
		if !character.is_digit() {
			break
		}
		value = value * 10 + int(character - `0`)
		if value > 7 {
			return 8
		}
	}
	return value
}

fn (mut document EditingDocument) toggle_list(kind ListKind) {
	indices := document.selected_block_indices()
	turn_off := indices.all(document.blocks[it].list_kind == kind)
	for block_index in indices {
		document.blocks[block_index].list_kind = if turn_off { .none } else { kind }
	}
}

fn (mut document EditingDocument) justify(alignment JustifyAlignment) {
	for block_index in document.selected_block_indices() {
		document.blocks[block_index].alignment = alignment
	}
}

fn clear_item_format(mut item InlineItem) {
	// removeFormat does not unlink anchors.
	item.style = InlineStyle{
		link: item.style.link
	}
}

fn clear_item_link(mut item InlineItem) {
	item.style.link = ''
}

fn (mut document EditingDocument) remove_format() {
	if document.selection_collapsed() {
		link_override := document.command_value_overrides[command_create_link] or { '' }
		document.command_state_overrides.clear()
		document.command_value_overrides.clear()
		if link_override != '' {
			document.command_value_overrides[command_create_link] = link_override
		}
		return
	}
	document.for_each_selected_item(clear_item_format)
}

fn (mut document EditingDocument) unlink() {
	if document.selection_collapsed() {
		point := document.selection.start
		if point.offset > 0 {
			document.blocks[point.block].items[point.offset - 1].style.link = ''
		} else if point.offset < document.blocks[point.block].items.len {
			document.blocks[point.block].items[point.offset].style.link = ''
		}
		return
	}
	document.for_each_selected_item(clear_item_link)
}
