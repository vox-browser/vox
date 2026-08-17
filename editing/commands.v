// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Editing/Commands.{h,cpp}.
module editing

import color
import strings

pub enum InlineItemKind {
	text
	line_break
	horizontal_rule
	image
	html
}

pub enum ScriptPosition {
	normal
	subscript
	superscript
}

pub enum ListKind {
	none
	ordered
	unordered
}

pub enum JustifyAlignment {
	left
	center
	right
	justify
}

pub struct InlineStyle {
pub mut:
	bold          bool
	italic        bool
	underline     bool
	strikethrough bool
	script        ScriptPosition
	color         string
	background    string
	font_name     string
	font_size     string
	link          string
}

pub struct InlineItem {
pub mut:
	kind  InlineItemKind
	data  string
	style InlineStyle
}

pub struct Block {
pub mut:
	tag       string = 'div'
	items     []InlineItem
	alignment JustifyAlignment
	list_kind ListKind
	indent    int
}

pub struct Boundary {
pub:
	block  int
	offset int
}

pub struct EditingRange {
pub:
	start Boundary
	end   Boundary
}

pub struct InputRecord {
pub:
	input_type string
	data       ?string
}

// EditingDocument is the V translation's editing-host model. Its blocks are
// DOM editing hosts' single-line containers and its InlineItems are editable
// text/replaced nodes. Keeping selection boundaries in this typed model lets
// the port implement the specified mutations without importing dom (which
// would form a package cycle with Document's editing entry points).
@[heap]
pub struct EditingDocument {
pub mut:
	is_html_document            bool = true
	editable                    bool = true
	plaintext_only              bool
	css_styling_flag            bool
	default_paragraph_separator string  = 'div'
	blocks                      []Block = [Block{}]
	selection                   EditingRange
	command_state_overrides     map[string]bool
	command_value_overrides     map[string]string
	input_events                []InputRecord
mut:
	inside_exec_command bool
}

pub fn new_document(text string) &EditingDocument {
	mut document := &EditingDocument{}
	document.blocks =
		blocks_from_plain_text(text, document.default_paragraph_separator, InlineStyle{})
	document.selection = EditingRange{
		start: Boundary{0, 0}
		end:   Boundary{0, 0}
	}
	return document
}

fn blocks_from_plain_text(text string, tag string, style InlineStyle) []Block {
	lines := text.split_into_lines()
	mut blocks := []Block{cap: if lines.len == 0 { 1 } else { lines.len }}
	if lines.len == 0 {
		return [Block{ tag: tag }]
	}
	for line in lines {
		blocks << Block{
			tag:   tag
			items: text_items(line, style)
		}
	}
	return blocks
}

fn text_items(text string, style InlineStyle) []InlineItem {
	mut items := []InlineItem{cap: text.runes().len}
	for character in text.runes() {
		items << InlineItem{
			kind:  .text
			data:  character.str()
			style: style
		}
	}
	return items
}

pub fn (document &EditingDocument) plain_text() string {
	mut output := strings.new_builder(64)
	for block_index, block in document.blocks {
		if block_index > 0 {
			output.write_u8(`\n`)
		}
		for item in block.items {
			match item.kind {
				.text, .html { output.write_string(item.data) }
				.line_break { output.write_u8(`\n`) }
				.image { output.write_string('\uFFFC') }
				.horizontal_rule { output.write_string('\u2015') }
			}
		}
	}
	return output.str()
}

pub fn (document &EditingDocument) serialize_html() string {
	mut output := strings.new_builder(128)
	for block in document.blocks {
		list_tag := match block.list_kind {
			.ordered { 'ol' }
			.unordered { 'ul' }
			.none { '' }
		}
		block_style := serialize_block_style(block)
		if list_tag != '' {
			output.write_string('<${list_tag}><li${block_style}>')
		} else {
			output.write_string('<${block.tag}${block_style}>')
		}
		for item in block.items {
			output.write_string(serialize_item(item))
		}
		if list_tag != '' {
			output.write_string('</li></${list_tag}>')
		} else {
			output.write_string('</${block.tag}>')
		}
	}
	return output.str()
}

