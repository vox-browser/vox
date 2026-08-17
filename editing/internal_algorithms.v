// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/Internal/Algorithms.{h,cpp}.
module editing

import color
import strconv

pub enum SelectionsListState {
	ol
	ul
	mixed
	mixed_ol
	mixed_ul
	none
}

pub struct RecordedNodeValue {
pub:
	block_index int
	item_index  int
	command     string
	value       ?string
}

pub struct RecordedOverride {
pub:
	command string
	value   string
	is_bool bool
}

pub fn canonical_space_sequence(length int, non_breaking_start bool, non_breaking_end bool) string {
	if length <= 0 {
		return ''
	}
	if length == 1 {
		return if non_breaking_start || non_breaking_end { '\u00a0' } else { ' ' }
	}
	mut remaining := length
	mut output := ''
	pair := if non_breaking_start { '\u00a0 ' } else { ' \u00a0' }
	for remaining > 2 {
		output += pair
		remaining -= 2
	}
	if remaining > 0 {
		output += if non_breaking_start { '\u00a0' } else { ' ' }
		remaining--
	}
	if remaining > 0 {
		output += if non_breaking_end { '\u00a0' } else { ' ' }
	}
	return output
}

pub fn canonicalize_whitespace_text(text string, non_breaking_start bool, non_breaking_end bool) string {
	mut output := ''
	mut whitespace_length := 0
	mut at_start := true
	for rune_ in text.runes() {
		if rune_ in [` `, `\t`, `\r`, `\n`, `\u00a0`] {
			whitespace_length++
			continue
		}
		if whitespace_length > 0 {
			output += canonical_space_sequence(whitespace_length, at_start && non_breaking_start,
				false)
			whitespace_length = 0
		}
		output += rune_.str()
		at_start = false
	}
	if whitespace_length > 0 {
		output += canonical_space_sequence(whitespace_length, at_start && non_breaking_start,
			non_breaking_end)
	}
	return output
}

pub fn is_formattable_block_name(local_name string) bool {
	return local_name.to_lower() in ['address', 'dd', 'div', 'dt', 'h1', 'h2', 'h3', 'h4', 'h5',
		'h6', 'p', 'pre']
}

pub fn is_heading(local_name string) bool {
	return local_name.to_lower() in ['h1', 'h2', 'h3', 'h4', 'h5', 'h6']
}

pub fn is_name_of_an_element_with_inline_contents(local_name string) bool {
	return local_name.to_lower() in ['a', 'abbr', 'b', 'bdi', 'bdo', 'cite', 'code', 'dfn', 'em',
		'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'i', 'kbd', 'mark', 'p', 'pre', 'q', 'rp', 'rt', 'ruby',
		's', 'samp', 'small', 'span', 'strong', 'sub', 'sup', 'u', 'var', 'acronym', 'listing',
		'strike', 'xmp', 'big', 'blink', 'font', 'marquee', 'nobr', 'tt']
}

pub fn is_prohibited_paragraph_child_name(local_name string) bool {
	return local_name.to_lower() in ['address', 'article', 'aside', 'blockquote', 'caption', 'center',
		'col', 'colgroup', 'dd', 'details', 'dir', 'div', 'dl', 'dt', 'fieldset', 'figcaption',
		'figure', 'footer', 'form', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'header', 'hgroup', 'hr',
		'li', 'listing', 'menu', 'nav', 'ol', 'p', 'plaintext', 'pre', 'section', 'summary', 'table',
		'tbody', 'td', 'tfoot', 'th', 'thead', 'tr', 'ul', 'xmp']
}

pub fn is_remove_format_candidate(local_name string) bool {
	return local_name.to_lower() in ['abbr', 'acronym', 'b', 'bdi', 'bdo', 'big', 'blink', 'cite',
		'code', 'dfn', 'em', 'font', 'i', 'ins', 'kbd', 'mark', 'nobr', 'q', 's', 'samp', 'small',
		'span', 'strike', 'strong', 'sub', 'sup', 'tt', 'u', 'var']
}

pub fn is_non_list_single_line_container(local_name string) bool {
	return is_heading(local_name)
		|| local_name.to_lower() in ['address', 'div', 'listing', 'p', 'pre', 'xmp']
}

pub fn is_single_line_container(local_name string) bool {
	return is_non_list_single_line_container(local_name)
		|| local_name.to_lower() in ['li', 'dt', 'dd']
}

