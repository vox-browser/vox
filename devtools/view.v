module devtools

import dom
import math
import ui2

pub const toolbar_height = 28.0
pub const breadcrumb_height = 22.0
pub const resize_handle_height = 4.0
pub const font_size = 11.0
// Monospaced faces share Menlo's 0.602em advance, so colored segments can be
// placed by column without a text measurement service.
pub const char_width = font_size * 0.6021
pub const editor_id = 'devtools-editor'
pub const tree_id = 'devtools-tree'
pub const computed_filter_id = 'devtools-computed-filter'
pub const sidebar_tab_height = 26.0

const color_border = u32(0xcacdd1)
const color_toolbar = u32(0xf1f3f4)
const color_selected = u32(0xcfe8fc)
const color_hovered = u32(0xeef3fb)
const color_accent = u32(0x1a73e8)
const color_muted = u32(0x5f6368)
const color_property = u32(0xc80000)
const color_overridden = u32(0x9aa0a6)

pub struct PaneLayout {
pub:
	width         f64
	height        f64
	tree_width    f64
	tree_height   f64
	sidebar_width f64
}

pub fn layout(width f64, height f64) PaneLayout {
	sidebar := if width >= 640 { 320.0 } else { math.floor(math.max(0.0, width * 0.4)) }
	return PaneLayout{
		width:         width
		height:        height
		tree_width:    width - sidebar
		tree_height:   math.max(0.0, height - toolbar_height - breadcrumb_height)
		sidebar_width: sidebar
	}
}

pub fn action(verb string, node i64, arg string) string {
	if node == 0 && arg == '' {
		return 'devtools:${verb}'
	}
	return if arg == '' { 'devtools:${verb}:${node}' } else { 'devtools:${verb}:${node}:${arg}' }
}

pub struct Action {
pub:
	verb string
	node i64
	arg  string
}

pub fn parse_action(value string) ?Action {
	if !value.starts_with('devtools:') {
		return none
	}
	rest := value.all_after('devtools:')
	if !rest.contains(':') {
		return Action{
			verb: rest
		}
	}
	tail := rest.all_after(':')
	return Action{
		verb: rest.all_before(':')
		node: tail.all_before(':').i64()
		arg:  if tail.contains(':') { tail.all_after(':') } else { '' }
	}
}

pub fn attribute_value_id(node i64, index int) string {
	return 'devtools-attr-value-${node}-${index}'
}

pub fn new_attribute_name_id(node i64) string {
	return 'devtools-attr-name-${node}'
}

pub fn new_attribute_value_id(node i64) string {
	return 'devtools-attr-new-value-${node}'
}

pub fn style_value_id(node i64, rule int, declaration int) string {
	return 'devtools-style-value-field-${node}-${rule}-${declaration}'
}

pub fn new_style_name_id(node i64) string {
	return 'devtools-style-new-name-${node}'
}

pub fn new_style_value_id(node i64) string {
	return 'devtools-style-new-value-${node}'
}

fn mono_style(color u32) ui2.TextStyle {
	return ui2.TextStyle{
		size:        font_size
		color:       color
		font_family: 'Menlo'
	}
}

fn flat_button(id string, title string, frame ui2.Rect, action_id string) ui2.Element {
	return ui2.Element{
		...ui2.button(id, title, frame, ui2.BoxStyle{
			bg:            0xffffff
			radius:        4
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
			border_color:  0xdadce0
		}, ui2.TextStyle{ size: 12, color: color_accent })
		action_id:           action_id
		accessibility_label: title
	}
}

fn icon_button(id string, title string, frame ui2.Rect, action_id string, tooltip string) ui2.Element {
	return ui2.Element{
		...ui2.button(id, title, frame, ui2.BoxStyle{ transparent: true }, ui2.TextStyle{ size: 15, color: color_muted })
		action_id:           action_id
		tooltip:             tooltip
		accessibility_label: tooltip
	}
}

fn point(x f64, y f64) ui2.VectorPoint {
	return ui2.VectorPoint{
		x: x
		y: y
	}
}