fn serialize_block_style(block Block) string {
	mut declarations := []string{}
	if block.alignment != .left {
		declarations << 'text-align:${justify_alignment_to_string(block.alignment)}'
	}
	if block.indent > 0 {
		declarations << 'margin-left:${block.indent * 40}px'
	}
	if declarations.len == 0 {
		return ''
	}
	return ' style="${declarations.join(';')}"'
}

fn serialize_item(item InlineItem) string {
	mut body := match item.kind {
		.text { escape_html(item.data) }
		.line_break { '<br>' }
		.horizontal_rule { '<hr>' }
		.image { '<img src="${escape_attribute(item.data)}">' }
		.html { item.data }
	}
	if item.kind !in [.text, .html] {
		return body
	}
	style := item.style
	if style.link != '' {
		body = '<a href="${escape_attribute(style.link)}">${body}</a>'
	}
	if style.script == .subscript {
		body = '<sub>${body}</sub>'
	} else if style.script == .superscript {
		body = '<sup>${body}</sup>'
	}
	if style.strikethrough {
		body = '<s>${body}</s>'
	}
	if style.underline {
		body = '<u>${body}</u>'
	}
	if style.italic {
		body = '<i>${body}</i>'
	}
	if style.bold {
		body = '<b>${body}</b>'
	}
	mut declarations := []string{}
	if style.color != '' {
		declarations << 'color:${style.color}'
	}
	if style.background != '' {
		declarations << 'background-color:${style.background}'
	}
	if style.font_name != '' {
		declarations << 'font-family:${style.font_name}'
	}
	if style.font_size != '' {
		declarations << 'font-size:${style.font_size}'
	}
	if declarations.len > 0 {
		body = '<span style="${declarations.join(';')}">${body}</span>'
	}
	return body
}

fn escape_html(input string) string {
	return input.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
}

fn escape_attribute(input string) string {
	return escape_html(input).replace('"', '&quot;')
}

pub fn (mut document EditingDocument) set_selection(start Boundary, end Boundary) ! {
	start_checked := document.checked_boundary(start)!
	end_checked := document.checked_boundary(end)!
	if boundary_less(end_checked, start_checked) {
		document.selection = EditingRange{
			start: end_checked
			end:   start_checked
		}
	} else {
		document.selection = EditingRange{
			start: start_checked
			end:   end_checked
		}
	}
	document.reset_overrides()
}

fn (document &EditingDocument) checked_boundary(boundary Boundary) !Boundary {
	if boundary.block < 0 || boundary.block >= document.blocks.len {
		return error('IndexSizeError: block index is out of range')
	}
	if boundary.offset < 0 || boundary.offset > document.blocks[boundary.block].items.len {
		return error('IndexSizeError: item offset is out of range')
	}
	return boundary
}

fn boundary_less(a Boundary, b Boundary) bool {
	return a.block < b.block || (a.block == b.block && a.offset < b.offset)
}

pub fn (document &EditingDocument) selection_collapsed() bool {
	return document.selection.start == document.selection.end
}

pub fn (mut document EditingDocument) collapse(boundary Boundary) ! {
	checked := document.checked_boundary(boundary)!
	document.selection = EditingRange{
		start: checked
		end:   checked
	}
	document.reset_overrides()
}

pub fn (mut document EditingDocument) select_all() {
	if document.blocks.len == 0 {
		document.blocks << Block{
			tag: document.default_paragraph_separator
		}
	}
	document.selection = EditingRange{
		start: Boundary{0, 0}
		end:   Boundary{document.blocks.len - 1, document.blocks.last().items.len}
	}
	document.reset_overrides()
}

fn (mut document EditingDocument) reset_overrides() {
	document.command_state_overrides.clear()
	document.command_value_overrides.clear()
}

