// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/CommandNames.{h,cpp}.
module editing

pub const command_back_color = 'backColor'
pub const command_bold = 'bold'
pub const command_copy = 'copy'
pub const command_create_link = 'createLink'
pub const command_cut = 'cut'
pub const command_default_paragraph_separator = 'defaultParagraphSeparator'
pub const command_delete = 'delete'
pub const command_font_name = 'fontName'
pub const command_font_size = 'fontSize'
pub const command_fore_color = 'foreColor'
pub const command_format_block = 'formatBlock'
pub const command_forward_delete = 'forwardDelete'
pub const command_hilite_color = 'hiliteColor'
pub const command_indent = 'indent'
pub const command_insert_horizontal_rule = 'insertHorizontalRule'
pub const command_insert_html = 'insertHTML'
pub const command_insert_image = 'insertImage'
pub const command_insert_line_break = 'insertLineBreak'
pub const command_insert_ordered_list = 'insertOrderedList'
pub const command_insert_paragraph = 'insertParagraph'
pub const command_insert_text = 'insertText'
pub const command_insert_unordered_list = 'insertUnorderedList'
pub const command_italic = 'italic'
pub const command_justify_center = 'justifyCenter'
pub const command_justify_full = 'justifyFull'
pub const command_justify_left = 'justifyLeft'
pub const command_justify_right = 'justifyRight'
pub const command_outdent = 'outdent'
pub const command_paste = 'paste'
pub const command_preserve_whitespace = 'preserveWhitespace'
pub const command_redo = 'redo'
pub const command_remove_format = 'removeFormat'
pub const command_select_all = 'selectAll'
pub const command_strikethrough = 'strikethrough'
pub const command_style_with_css = 'styleWithCSS'
pub const command_subscript = 'subscript'
pub const command_superscript = 'superscript'
pub const command_underline = 'underline'
pub const command_undo = 'undo'
pub const command_unlink = 'unlink'
pub const command_use_css = 'useCSS'

// all_command_names preserves the upstream CommandNames.h enumeration order,
// including command names that currently have no command action.
pub fn all_command_names() []string {
	return [
		command_back_color,
		command_bold,
		command_copy,
		command_create_link,
		command_cut,
		command_default_paragraph_separator,
		command_delete,
		command_font_name,
		command_font_size,
		command_fore_color,
		command_format_block,
		command_forward_delete,
		command_hilite_color,
		command_indent,
		command_insert_horizontal_rule,
		command_insert_html,
		command_insert_image,
		command_insert_line_break,
		command_insert_ordered_list,
		command_insert_paragraph,
		command_insert_text,
		command_insert_unordered_list,
		command_italic,
		command_justify_center,
		command_justify_full,
		command_justify_left,
		command_justify_right,
		command_outdent,
		command_paste,
		command_preserve_whitespace,
		command_redo,
		command_remove_format,
		command_select_all,
		command_strikethrough,
		command_style_with_css,
		command_subscript,
		command_superscript,
		command_underline,
		command_undo,
		command_unlink,
		command_use_css,
	]
}

fn command_ascii_lowercase(input string) string {
	mut bytes := input.bytes()
	for index, character in bytes {
		if character >= `A` && character <= `Z` {
			bytes[index] = character + 0x20
		}
	}
	return bytes.bytestr()
}

pub fn canonical_command_name(input string) ?string {
	needle := command_ascii_lowercase(input)
	for command in all_command_names() {
		if command_ascii_lowercase(command) == needle {
			return command
		}
	}
	return none
}