// elements is the docked panel. `frame` places it in the browser window.
pub fn (tools &DevTools) elements(frame ui2.Rect) ui2.Element {
	l := layout(frame.width, frame.height)
	mut children := [tools.toolbar(l), tools.tree(l), tools.breadcrumb_bar(l)]
	if l.sidebar_width > 0 {
		children << ui2.view('devtools-divider', ui2.rect(l.tree_width, toolbar_height, 1,
			l.height - toolbar_height), ui2.BoxStyle{ bg: color_border }, [])
		children << tools.sidebar(l)
	}
	children << ui2.Element{
		...ui2.draggable_view_with_cursor('devtools-resize', ui2.rect(0, 0, l.width, resize_handle_height),
			ui2.BoxStyle{ transparent: true }, 'resize_ns', [])
		action_id:           'devtools-resize'
		accessibility_label: 'Resize Developer Tools'
	}
	return ui2.Element{
		...ui2.view('devtools', frame, ui2.BoxStyle{
			bg:           0xffffff
			border_top:   1
			border_color: color_border
		}, children)
		accessibility_role:  'group'
		accessibility_label: 'Developer Tools'
	}
}

fn (tools &DevTools) toolbar(l PaneLayout) ui2.Element {
	icon := if tools.picking { color_accent } else { color_muted }
	picker := ui2.Element{
		...ui2.button_view('devtools-pick', ui2.rect(4, 3, 24, 22), ui2.BoxStyle{
			bg:          0xd2e3fc
			radius:      4
			transparent: !tools.picking
		}, [
			ui2.Element{
				...ui2.view('devtools-pick-arrow', ui2.rect(0, 0, 24, 22), ui2.BoxStyle{ transparent: true }, [])
				vector: ui2.VectorPath{
					points:       [point(11, 10), point(19, 13.2), point(15.6, 14.6), point(14.2, 18)]
					fill:         icon
					stroke_width: 0
				}
			},
		])
		vector:              ui2.VectorPath{
			points:       [point(10.5, 15.5), point(5.5, 15.5), point(5.5, 5.5), point(15.5, 5.5),
				point(15.5, 10.5)]
			closed:       false
			fill_enabled: false
			stroke:       icon
			stroke_width: 1.2
		}
		action_id:           action('pick', 0, '')
		tooltip:             'Select an element in the page to inspect it'
		accessibility_label: 'Select an element in the page to inspect it'
		accessibility_value: if tools.picking { 'on' } else { '' }
	}
	return ui2.view('devtools-toolbar', ui2.rect(0, 0, l.width, toolbar_height), ui2.BoxStyle{
		bg:            color_toolbar
		border_bottom: 1
		border_color:  color_border
	}, [
		picker,
		ui2.view('devtools-toolbar-separator', ui2.rect(33, 6, 1, 16), ui2.BoxStyle{ bg: color_border }, []),
		ui2.label('devtools-tab-elements', 'Elements', ui2.rect(38, 0, 68, toolbar_height - 1),
			ui2.TextStyle{ size: 12, color: 0x1f1f1f, align: .center }),
		ui2.view('devtools-tab-elements-underline', ui2.rect(38, toolbar_height - 3, 68, 2),
			ui2.BoxStyle{ bg: color_accent }, []),
		ui2.label('devtools-error', tools.error, ui2.rect(116, 0, math.max(0.0, l.width - 152),
			toolbar_height - 1), ui2.TextStyle{ size: 11, color: 0xb42318 }),
		icon_button('devtools-close', '×', ui2.rect(l.width - 28, 3, 22, 22), action('close', 0, ''),
			'Close Developer Tools'),
	])
}

fn row_text_x(row Row) f64 {
	return tree_padding + f64(row.depth) * indent_width + expander_width
}

fn (tools &DevTools) tree(l PaneLayout) ui2.Element {
	mut content_width := l.tree_width
	for row in tools.rows {
		if row.kind != .editor {
			content_width = math.max(content_width, row_text_x(row) + f64(row.columns()) * char_width + 24)
		}
	}
	mut children := []ui2.Element{cap: tools.rows.len}
	mut top := tree_padding
	for row in tools.rows {
		children << if row.kind == .editor {
			tools.editor_row(row, top, l)
		} else {
			tools.row_element(row, top, content_width)
		}
		top += tools.row_extent(row)
	}
	return ui2.Element{
		...ui2.scroll_with_mode(tree_id, ui2.rect(0, toolbar_height, l.tree_width, l.tree_height),
			0xffffff, .both, children)
		accessibility_role:  'tree'
		accessibility_label: 'DOM tree'
	}
}