pub fn named_font_sizes() []string {
	return ['x-small', 'small', 'medium', 'large', 'x-large', 'xx-large', 'xxx-large']
}

pub fn font_size_to_pixel_size(font_size string) f64 {
	value := font_size.trim_space().to_lower()
	if value.ends_with('px') {
		if parsed := strconv.atof64(value[..value.len - 2]) {
			return parsed
		}
	}
	legacy := {
		'1':         10.0
		'2':         13.0
		'3':         16.0
		'4':         18.0
		'5':         24.0
		'6':         32.0
		'7':         48.0
		'x-small':   10.0
		'small':     13.0
		'medium':    16.0
		'large':     18.0
		'x-large':   24.0
		'xx-large':  32.0
		'xxx-large': 48.0
	}
	return legacy[value] or { 16.0 }
}

pub fn legacy_font_size(pixel_size int) string {
	for index := 1; index < 7; index++ {
		lower := font_size_to_pixel_size(index.str())
		upper := font_size_to_pixel_size((index + 1).str())
		if f64(pixel_size) < (lower + upper) / 2.0 {
			return index.str()
		}
	}
	return '7'
}

pub fn justify_alignment_to_string(alignment JustifyAlignment) string {
	return match alignment {
		.left { 'left' }
		.center { 'center' }
		.right { 'right' }
		.justify { 'justify' }
	}
}

pub fn values_are_equivalent(command string, a ?string, b ?string) bool {
	left := a or { return b == none }
	right := b or { return false }
	canonical := canonical_command_name(command) or { command }
	if canonical in [command_back_color, command_fore_color, command_hilite_color] {
		left_color := color.from_string(left)
		right_color := color.from_string(right)
		if left_color == none {
			return right_color == none
		}
		right_color_value := right_color or { return false }
		return left_color == right_color_value
	}
	if canonical == command_bold {
		if left == right {
			return true
		}
		return (left in ['bold', '700'] && right in ['bold', '700'])
			|| (left in ['normal', '400'] && right in ['normal', '400'])
	}
	return left == right
}

pub fn values_are_loosely_equivalent(command string, a ?string, b ?string) bool {
	if values_are_equivalent(command, a, b) {
		return true
	}
	if command.to_lower() != command_font_size.to_lower() {
		return false
	}
	left := a or { return false }
	right := b or { return false }
	return font_size_index(left) >= 0 && font_size_index(left) == font_size_index(right)
}

fn font_size_index(value string) int {
	named := named_font_sizes()
	if value in named {
		return named.index(value)
	}
	if value in ['1', '2', '3', '4', '5', '6', '7'] {
		return value.int() - 1
	}
	return -1
}

pub fn selections_list_state(document &EditingDocument) SelectionsListState {
	mut ordered := 0
	mut unordered := 0
	mut neither := 0
	for block_index in document.selected_block_indices() {
		match document.blocks[block_index].list_kind {
			.ordered { ordered++ }
			.unordered { unordered++ }
			.none { neither++ }
		}
	}
	if ordered > 0 && unordered == 0 && neither == 0 {
		return .ol
	}
	if unordered > 0 && ordered == 0 && neither == 0 {
		return .ul
	}
	if ordered > 0 && unordered > 0 && neither == 0 {
		return .mixed
	}
	if ordered > 0 && (unordered > 0 || neither > 0) {
		return .mixed_ol
	}
	if unordered > 0 && neither > 0 {
		return .mixed_ul
	}
	return .none
}

pub fn record_current_overrides(document &EditingDocument) []RecordedOverride {
	mut result := []RecordedOverride{}
	if value := document.command_value_overrides[command_create_link] {
		result << RecordedOverride{
			command: command_create_link
			value:   value
		}
	}
	for command in [command_bold, command_italic, command_strikethrough, command_subscript,
		command_superscript, command_underline] {
		if state := document.command_state_overrides[command] {
			result << RecordedOverride{
				command: command
				value:   state.str()
				is_bool: true
			}
		}
	}
	for command in [command_font_name, command_font_size, command_fore_color, command_hilite_color] {
		if value := document.command_value_overrides[command] {
			result << RecordedOverride{
				command: command
				value:   value
			}
		}
	}
	return result
}

pub fn restore_states_and_values(mut document EditingDocument, overrides []RecordedOverride) {
	for override_ in overrides {
		if override_.is_bool {
			document.command_state_overrides[override_.command] = override_.value.bool()
		} else {
			document.set_value_override(override_.command, override_.value)
		}
	}
}