fn (mut document EditingDocument) delete_selection() bool {
	if document.selection_collapsed() {
		return false
	}
	start := document.selection.start
	end := document.selection.end
	if start.block == end.block {
		document.blocks[start.block].items.delete_many(start.offset, end.offset - start.offset)
	} else {
		left := document.blocks[start.block].items[..start.offset].clone()
		right := document.blocks[end.block].items[end.offset..].clone()
		document.blocks[start.block].items = left
		document.blocks[start.block].items << right
		document.blocks.delete_many(start.block + 1, end.block - start.block)
	}
	document.selection = EditingRange{
		start: start
		end:   start
	}
	return true
}

fn (mut document EditingDocument) insert_items(items []InlineItem) {
	document.delete_selection()
	point := document.selection.start
	mut block := &document.blocks[point.block]
	mut result := []InlineItem{cap: block.items.len + items.len}
	result << block.items[..point.offset]
	result << items
	result << block.items[point.offset..]
	block.items = result
	new_point := Boundary{point.block, point.offset + items.len}
	document.selection = EditingRange{
		start: new_point
		end:   new_point
	}
}

fn (document &EditingDocument) insertion_style() InlineStyle {
	if document.selection_collapsed() {
		point := document.selection.start
		block := document.blocks[point.block]
		if point.offset > 0 {
			return block.items[point.offset - 1].style
		}
		if point.offset < block.items.len {
			return block.items[point.offset].style
		}
	}
	return InlineStyle{}
}

fn (mut document EditingDocument) for_each_selected_item(callback fn (mut InlineItem)) {
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
			callback(mut document.blocks[block_index].items[item_index])
		}
	}
}

fn (document &EditingDocument) selected_items() []InlineItem {
	start := document.selection.start
	end := document.selection.end
	mut result := []InlineItem{}
	for block_index := start.block; block_index <= end.block; block_index++ {
		from := if block_index == start.block { start.offset } else { 0 }
		to := if block_index == end.block {
			end.offset
		} else {
			document.blocks[block_index].items.len
		}
		result << document.blocks[block_index].items[from..to]
	}
	return result
}

fn (document &EditingDocument) selected_block_indices() []int {
	mut indices := []int{}
	for block_index := document.selection.start.block; block_index <= document.selection.end.block; block_index++ {
		indices << block_index
	}
	return indices
}

fn (mut document EditingDocument) set_inline_bool(command string, enabled bool) {
	if document.selection_collapsed() {
		document.command_state_overrides[command] = enabled
		return
	}
	match command {
		command_bold {
			document.for_each_selected_item(fn [enabled] (mut item InlineItem) {
				item.style.bold = enabled
			})
		}
		command_italic {
			document.for_each_selected_item(fn [enabled] (mut item InlineItem) {
				item.style.italic = enabled
			})
		}
		command_underline {
			document.for_each_selected_item(fn [enabled] (mut item InlineItem) {
				item.style.underline = enabled
			})
		}
		command_strikethrough {
			document.for_each_selected_item(fn [enabled] (mut item InlineItem) {
				item.style.strikethrough = enabled
			})
		}
		else {}
	}
}

fn (mut document EditingDocument) set_script(position ScriptPosition) {
	if document.selection_collapsed() {
		document.command_state_overrides[command_subscript] = position == .subscript
		document.command_state_overrides[command_superscript] = position == .superscript
		return
	}
	document.for_each_selected_item(fn [position] (mut item InlineItem) {
		item.style.script = position
	})
}

fn (mut document EditingDocument) set_inline_value(command string, value string) {
	if document.selection_collapsed() {
		document.set_value_override(command, value)
		return
	}
	match command {
		command_back_color, command_hilite_color {
			document.for_each_selected_item(fn [value] (mut item InlineItem) {
				item.style.background = value
			})
		}
		command_fore_color {
			document.for_each_selected_item(fn [value] (mut item InlineItem) {
				item.style.color = value
			})
		}
		command_font_name {
			document.for_each_selected_item(fn [value] (mut item InlineItem) {
				item.style.font_name = value
			})
		}
		command_font_size {
			document.for_each_selected_item(fn [value] (mut item InlineItem) {
				item.style.font_size = value
			})
		}
		command_create_link {
			document.for_each_selected_item(fn [value] (mut item InlineItem) {
				item.style.link = value
			})
		}
		else {}
	}
}