fn expander(row Row, x f64) ui2.Element {
	title := if row.expanded { 'Collapse' } else { 'Expand' }
	return ui2.Element{
		...ui2.button('${row.key()}-toggle', '', ui2.rect(x, 2, expander_width, 14), ui2.BoxStyle{
			transparent: true
		}, ui2.TextStyle{})
		vector:              ui2.VectorPath{
			points:       if row.expanded {
				[point(3, 4.5), point(11, 4.5), point(7, 9.5)]
			} else {
				[point(4.5, 3), point(9.5, 7), point(4.5, 11)]
			}
			fill:         0x727272
			stroke_width: 0
		}
		action_id:           action('toggle', row.node, '')
		tooltip:             title
		accessibility_label: title
	}
}

fn (tools &DevTools) row_element(row Row, top f64, width f64) ui2.Element {
	x := tree_padding + f64(row.depth) * indent_width
	selected := row.node == tools.selected && row.kind != .close_tag
	hovered := row.node == tools.hovered
	mut children := []ui2.Element{cap: row.segments.len + 1}
	if row.expandable {
		children << expander(row, x)
	}
	mut column := 0
	mut text := ''
	for index, segment in row.segments {
		count := segment.text.runes().len
		children << ui2.label('${row.key()}-${index}', segment.text, ui2.rect(row_text_x(row) +
			f64(column) * char_width, 0, f64(count + 1) * char_width, row_height), mono_style(segment.color))
		column += count
		text += segment.text
	}
	return ui2.Element{
		...ui2.button_view(row.key(), ui2.rect(0, top, width, row_height), ui2.BoxStyle{
			bg:          if selected {
				color_selected
			} else {
				color_hovered
			}
			transparent: !selected && !hovered
		}, children)
		key:                 row.key()
		action_id:           action('select', row.node, '')
		menu:                row_menu(row)
		accessibility_label: text
		accessibility_value: if selected { 'selected' } else { '' }
	}
}

fn row_menu(row Row) []ui2.MenuEntry {
	id := row.node
	return match row.kind {
		.element, .close_tag {
			mut entries := [
				ui2.MenuEntry{action('edit-html', id, ''), 'Edit as HTML'},
				ui2.MenuEntry{action('add-attribute', id, ''), 'Add attribute'},
				ui2.MenuEntry{action('copy', id, ''), 'Copy element'},
				ui2.MenuEntry{action('delete', id, ''), 'Delete element'},
			]
			if row.expandable {
				entries << ui2.MenuEntry{action('expand-all', id, ''), 'Expand recursively'}
				entries << ui2.MenuEntry{action('collapse-all', id, ''), 'Collapse children'}
			}
			entries
		}
		.text, .comment {
			[
				ui2.MenuEntry{action('edit-text', id, ''), 'Edit text'},
				ui2.MenuEntry{action('copy', id, ''), 'Copy text'},
				ui2.MenuEntry{action('delete', id, ''), 'Delete node'},
			]
		}
		else {
			[]ui2.MenuEntry{}
		}
	}
}

fn (tools &DevTools) editor_row(row Row, top f64, l PaneLayout) ui2.Element {
	editor := tools.editor or { return ui2.view(row.key(), ui2.rect(0, top, 0, 0), ui2.BoxStyle{}, []) }
	x := row_text_x(row)
	width := math.max(220.0, l.tree_width - x - 16)
	text_height := tools.editor_text_height()
	label := if editor.kind == .html { 'Edit as HTML' } else { 'Edit text' }
	hint := $if macos { 'Cmd+Enter to apply, Esc to cancel' } $else {
		'Ctrl+Enter to apply, Esc to cancel'
	}
	return ui2.view(row.key(), ui2.rect(0, top, x + width + 8, text_height + 34), ui2.BoxStyle{
		transparent: true
	}, [
		// Native text areas draw no border of their own.
		ui2.view('devtools-editor-frame', ui2.rect(x, 2, width, text_height), ui2.BoxStyle{
			bg:            0xffffff
			border_left:   1
			border_top:    1
			border_right:  1
			border_bottom: 1
			border_color:  color_accent
		}, [
			ui2.Element{
				...ui2.text_input(
					id:           editor_id
					text:         editor.text
					multiline:    true
					autocorrect:  false
					padding_left: 4
					frame:        ui2.rect(1, 1, width - 2, text_height - 2)
					text_style:   mono_style(color_text)
				) or { panic(err) }
				accessibility_label: label
			},
		]),
		ui2.label('devtools-editor-hint', hint, ui2.rect(x, text_height + 8, math.max(0.0, width - 150),
			22), ui2.TextStyle{ size: 11, color: color_muted }),
		flat_button('devtools-editor-cancel', 'Cancel', ui2.rect(x + width - 140, text_height + 7,
			66, 22), action('editor-cancel', 0, '')),
		flat_button('devtools-editor-apply', 'Apply', ui2.rect(x + width - 68, text_height + 7, 66,
			22), action('editor-apply', 0, '')),
	])
}

