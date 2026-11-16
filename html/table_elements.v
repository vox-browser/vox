// Copyright (c) 2020-2025, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the DOM algorithms in HTMLTableElement.cpp, HTMLTableSectionElement.cpp,
// HTMLTableRowElement.cpp, and HTMLTableCellElement.cpp.
module html

import aria
import dom
import strconv

fn table_element(element &dom.HTMLTableElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

fn table_section_element(element &dom.HTMLTableSectionElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

fn table_row_element(element &dom.HTMLTableRowElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

fn table_cell_element(element &dom.HTMLTableCellElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

fn table_col_element(element &dom.HTMLTableColElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

fn direct_child_elements(element &dom.Element) []&dom.Element {
	mut children := []&dom.Element{}
	for child in element.as_node().children_as_vector() {
		if child_element := child.as_element() {
			children << child_element
		}
	}
	return children
}

fn remove_table_node(node &dom.Node) {
	mut mutable_node := unsafe { &dom.Node(node) }
	mutable_node.remove(false)
}

fn create_table_dom_element(document &dom.Document, local_name string) !&dom.Element {
	return dom.create_element(document, local_name, ns_html, none, none, false)
}

// https://html.spec.whatwg.org/multipage/tables.html#dom-table-caption
pub fn html_table_element_caption(table &dom.HTMLTableElement) ?&dom.HTMLTableCaptionElement {
	for child in direct_child_elements(table_element(table)) {
		if child.local_name() == 'caption' {
			return unsafe { &dom.HTMLTableCaptionElement(child) }
		}
	}
	return none
}

pub fn set_html_table_element_caption(table &dom.HTMLTableElement, caption ?&dom.HTMLTableCaptionElement) ! {
	delete_html_table_element_caption(table)
	if value := caption {
		mut table_node := table_element(table).as_node()
		table_node.pre_insert(unsafe { &dom.Element(value) }.as_node(), table_node.first_child())!
	}
}

pub fn create_html_table_element_caption(table &dom.HTMLTableElement) !&dom.HTMLTableCaptionElement {
	if caption := html_table_element_caption(table) {
		return caption
	}
	caption := create_table_dom_element(table_element(table).document(), 'caption')!
	mut table_node := table_element(table).as_node()
	table_node.pre_insert(caption.as_node(), table_node.first_child())!
	return unsafe { &dom.HTMLTableCaptionElement(caption) }
}

pub fn delete_html_table_element_caption(table &dom.HTMLTableElement) {
	if caption := html_table_element_caption(table) {
		remove_table_node(unsafe { &dom.Element(caption) }.as_node())
	}
}

fn html_table_element_section(table &dom.HTMLTableElement, local_name string) ?&dom.HTMLTableSectionElement {
	for child in direct_child_elements(table_element(table)) {
		if child.local_name() == local_name {
			return unsafe { &dom.HTMLTableSectionElement(child) }
		}
	}
	return none
}

pub fn html_table_element_t_head(table &dom.HTMLTableElement) ?&dom.HTMLTableSectionElement {
	return html_table_element_section(table, 'thead')
}

fn table_head_insertion_sibling(table &dom.HTMLTableElement) ?&dom.Node {
	for child in table_element(table).as_node().children_as_vector() {
		child_element := child.as_element() or { continue }
		if child_element.local_name() in ['caption', 'colgroup'] {
			continue
		}
		return child
	}
	return none
}

pub fn set_html_table_element_t_head(table &dom.HTMLTableElement, head ?&dom.HTMLTableSectionElement) ! {
	if value := head {
		if table_section_element(value).local_name() != 'thead' {
			return error('HierarchyRequestError: Element is not thead')
		}
	}
	delete_html_table_element_t_head(table)
	if value := head {
		mut table_node := table_element(table).as_node()
		table_node.pre_insert(table_section_element(value).as_node(), table_head_insertion_sibling(table))!
	}
}

pub fn create_html_table_element_t_head(table &dom.HTMLTableElement) !&dom.HTMLTableSectionElement {
	if head := html_table_element_t_head(table) {
		return head
	}
	head := create_table_dom_element(table_element(table).document(), 'thead')!
	mut table_node := table_element(table).as_node()
	table_node.pre_insert(head.as_node(), table_head_insertion_sibling(table))!
	return unsafe { &dom.HTMLTableSectionElement(head) }
}

pub fn delete_html_table_element_t_head(table &dom.HTMLTableElement) {
	if head := html_table_element_t_head(table) {
		remove_table_node(table_section_element(head).as_node())
	}
}

pub fn html_table_element_t_foot(table &dom.HTMLTableElement) ?&dom.HTMLTableSectionElement {
	return html_table_element_section(table, 'tfoot')
}

pub fn set_html_table_element_t_foot(table &dom.HTMLTableElement, foot ?&dom.HTMLTableSectionElement) ! {
	if value := foot {
		if table_section_element(value).local_name() != 'tfoot' {
			return error('HierarchyRequestError: Element is not tfoot')
		}
	}
	delete_html_table_element_t_foot(table)
	if value := foot {
		mut table_node := table_element(table).as_node()
		table_node.append_child(table_section_element(value).as_node())!
	}
}

pub fn create_html_table_element_t_foot(table &dom.HTMLTableElement) !&dom.HTMLTableSectionElement {
	if foot := html_table_element_t_foot(table) {
		return foot
	}
	foot := create_table_dom_element(table_element(table).document(), 'tfoot')!
	mut table_node := table_element(table).as_node()
	table_node.append_child(foot.as_node())!
	return unsafe { &dom.HTMLTableSectionElement(foot) }
}

pub fn delete_html_table_element_t_foot(table &dom.HTMLTableElement) {
	if foot := html_table_element_t_foot(table) {
		remove_table_node(table_section_element(foot).as_node())
	}
}

pub fn html_table_element_t_bodies(table &dom.HTMLTableElement) []&dom.HTMLTableSectionElement {
	mut bodies := []&dom.HTMLTableSectionElement{}
	for child in direct_child_elements(table_element(table)) {
		if child.local_name() == 'tbody' {
			bodies << unsafe { &dom.HTMLTableSectionElement(child) }
		}
	}
	return bodies
}

pub fn create_html_table_element_t_body(table &dom.HTMLTableElement) !&dom.HTMLTableSectionElement {
	body := create_table_dom_element(table_element(table).document(), 'tbody')!
	mut sibling := ?&dom.Node(none)
	children := table_element(table).as_node().children_as_vector()
	for index := children.len - 1; index >= 0; index-- {
		child_element := children[index].as_element() or { continue }
		if child_element.local_name() == 'tbody' {
			sibling = children[index].next_sibling()
			break
		}
	}
	mut table_node := table_element(table).as_node()
	table_node.pre_insert(body.as_node(), sibling)!
	return unsafe { &dom.HTMLTableSectionElement(body) }
}

fn direct_rows(parent &dom.Element) []&dom.HTMLTableRowElement {
	mut rows := []&dom.HTMLTableRowElement{}
	for child in direct_child_elements(parent) {
		if child.local_name() == 'tr' {
			rows << unsafe { &dom.HTMLTableRowElement(child) }
		}
	}
	return rows
}

// https://html.spec.whatwg.org/multipage/tables.html#dom-table-rows
pub fn html_table_element_rows(table &dom.HTMLTableElement) []&dom.HTMLTableRowElement {
	children := direct_child_elements(table_element(table))
	mut rows := []&dom.HTMLTableRowElement{}
	for child in children {
		if child.local_name() == 'thead' {
			rows << direct_rows(child)
		}
	}
	for child in children {
		if child.local_name() == 'tr' {
			rows << unsafe { &dom.HTMLTableRowElement(child) }
		} else if child.local_name() == 'tbody' {
			rows << direct_rows(child)
		}
	}
	for child in children {
		if child.local_name() == 'tfoot' {
			rows << direct_rows(child)
		}
	}
	return rows
}

pub fn insert_html_table_element_row(table &dom.HTMLTableElement, index i32) !&dom.HTMLTableRowElement {
	rows := html_table_element_rows(table)
	if index < -1 || index > rows.len {
		return error('IndexSizeError: Index is negative or greater than the number of rows')
	}
	row_element := create_table_dom_element(table_element(table).document(), 'tr')!
	row := unsafe { &dom.HTMLTableRowElement(row_element) }
	bodies := html_table_element_t_bodies(table)
	if rows.len == 0 && bodies.len == 0 {
		body := create_table_dom_element(table_element(table).document(), 'tbody')!
		mut body_node := body.as_node()
		body_node.append_child(row_element.as_node())!
		mut table_node := table_element(table).as_node()
		table_node.append_child(body.as_node())!
	} else if rows.len == 0 {
		mut last_body_node := table_section_element(bodies.last()).as_node()
		last_body_node.append_child(row_element.as_node())!
	} else if index == -1 || index == rows.len {
		last_row_node := table_row_element(rows[rows.len - 1]).as_node()
		mut parent := last_row_node.parent_node() or { return error('Row has no parent') }
		parent.append_child(row_element.as_node())!
	} else {
		reference := table_row_element(rows[index]).as_node()
		mut parent := reference.parent_node() or { return error('Row has no parent') }
		parent.insert_before(row_element.as_node(), reference, false)
	}
	return row
}

pub fn delete_html_table_element_row(table &dom.HTMLTableElement, index i32) ! {
	rows := html_table_element_rows(table)
	if index < -1 || index >= rows.len {
		return error('IndexSizeError: Index is negative or greater than or equal to the number of rows')
	}
	if rows.len == 0 {
		return
	}
	row := if index == -1 { rows[rows.len - 1] } else { rows[index] }
	remove_table_node(table_row_element(row).as_node())
}

pub fn html_table_section_element_rows(section &dom.HTMLTableSectionElement) []&dom.HTMLTableRowElement {
	return direct_rows(table_section_element(section))
}

pub fn insert_html_table_section_element_row(section &dom.HTMLTableSectionElement, index i32) !&dom.HTMLTableRowElement {
	rows := html_table_section_element_rows(section)
	if index < -1 || index > rows.len {
		return error('IndexSizeError: Index is negative or greater than the number of rows')
	}
	row_element := create_table_dom_element(table_section_element(section).document(), 'tr')!
	mut section_node := table_section_element(section).as_node()
	if index == -1 || index == rows.len {
		section_node.append_child(row_element.as_node())!
	} else {
		section_node.insert_before(row_element.as_node(), table_row_element(rows[index]).as_node(), false)
	}
	return unsafe { &dom.HTMLTableRowElement(row_element) }
}

pub fn delete_html_table_section_element_row(section &dom.HTMLTableSectionElement, index i32) ! {
	rows := html_table_section_element_rows(section)
	if index < -1 || index >= rows.len {
		return error('IndexSizeError: Index is negative or greater than or equal to the number of rows')
	}
	if rows.len == 0 {
		return
	}
	row := if index == -1 { rows[rows.len - 1] } else { rows[index] }
	remove_table_node(table_row_element(row).as_node())
}

pub fn html_table_row_element_cells(row &dom.HTMLTableRowElement) []&dom.HTMLTableCellElement {
	mut cells := []&dom.HTMLTableCellElement{}
	for child in direct_child_elements(table_row_element(row)) {
		if child.local_name() in ['td', 'th'] {
			cells << unsafe { &dom.HTMLTableCellElement(child) }
		}
	}
	return cells
}

fn index_of_table_row(rows []&dom.HTMLTableRowElement, row &dom.HTMLTableRowElement) i32 {
	for index, candidate in rows {
		if candidate.as_node().is_same_node(row.as_node()) {
			return i32(index)
		}
	}
	return -1
}

pub fn html_table_row_element_row_index(row &dom.HTMLTableRowElement) i32 {
	parent := table_row_element(row).as_node().parent_node() or { return -1 }
	parent_element := parent.as_element() or { return -1 }
	if parent_element.local_name() == 'table' {
		return index_of_table_row(html_table_element_rows(unsafe { &dom.HTMLTableElement(parent_element) }), row)
	}
	if parent_element.local_name() in ['tbody', 'thead', 'tfoot'] {
		grandparent := parent.parent_node() or { return -1 }
		grandparent_element := grandparent.as_element() or { return -1 }
		if grandparent_element.local_name() == 'table' {
			return index_of_table_row(html_table_element_rows(unsafe {
				&dom.HTMLTableElement(grandparent_element)
			}), row)
		}
	}
	return -1
}

pub fn html_table_row_element_section_row_index(row &dom.HTMLTableRowElement) i32 {
	parent := table_row_element(row).as_node().parent_node() or { return -1 }
	parent_element := parent.as_element() or { return -1 }
	if parent_element.local_name() == 'table' {
		return index_of_table_row(html_table_element_rows(unsafe { &dom.HTMLTableElement(parent_element) }), row)
	}
	if parent_element.local_name() in ['tbody', 'thead', 'tfoot'] {
		return index_of_table_row(html_table_section_element_rows(unsafe {
			&dom.HTMLTableSectionElement(parent_element)
		}), row)
	}
	return -1
}

pub fn insert_html_table_row_element_cell(row &dom.HTMLTableRowElement, index i32) !&dom.HTMLTableCellElement {
	cells := html_table_row_element_cells(row)
	if index < -1 || index > cells.len {
		return error('IndexSizeError: Index is negative or greater than the number of cells')
	}
	cell_element := create_table_dom_element(table_row_element(row).document(), 'td')!
	mut row_node := table_row_element(row).as_node()
	if index == -1 || index == cells.len {
		row_node.append_child(cell_element.as_node())!
	} else {
		row_node.insert_before(cell_element.as_node(), table_cell_element(cells[index]).as_node(), false)
	}
	return unsafe { &dom.HTMLTableCellElement(cell_element) }
}

pub fn delete_html_table_row_element_cell(row &dom.HTMLTableRowElement, index i32) ! {
	cells := html_table_row_element_cells(row)
	if index < -1 || index >= cells.len {
		return error('IndexSizeError: Index is negative or greater than or equal to the number of cells')
	}
	if cells.len == 0 {
		return
	}
	cell := if index == -1 { cells[cells.len - 1] } else { cells[index] }
	remove_table_node(table_cell_element(cell).as_node())
}

pub fn html_table_cell_element_col_span(cell &dom.HTMLTableCellElement) u32 {
	attribute := table_cell_element(cell).get_attribute('colspan') or { return 1 }
	digits := parse_non_negative_integer_digits(attribute) or { return 1 }
	value := strconv.parse_uint(digits, 10, 64) or { return 1000 }
	if value == 0 {
		return 1
	}
	return if value > 1000 { u32(1000) } else { u32(value) }
}

pub fn set_html_table_cell_element_col_span(cell &dom.HTMLTableCellElement, value u32) {
	mut element := unsafe { &dom.Element(cell) }
	element.set_attribute_value('colspan', (if value > 0x7fff_ffff { u32(1) } else { value }).str())
}

pub fn html_table_cell_element_row_span(cell &dom.HTMLTableCellElement) u32 {
	attribute := table_cell_element(cell).get_attribute('rowspan') or { return 1 }
	digits := parse_non_negative_integer_digits(attribute) or { return 1 }
	value := strconv.parse_uint(digits, 10, 64) or { return 65534 }
	return if value > 65534 { u32(65534) } else { u32(value) }
}

pub fn set_html_table_cell_element_row_span(cell &dom.HTMLTableCellElement, value u32) {
	mut element := unsafe { &dom.Element(cell) }
	element.set_attribute_value('rowspan', (if value > 0x7fff_ffff { u32(1) } else { value }).str())
}

pub fn html_table_cell_element_cell_index(cell &dom.HTMLTableCellElement) i32 {
	parent := table_cell_element(cell).as_node().parent_node() or { return -1 }
	parent_element := parent.as_element() or { return -1 }
	if parent_element.local_name() != 'tr' {
		return -1
	}
	cells := html_table_row_element_cells(unsafe { &dom.HTMLTableRowElement(parent_element) })
	for index, candidate in cells {
		if candidate.as_node().is_same_node(cell.as_node()) {
			return i32(index)
		}
	}
	return -1
}

pub fn html_table_cell_element_default_role(cell &dom.HTMLTableCellElement) ?aria.Role {
	element := unsafe { &dom.Element(cell) }
	mut ancestor := element.as_node().parent_element()
	mut table_ancestor := ?&dom.Element(none)
	for ancestor != none {
		current := ancestor or { break }
		if current.is_html_element() && current.local_name() == 'table' {
			table_ancestor = current
			break
		}
		ancestor = current.as_node().parent_element()
	}
	// Cells outside a table have no implicit role, including header roles.
	table := table_ancestor or { return none }
	if element.local_name() == 'th' {
		scope := element.get_attribute_value('scope').to_lower_ascii()
		if scope in ['col', 'colgroup'] { return .columnheader }
		if scope in ['row', 'rowgroup'] { return .rowheader }
		mut header_ancestor := element.as_node().parent_element()
		for header_ancestor != none {
			current := header_ancestor or { break }
			if current.local_name() == 'thead' {
				return .columnheader
			}
			if current.local_name() == 'tbody' {
				return .rowheader
			}
			header_ancestor = current.as_node().parent_element()
		}
	}
	role := html_element_role_or_default(table) or { return none }
	if role in [.grid, .gridcell] {
		return .gridcell
	}
	if role == .table {
		return .cell
	}
	return none
}

// https://html.spec.whatwg.org/multipage/tables.html#dom-colgroup-span
pub fn html_table_col_element_span(col &dom.HTMLTableColElement) u32 {
	attribute := table_col_element(col).get_attribute('span') or { return 1 }
	digits := parse_non_negative_integer_digits(attribute) or { return 1 }
	value := strconv.parse_uint(digits, 10, 64) or { return 1000 }
	if value < 1 {
		return 1
	}
	return if value > 1000 { u32(1000) } else { u32(value) }
}

pub fn set_html_table_col_element_span(col &dom.HTMLTableColElement, value u32) {
	mut element := unsafe { &dom.Element(col) }
	element.set_attribute_value('span', (if value > 0x7fff_ffff { u32(1) } else { value }).str())
}

pub fn html_table_element_border(table &dom.HTMLTableElement) u32 {
	value := strconv.parse_uint(table_element(table).get_attribute_value('border'), 10, 32) or {
		return 0
	}
	return u32(value)
}

pub fn html_table_element_cellpadding(table &dom.HTMLTableElement) ?u32 {
	return table.cellpadding_
}

pub fn html_table_element_attribute_changed(table &dom.HTMLTableElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut element := table_element(table)
	element.attribute_changed(name, old_value, value, namespace_)
}