fn (mut document EditingDocument) set_value_override(command string, value string) {
	document.command_value_overrides[command] = value
	if command == command_back_color {
		document.command_value_overrides[command_hilite_color] = value
	} else if command == command_hilite_color {
		document.command_value_overrides[command_back_color] = value
	}
}

fn (mut document EditingDocument) split_paragraph() {
	document.delete_selection()
	point := document.selection.start
	old := document.blocks[point.block]
	left := old.items[..point.offset].clone()
	right := old.items[point.offset..].clone()
	document.blocks[point.block].items = left
	new_block := Block{
		tag:       old.tag
		items:     right
		alignment: old.alignment
		list_kind: old.list_kind
		indent:    old.indent
	}
	document.blocks.insert(point.block + 1, new_block)
	new_point := Boundary{point.block + 1, 0}
	document.selection = EditingRange{
		start: new_point
		end:   new_point
	}
}

pub struct CommandDefinition {
pub:
	command                 string
	relevant_css_property   string
	preserves_overrides     bool
	inline_activated_values []string
	mapped_value            string
	has_action              bool = true
	has_state               bool
	has_value               bool
	has_indeterminate       bool
}

pub fn command_definitions() []CommandDefinition {
	return [
		CommandDefinition{
			command:               command_back_color
			relevant_css_property: 'background-color'
			mapped_value:          'formatBackColor'
		},
		CommandDefinition{
			command:                 command_bold
			relevant_css_property:   'font-weight'
			inline_activated_values: ['bold', '600', '700', '800', '900']
			mapped_value:            'formatBold'
		},
		CommandDefinition{
			command:      command_create_link
			mapped_value: 'insertLink'
		},
		CommandDefinition{
			command:             command_delete
			preserves_overrides: true
			mapped_value:        'deleteContentBackward'
		},
		CommandDefinition{
			command:   command_default_paragraph_separator
			has_value: true
		},
		CommandDefinition{
			command:               command_font_name
			relevant_css_property: 'font-family'
			mapped_value:          'formatFontName'
		},
		CommandDefinition{
			command:               command_font_size
			relevant_css_property: 'font-size'
			has_value:             true
		},
		CommandDefinition{
			command:               command_fore_color
			relevant_css_property: 'color'
			mapped_value:          'formatFontColor'
		},
		CommandDefinition{
			command:             command_format_block
			has_indeterminate:   true
			has_value:           true
			preserves_overrides: true
		},
		CommandDefinition{
			command:             command_forward_delete
			preserves_overrides: true
			mapped_value:        'deleteContentForward'
		},
		CommandDefinition{
			command:               command_hilite_color
			relevant_css_property: 'background-color'
		},
		CommandDefinition{
			command:             command_indent
			preserves_overrides: true
			mapped_value:        'formatIndent'
		},
		CommandDefinition{
			command:             command_insert_horizontal_rule
			preserves_overrides: true
			mapped_value:        'insertHorizontalRule'
		},
		CommandDefinition{
			command:             command_insert_html
			preserves_overrides: true
		},
		CommandDefinition{
			command:             command_insert_image
			preserves_overrides: true
		},
		CommandDefinition{
			command:             command_insert_line_break
			preserves_overrides: true
			mapped_value:        'insertLineBreak'
		},
		CommandDefinition{
			command:             command_insert_ordered_list
			has_indeterminate:   true
			has_state:           true
			preserves_overrides: true
			mapped_value:        'insertOrderedList'
		},
		CommandDefinition{
			command:             command_insert_paragraph
			preserves_overrides: true
			mapped_value:        'insertParagraph'
		},
		CommandDefinition{
			command:      command_insert_text
			mapped_value: 'insertText'
		},
		CommandDefinition{
			command:             command_insert_unordered_list
			has_indeterminate:   true
			has_state:           true
			preserves_overrides: true
			mapped_value:        'insertUnorderedList'
		},
		CommandDefinition{
			command:                 command_italic
			relevant_css_property:   'font-style'
			inline_activated_values: ['italic', 'oblique']
		},
		CommandDefinition{
			command:             command_justify_center
			has_indeterminate:   true
			has_state:           true
			has_value:           true
			preserves_overrides: true
			mapped_value:        'formatJustifyCenter'
		},
		CommandDefinition{
			command:             command_justify_full
			has_indeterminate:   true
			has_state:           true
			has_value:           true
			preserves_overrides: true
			mapped_value:        'formatJustifyFull'
		},
		CommandDefinition{
			command:             command_justify_left
			has_indeterminate:   true
			has_state:           true
			has_value:           true
			preserves_overrides: true
			mapped_value:        'formatJustifyLeft'
		},
		CommandDefinition{
			command:             command_justify_right
			has_indeterminate:   true
			has_state:           true
			has_value:           true
			preserves_overrides: true
			mapped_value:        'formatJustifyRight'
		},
		CommandDefinition{
			command:             command_outdent
			preserves_overrides: true
			mapped_value:        'formatOutdent'
		},
		CommandDefinition{
			command:               command_preserve_whitespace
			relevant_css_property: 'white-space'
			has_action:            false
		},
		CommandDefinition{
			command: command_remove_format
		},
		CommandDefinition{
			command: command_select_all
		},
		CommandDefinition{
			command:                 command_strikethrough
			inline_activated_values: ['line-through']
			mapped_value:            'formatStrikeThrough'
		},
		CommandDefinition{
			command:   command_style_with_css
			has_state: true
		},
		CommandDefinition{
			command:                 command_subscript
			has_indeterminate:       true
			inline_activated_values: ['subscript']
		},
		CommandDefinition{
			command:                 command_superscript
			has_indeterminate:       true
			inline_activated_values: ['superscript']
			mapped_value:            'formatSuperscript'
		},
		CommandDefinition{
			command:                 command_underline
			inline_activated_values: ['underline']
		},
		CommandDefinition{
			command: command_unlink
		},
		CommandDefinition{
			command: command_use_css
		},
	]
}