fn (tools &DevTools) breadcrumb_bar(l PaneLayout) ui2.Element {
	crumbs := tools.breadcrumbs()
	widths := crumbs.map(f64(node_label(it).runes().len) * char_width + 14)
	mut first := 0
	mut total := 0.0
	for width in widths {
		total += width
	}
	// Keep the innermost crumbs, as Chrome does when the path overflows.
	for total > l.tree_width - 8 && first < crumbs.len - 1 {
		total -= widths[first]
		first++
	}
	mut children := []ui2.Element{}
	mut x := 4.0
	for index in first .. crumbs.len {
		node := crumbs[index]
		label := node_label(node)
		id := node_id(node)
		children << ui2.Element{
			...ui2.button('devtools-crumb-${index}', label, ui2.rect(x, 2, widths[index], 17),
				ui2.BoxStyle{
				bg:          0xdfe1e5
				radius:      3
				transparent: id != tools.selected
			}, mono_style(color_tag))
			action_id:           action('select', id, '')
			tooltip:             label
			accessibility_label: label
		}
		x += widths[index]
	}
	return ui2.view('devtools-breadcrumbs', ui2.rect(0, l.height - breadcrumb_height, l.tree_width,
		breadcrumb_height), ui2.BoxStyle{
		bg:           color_toolbar
		border_top:   1
		border_color: color_border
	}, children)
}

fn section_heading(id string, title string, y f64, width f64) ui2.Element {
	return ui2.label(id, title, ui2.rect(12, y, width - 24, 18), ui2.TextStyle{
		size:  11
		bold:  true
		color: color_muted
	})
}

fn (tools &DevTools) sidebar(l PaneLayout) ui2.Element {
	width := l.sidebar_width - 1
	content_frame := ui2.rect(0, sidebar_tab_height, width, l.height - toolbar_height - sidebar_tab_height)
	node := tools.selected_node() or {
		return ui2.view('devtools-sidebar-pane', ui2.rect(l.tree_width + 1, toolbar_height, width,
			l.height - toolbar_height), ui2.BoxStyle{ bg: 0xffffff }, [
			tools.sidebar_tabs(width),
			ui2.scroll('devtools-sidebar', content_frame, 0xffffff, [
				ui2.label('devtools-sidebar-empty', 'Select a node to inspect it.', ui2.rect(12, 10,
					width - 24, 18), ui2.TextStyle{ size: 12, color: color_muted }),
			]),
		])
	}
	children := if !node.is_element() {
		tools.node_content(node, width)
	} else {
		match tools.sidebar {
			.styles { tools.styles_content(node_id(node), width) }
			.computed { tools.computed_content(width) }
			.attributes { tools.node_content(node, width) }
		}
	}
	return ui2.view('devtools-sidebar-pane', ui2.rect(l.tree_width + 1, toolbar_height, width,
		l.height - toolbar_height), ui2.BoxStyle{ bg: 0xffffff }, [
		tools.sidebar_tabs(width),
		ui2.scroll('devtools-sidebar', content_frame, 0xffffff, children),
	])
}

