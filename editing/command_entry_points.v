// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Upstream Commands.cpp exposes one callback per command definition. The V
// command registry stores the shared dispatch in EditingDocument; these
// entry-points preserve the upstream surface while routing every command
// through that single implementation.
module editing

fn run_command_action(mut document EditingDocument, command string, value string) bool {
	return document.take_the_action_for_command(command, value)
}

pub fn command_back_color_action(mut document EditingDocument, value string) bool {
	return run_command_action(mut document, command_back_color, value)
}

pub fn command_bold_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_bold, '')
}

pub fn command_create_link_action(mut document EditingDocument, value string) bool {
	return run_command_action(mut document, command_create_link, value)
}

pub fn command_default_paragraph_separator_action(mut document EditingDocument, value string) bool {
	return run_command_action(mut document, command_default_paragraph_separator, value)
}

pub fn command_default_paragraph_separator_value(document &EditingDocument) string {
	return document.default_paragraph_separator
}

pub fn command_delete_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_delete, '')
}

pub fn command_font_name_action(mut document EditingDocument, value string) bool {
	return run_command_action(mut document, command_font_name, value)
}

pub fn command_font_size_action(mut document EditingDocument, value string) bool {
	return run_command_action(mut document, command_font_size, value)
}

pub fn command_font_size_value(document &EditingDocument) string {
	return document.query_command_value(command_font_size) or { '' }
}

pub fn command_fore_color_action(mut document EditingDocument, value string) bool {
	return run_command_action(mut document, command_fore_color, value)
}

pub fn command_format_block_action(mut document EditingDocument, value string) bool {
	return run_command_action(mut document, command_format_block, value)
}

pub fn command_format_block_indeterminate(document &EditingDocument) bool {
	return document.query_command_indeterm(command_format_block) or { false }
}

pub fn command_format_block_value(document &EditingDocument) string {
	return document.query_command_value(command_format_block) or { '' }
}

pub fn command_forward_delete_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_forward_delete, '')
}

pub fn command_indent_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_indent, '')
}

pub fn command_insert_horizontal_rule_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_insert_horizontal_rule, '')
}

pub fn command_insert_html_action(mut document EditingDocument, value string) bool {
	return run_command_action(mut document, command_insert_html, value)
}

pub fn command_insert_image_action(mut document EditingDocument, value string) bool {
	return run_command_action(mut document, command_insert_image, value)
}

pub fn command_insert_linebreak_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_insert_line_break, '')
}

pub fn command_insert_ordered_list_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_insert_ordered_list, '')
}

pub fn command_insert_ordered_list_indeterminate(document &EditingDocument) bool {
	return document.query_command_indeterm(command_insert_ordered_list) or { false }
}

pub fn command_insert_ordered_list_state(document &EditingDocument) bool {
	return document.query_command_state(command_insert_ordered_list) or { false }
}

pub fn command_insert_paragraph_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_insert_paragraph, '')
}

pub fn command_insert_text_action(mut document EditingDocument, value string) bool {
	return run_command_action(mut document, command_insert_text, value)
}

pub fn command_insert_unordered_list_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_insert_unordered_list, '')
}

pub fn command_insert_unordered_list_indeterminate(document &EditingDocument) bool {
	return document.query_command_indeterm(command_insert_unordered_list) or { false }
}

pub fn command_insert_unordered_list_state(document &EditingDocument) bool {
	return document.query_command_state(command_insert_unordered_list) or { false }
}

pub fn command_italic_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_italic, '')
}

pub fn justify_indeterminate(document &EditingDocument, alignment JustifyAlignment) bool {
	indices := document.selected_block_indices()
	if indices.len == 0 {
		return false
	}
	return indices.any(document.blocks[it].alignment == alignment)
		&& indices.any(document.blocks[it].alignment != alignment)
}

pub fn justify_state(document &EditingDocument, alignment JustifyAlignment) bool {
	indices := document.selected_block_indices()
	return indices.len > 0 && indices.all(document.blocks[it].alignment == alignment)
}

pub fn justify_value(document &EditingDocument) string {
	indices := document.selected_block_indices()
	if indices.len == 0 {
		return ''
	}
	return justify_alignment_to_string(document.blocks[indices[0]].alignment)
}

pub fn command_justify_center_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_justify_center, '')
}

pub fn command_justify_center_indeterminate(document &EditingDocument) bool {
	return justify_indeterminate(document, .center)
}

pub fn command_justify_center_state(document &EditingDocument) bool {
	return justify_state(document, .center)
}

pub fn command_justify_center_value(document &EditingDocument) string {
	return justify_value(document)
}

pub fn command_justify_full_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_justify_full, '')
}

pub fn command_justify_full_indeterminate(document &EditingDocument) bool {
	return justify_indeterminate(document, .justify)
}

pub fn command_justify_full_state(document &EditingDocument) bool {
	return justify_state(document, .justify)
}

pub fn command_justify_full_value(document &EditingDocument) string {
	return justify_value(document)
}

pub fn command_justify_left_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_justify_left, '')
}

pub fn command_justify_left_indeterminate(document &EditingDocument) bool {
	return justify_indeterminate(document, .left)
}

pub fn command_justify_left_state(document &EditingDocument) bool {
	return justify_state(document, .left)
}

pub fn command_justify_left_value(document &EditingDocument) string {
	return justify_value(document)
}

pub fn command_justify_right_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_justify_right, '')
}

pub fn command_justify_right_indeterminate(document &EditingDocument) bool {
	return justify_indeterminate(document, .right)
}

pub fn command_justify_right_state(document &EditingDocument) bool {
	return justify_state(document, .right)
}

pub fn command_justify_right_value(document &EditingDocument) string {
	return justify_value(document)
}

pub fn command_outdent_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_outdent, '')
}

pub fn command_remove_format_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_remove_format, '')
}

pub fn command_select_all_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_select_all, '')
}

pub fn command_strikethrough_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_strikethrough, '')
}

pub fn command_style_with_css_action(mut document EditingDocument, value string) bool {
	return run_command_action(mut document, command_style_with_css, value)
}

pub fn command_style_with_css_state(document &EditingDocument) bool {
	return document.css_styling_flag
}

pub fn command_subscript_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_subscript, '')
}

pub fn command_subscript_indeterminate(document &EditingDocument) bool {
	return document.query_command_indeterm(command_subscript) or { false }
}

pub fn command_superscript_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_superscript, '')
}

pub fn command_superscript_indeterminate(document &EditingDocument) bool {
	return document.query_command_indeterm(command_superscript) or { false }
}

pub fn command_underline_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_underline, '')
}

pub fn command_unlink_action(mut document EditingDocument, _ string) bool {
	return run_command_action(mut document, command_unlink, '')
}

pub fn command_use_css_action(mut document EditingDocument, value string) bool {
	return run_command_action(mut document, command_use_css, value)
}