pub fn find_command_definition(input string) ?CommandDefinition {
	canonical := canonical_command_name(input) or { return none }
	for definition in command_definitions() {
		if definition.command == canonical {
			return definition
		}
	}
	return none
}

fn normalized_color(value string) ?string {
	// Commands.cpp uses LibGfx Color::from_utf16_string verbatim. The translated
	// color module implements that parser, including all named CSS colors,
	// rgb()/rgba(), transparent, and the four supported hex lengths.
	if parsed := color.from_string(value) {
		lowercase := command_ascii_lowercase(value)
		if lowercase.starts_with('#')
			|| lowercase in ['black', 'silver', 'gray', 'white', 'maroon', 'red', 'purple', 'fuchsia', 'green', 'lime', 'olive', 'yellow', 'navy', 'blue', 'teal', 'aqua', 'transparent'] {
			return lowercase
		}
		return serialize_command_color(parsed)
	}
	with_hash := '#${value}'
	if color.from_string(with_hash) != none {
		return command_ascii_lowercase(with_hash)
	}
	return none
}

fn serialize_command_color(value color.Color) string {
	mut result := '#${command_color_byte_hex(value.red)}${command_color_byte_hex(value.green)}${command_color_byte_hex(value.blue)}'
	if value.alpha != 255 {
		result += command_color_byte_hex(value.alpha)
	}
	return result
}

fn command_color_byte_hex(value u8) string {
	digits := '0123456789abcdef'
	return '${digits[int(value >> 4)].ascii_str()}${digits[int(value & 0x0f)].ascii_str()}'
}

fn parse_format_block(value string) ?string {
	mut result := value
	if result.starts_with('<') && result.ends_with('>') && result.len > 2 {
		result = result[1..result.len - 1]
	}
	result = command_ascii_lowercase(result)
	if is_formattable_block_name(result) {
		return result
	}
	return none
}