pub fn record_the_values_of_selection(document &EditingDocument, command string) []RecordedNodeValue {
	mut values := []RecordedNodeValue{}
	start := document.selection.start
	end := document.selection.end
	for block_index := start.block; block_index <= end.block; block_index++ {
		from := if block_index == start.block { start.offset } else { 0 }
		to := if block_index == end.block {
			end.offset
		} else {
			document.blocks[block_index].items.len
		}
		for item_index := from; item_index < to; item_index++ {
			if document.blocks[block_index].items[item_index].kind !in [.text, .line_break, .image] {
				continue
			}
			values << RecordedNodeValue{
				block_index: block_index
				item_index:  item_index
				command:     command
				value:       effective_item_value(document.blocks[block_index].items[item_index],
					command)
			}
		}
	}
	return values
}

// Typed EditingDocument counterpart of restore_the_values_of_nodes(). Invalid
// coordinates are ignored because an earlier DOM mutation may have removed a
// recorded node, matching the upstream algorithm's live-node behavior.
pub fn restore_the_values_of_selection(mut document EditingDocument, values []RecordedNodeValue) {
	for recorded in values {
		if recorded.block_index < 0 || recorded.block_index >= document.blocks.len {
			continue
		}
		if recorded.item_index < 0
			|| recorded.item_index >= document.blocks[recorded.block_index].items.len {
			continue
		}
		mut item := &document.blocks[recorded.block_index].items[recorded.item_index]
		restore_item_value(mut item, recorded.command, recorded.value)
	}
}

fn restore_item_value(mut item InlineItem, command string, value ?string) {
	actual := value or { '' }
	match command {
		command_bold {
			item.style.bold = actual in ['bold', '600', '700', '800', '900']
		}
		command_italic {
			item.style.italic = actual in ['italic', 'oblique']
		}
		command_underline {
			item.style.underline = actual == 'underline'
		}
		command_strikethrough {
			item.style.strikethrough = actual == 'line-through'
		}
		command_subscript {
			if actual == 'subscript' {
				item.style.script = .subscript
			} else if item.style.script == .subscript {
				item.style.script = .normal
			}
		}
		command_superscript {
			if actual == 'superscript' {
				item.style.script = .superscript
			} else if item.style.script == .superscript {
				item.style.script = .normal
			}
		}
		command_fore_color {
			item.style.color = actual
		}
		command_back_color, command_hilite_color {
			item.style.background = actual
		}
		command_font_name {
			item.style.font_name = actual
		}
		command_font_size {
			item.style.font_size = actual
		}
		command_create_link {
			item.style.link = actual
		}
		else {}
	}
}

fn effective_item_value(item InlineItem, command string) ?string {
	return match command {
		command_bold {
			if item.style.bold {
				'bold'
			} else {
				'normal'
			}
		}
		command_italic {
			if item.style.italic {
				'italic'
			} else {
				'normal'
			}
		}
		command_underline {
			if item.style.underline {
				'underline'
			} else {
				'none'
			}
		}
		command_strikethrough {
			if item.style.strikethrough {
				'line-through'
			} else {
				'none'
			}
		}
		command_subscript {
			if item.style.script == .subscript {
				'subscript'
			} else {
				'baseline'
			}
		}
		command_superscript {
			if item.style.script == .superscript {
				'superscript'
			} else {
				'baseline'
			}
		}
		command_fore_color {
			if item.style.color == '' {
				none
			} else {
				item.style.color
			}
		}
		command_back_color, command_hilite_color {
			if item.style.background == '' {
				none
			} else {
				item.style.background
			}
		}
		command_font_name {
			if item.style.font_name == '' {
				none
			} else {
				item.style.font_name
			}
		}
		command_font_size {
			if item.style.font_size == '' {
				none
			} else {
				item.style.font_size
			}
		}
		command_create_link {
			if item.style.link == '' {
				none
			} else {
				item.style.link
			}
		}
		else {
			none
		}
	}
}

pub fn effective_command_values(document &EditingDocument, command string) []string {
	mut result := []string{}
	for item in document.selected_items() {
		if item.kind !in [.text, .line_break, .image] {
			continue
		}
		if value := effective_item_value(item, command) {
			result << value
		}
	}
	if result.len == 0 && document.selection_collapsed() {
		style := document.insertion_style()
		if value := effective_item_value(InlineItem{ style: style }, command) {
			result << value
		}
	}
	return result
}