fn (tools &DevTools) sidebar_tabs(width f64) ui2.Element {
	mut children := []ui2.Element{}
	mut x := 6.0
	for tab in [SidebarTab.styles, .computed, .attributes] {
		title := match tab {
			.styles { 'Styles' }
			.computed { 'Computed' }
			.attributes { 'Attributes' }
		}
		tab_width := f64(title.len) * 7 + 18
		selected := tab == tools.sidebar
		children << ui2.Element{
			...ui2.button('devtools-sidebar-tab-${tab}', title, ui2.rect(x, 0, tab_width, sidebar_tab_height - 1),
				ui2.BoxStyle{ transparent: true }, ui2.TextStyle{
				size:  12
				color: if selected { u32(0x1f1f1f) } else { color_muted }
			})
			action_id:           action('sidebar', 0, tab.str())
			accessibility_role:  'tab'
			accessibility_label: title
			accessibility_value: if selected { 'selected' } else { '' }
		}
		if selected {
			children << ui2.view('devtools-sidebar-tab-underline', ui2.rect(x, sidebar_tab_height - 3,
				tab_width, 2), ui2.BoxStyle{ bg: color_accent }, [])
		}
		x += tab_width
	}
	return ui2.Element{
		...ui2.view('devtools-sidebar-tabs', ui2.rect(0, 0, width, sidebar_tab_height), ui2.BoxStyle{
			bg:            color_toolbar
			border_bottom: 1
			border_color:  color_border
		}, children)
		accessibility_role: 'tab_list'
	}
}

// node_content edits attributes of an element, or the text of a text or
// comment node.
fn (tools &DevTools) node_content(node &dom.Node, width f64) []ui2.Element {
	id := node_id(node)
	mut children := [
		ui2.label('devtools-sidebar-title', node_label(node), ui2.rect(12, 8, width - 24, 20),
			ui2.TextStyle{ size: 12, bold: true, color: 0x1f1f1f }),
	]
	mut y := 36.0
	value_width := math.max(40.0, width - 128 - 38)
	if element := node.as_element() {
		children << section_heading('devtools-attributes-heading', 'Attributes', y, width)
		y += 22
		for index, attribute in attributes(element) {
			children << ui2.Element{
				...ui2.label('devtools-attr-label-${id}-${index}', attribute.name, ui2.rect(12, y,
					112, 20), mono_style(color_attribute_name))
				tooltip: attribute.name
			}
			children << ui2.Element{
				...ui2.text_input(
					id:          attribute_value_id(id, index)
					submit_id:   action('attr-set', id, attribute.name)
					text:        attribute.value
					multiline:   false
					autocorrect: false
					frame:       ui2.rect(128, y, value_width, 22)
					text_style:  mono_style(color_attribute_value)
				) or { panic(err) }
				accessibility_label: 'Value of ${attribute.name}'
			}
			children << icon_button('devtools-attr-remove-${id}-${index}', '×', ui2.rect(width - 34,
				y, 22, 22), action('attr-remove', id, attribute.name), 'Remove ${attribute.name}')
			y += 26
		}
		children << ui2.Element{
			...ui2.text_input(
				id:          new_attribute_name_id(id)
				submit_id:   action('attr-add', id, '')
				hint_text:   'name'
				multiline:   false
				autocorrect: false
				frame:       ui2.rect(12, y, 112, 22)
				text_style:  mono_style(color_attribute_name)
			) or { panic(err) }
			accessibility_label: 'New attribute name'
		}
		children << ui2.Element{
			...ui2.text_input(
				id:          new_attribute_value_id(id)
				submit_id:   action('attr-add', id, '')
				hint_text:   'value'
				multiline:   false
				autocorrect: false
				frame:       ui2.rect(128, y, value_width, 22)
				text_style:  mono_style(color_attribute_value)
			) or { panic(err) }
			accessibility_label: 'New attribute value'
		}
		children << icon_button('devtools-attr-add-${id}', '+', ui2.rect(width - 34, y, 22, 22),
			action('attr-add', id, ''), 'Add attribute')
		y += 38
		children << flat_button('devtools-edit-html', 'Edit as HTML', ui2.rect(12, y, 108, 24),
			action('edit-html', id, ''))
		children << flat_button('devtools-delete', 'Delete element', ui2.rect(128, y, 116, 24),
			action('delete', id, ''))
	} else if node.is_text() || node.is_comment() {
		children << section_heading('devtools-text-heading', if node.is_text() {
			'Text'
		} else {
			'Comment'
		}, y, width)
		y += 22
		children << ui2.label('devtools-text-preview', shorten(node.node_value() or { '' }, 400),
			ui2.rect(12, y, width - 24, 64), ui2.TextStyle{
			size:   11
			color:  color_text
			lines:  4
			valign: .top
		})
		y += 72
		children << flat_button('devtools-edit-text', 'Edit text', ui2.rect(12, y, 92, 24),
			action('edit-text', id, ''))
		children << flat_button('devtools-delete', 'Delete node', ui2.rect(112, y, 104, 24),
			action('delete', id, ''))
	}
	return children
}

fn style_text(color u32, struck bool) ui2.TextStyle {
	return ui2.TextStyle{
		size:          font_size
		color:         if struck { color_overridden } else { color }
		font_family:   'Menlo'
		strikethrough: struck
	}
}

// styles_content lists the inline style and matched rules, highest
// precedence first. Author declarations are editable in place.
fn (tools &DevTools) styles_content(id i64, width f64) []ui2.Element {
	snapshot := tools.styles
	if snapshot.node != id {
		return [
			ui2.label('devtools-styles-empty', 'No style information.', ui2.rect(12, 10, width - 24, 18),
				ui2.TextStyle{ size: 12, color: color_muted }),
		]
	}
	mut children := []ui2.Element{}
	mut y := 8.0
	for rule_index, rule in snapshot.rules {
		source_width := if rule.source == '' {
			0.0
		} else {
			math.min(f64(rule.source.runes().len) * 6.2 + 8, width * 0.45)
		}
		children << ui2.label('devtools-style-selector-${rule_index}', rule.selector + ' {',
			ui2.rect(12, y, width - 24 - source_width, 18), mono_style(if rule.origin == .user_agent {
			color_muted
		} else {
			color_text
		}))
		if rule.source != '' {
			children << ui2.Element{
				...ui2.label('devtools-style-source-${rule_index}', rule.source, ui2.rect(width - 12 - source_width,
					y, source_width, 18), ui2.TextStyle{ size: 11, color: color_muted, align: .right })
				tooltip: rule.source
			}
		}
		y += 20
		mut columns := 6
		for declaration in rule.declarations {
			columns = math.max(columns, declaration.name.runes().len + 2)
		}
		name_width := math.min(f64(columns) * char_width, width * 0.45)
		value_x := 24 + name_width
		value_width := math.max(40.0, width - value_x - 36)
		for declaration_index, declaration in rule.declarations {
			children << ui2.label('devtools-style-name-${rule_index}-${declaration_index}', declaration.name +
				':', ui2.rect(24, y, name_width, 20), style_text(color_property, declaration.overridden))
			if rule.editable() {
				children << ui2.Element{
					...ui2.text_input(
						id:          style_value_id(id, rule_index, declaration_index)
						submit_id:   action('style-set', id, '${rule_index}:${declaration.name}')
						text:        declaration.value_text()
						multiline:   false
						autocorrect: false
						frame:       ui2.rect(value_x, y, value_width, 20)
						text_style:  style_text(color_text, declaration.overridden)
					) or { panic(err) }
					accessibility_label: 'Value of ${declaration.name}'
				}
				children << icon_button('devtools-style-remove-${rule_index}-${declaration_index}',
					'×', ui2.rect(width - 32, y, 20, 20), action('style-remove', id, '${rule_index}:${declaration.name}'),
					'Remove ${declaration.name}')
			} else {
				children << ui2.label('devtools-style-value-${rule_index}-${declaration_index}',
					declaration.value_text() + ';', ui2.rect(value_x, y, width - value_x - 12, 20),
					style_text(color_text, declaration.overridden))
			}
			y += 22
		}
		if rule.origin == .inline {
			children << ui2.Element{
				...ui2.text_input(
					id:          new_style_name_id(id)
					submit_id:   action('style-add', id, '')
					hint_text:   'property'
					multiline:   false
					autocorrect: false
					frame:       ui2.rect(24, y, name_width - 4, 20)
					text_style:  mono_style(color_property)
				) or { panic(err) }
				accessibility_label: 'New style property'
			}
			children << ui2.Element{
				...ui2.text_input(
					id:          new_style_value_id(id)
					submit_id:   action('style-add', id, '')
					hint_text:   'value'
					multiline:   false
					autocorrect: false
					frame:       ui2.rect(value_x, y, value_width, 20)
					text_style:  mono_style(color_text)
				) or { panic(err) }
				accessibility_label: 'New style value'
			}
			children << icon_button('devtools-style-add', '+', ui2.rect(width - 32, y, 20, 20),
				action('style-add', id, ''), 'Add style property')
			y += 24
		}
		children << ui2.label('devtools-style-close-${rule_index}', '}', ui2.rect(12, y, 20, 18),
			mono_style(color_text))
		y += 26
	}
	return children
}

// box_layer nests one box-model edge around `inner`, with Chrome's colors.
fn box_layer(name string, edges []f64, color u32, frame ui2.Rect, inner ui2.Element) ui2.Element {
	edge := fn [edges] (index int) string {
		return if index < edges.len { box_edge(edges[index]) } else { '-' }
	}
	w, h := frame.width, frame.height
	caption := ui2.TextStyle{
		size:  10
		color: 0x333333
	}
	centered := ui2.TextStyle{
		size:  10
		color: 0x333333
		align: .center
	}
	return ui2.view('devtools-box-${name}', frame, ui2.BoxStyle{
		bg:            color
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
		border_color:  0x8a8a8a
	}, [
		ui2.label('devtools-box-${name}-caption', name, ui2.rect(4, 1, 60, 14), caption),
		ui2.label('devtools-box-${name}-top', edge(0), ui2.rect(0, 1, w, 14), centered),
		ui2.label('devtools-box-${name}-right', edge(1), ui2.rect(w - 36, h / 2 - 7, 34, 14), centered),
		ui2.label('devtools-box-${name}-bottom', edge(2), ui2.rect(0, h - 16, w, 14), centered),
		ui2.label('devtools-box-${name}-left', edge(3), ui2.rect(2, h / 2 - 7, 34, 14), centered),
		inner,
	])
}

pub fn box_model_diagram(model BoxModel, width f64) ui2.Element {
	w := math.max(200.0, math.min(width - 24, 320.0))
	h := 168.0
	dx, dy := 38.0, 20.0
	content_w, content_h := w - 6 * dx, h - 6 * dy
	content := ui2.view('devtools-box-content', ui2.rect(dx, dy, content_w, content_h), ui2.BoxStyle{
		bg:            0x8cb6c0
		border_left:   1
		border_top:    1
		border_right:  1
		border_bottom: 1
		border_color:  0x8a8a8a
	}, [
		ui2.label('devtools-box-size', '${box_edge(model.width)} × ${box_edge(model.height)}', ui2.rect(0,
			0, content_w, content_h), ui2.TextStyle{ size: 10, color: 0x1f1f1f, align: .center }),
	])
	padding := box_layer('padding', model.padding, 0xc3d08b, ui2.rect(dx, dy, w - 4 * dx, h - 4 * dy),
		content)
	border := box_layer('border', model.border, 0xfddd9b, ui2.rect(dx, dy, w - 2 * dx, h - 2 * dy),
		padding)
	return box_layer('margin', model.margin, 0xf9cc9d, ui2.rect((width - w) / 2, 10, w, h), border)
}

fn (tools &DevTools) computed_content(width f64) []ui2.Element {
	mut children := []ui2.Element{}
	mut y := 10.0
	if model := tools.styles.box {
		children << box_model_diagram(model, width)
		y += 182
	}
	children << ui2.Element{
		...ui2.text_input(
			id:          computed_filter_id
			action_id:   action('computed-filter', 0, '')
			text:        tools.computed_filter
			hint_text:   'Filter'
			multiline:   false
			autocorrect: false
			frame:       ui2.rect(12, y, width - 24, 22)
			text_style:  ui2.TextStyle{ size: 12 }
		) or { panic(err) }
		accessibility_label: 'Filter computed properties'
	}
	y += 30
	name_width := math.floor((width - 24) * 0.45)
	for index, property in tools.styles.filtered_computed(tools.computed_filter) {
		children << ui2.Element{
			...ui2.label('devtools-computed-name-${index}', property.name, ui2.rect(12, y, name_width,
				18), mono_style(color_property))
			tooltip: property.name
		}
		children << ui2.Element{
			...ui2.label('devtools-computed-value-${index}', property.value, ui2.rect(12 + name_width,
				y, width - 24 - name_width, 18), mono_style(color_text))
			tooltip: property.value
		}
		y += 18
	}
	return children
}
