// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/DOM/AdoptedStyleSheets.{h,cpp}. The concrete
// CSSStyleSheet type belongs to CSS in the V module graph, so the observable
// typed list lives here while retaining its owning Document-or-ShadowRoot.
module css

import dom

@[heap]
pub struct AdoptedStyleSheetsList {
mut:
	document_or_shadow_root &dom.Node = unsafe { nil }
	sheets                  []&CSSStyleSheet
}

fn adopted_style_sheets_list_if_created(document_or_shadow_root &dom.Node) ?&AdoptedStyleSheetsList {
	if document := document_or_shadow_root.as_document() {
		if document.adopted_css_style_sheets_handle == unsafe { nil } {
			return none
		}
		return unsafe { &AdoptedStyleSheetsList(document.adopted_css_style_sheets_handle) }
	}
	if shadow_root := document_or_shadow_root.as_shadow_root() {
		if shadow_root.adopted_css_style_sheets_handle == unsafe { nil } {
			return none
		}
		return unsafe { &AdoptedStyleSheetsList(shadow_root.adopted_css_style_sheets_handle) }
	}
	return none
}

pub fn create_adopted_style_sheets_list(document_or_shadow_root &dom.Node) &AdoptedStyleSheetsList {
	if existing := adopted_style_sheets_list_if_created(document_or_shadow_root) {
		return existing
	}
	assert document_or_shadow_root.as_document() != none
		|| document_or_shadow_root.as_shadow_root() != none
	list := &AdoptedStyleSheetsList{
		document_or_shadow_root: document_or_shadow_root
	}
	if document := document_or_shadow_root.as_document() {
		mut mutable_document := unsafe { &dom.Document(document) }
		mutable_document.adopted_css_style_sheets_handle = voidptr(list)
	} else if shadow_root := document_or_shadow_root.as_shadow_root() {
		mut mutable_shadow_root := unsafe { &dom.ShadowRoot(shadow_root) }
		mutable_shadow_root.adopted_css_style_sheets_handle = voidptr(list)
	}
	return list
}

pub fn (list &AdoptedStyleSheetsList) items() []&CSSStyleSheet {
	return list.sheets.clone()
}

pub fn (list &AdoptedStyleSheetsList) length() int {
	return list.sheets.len
}

pub fn (list &AdoptedStyleSheetsList) item(index int) ?&CSSStyleSheet {
	if index < 0 || index >= list.sheets.len { return none }
	return list.sheets[index]
}

pub fn (list &AdoptedStyleSheetsList) visit_edges(mut visitor dom.CellVisitor) {
	visitor.visit(list.document_or_shadow_root)
	for sheet in list.sheets {
		visitor.visit(sheet)
	}
}

fn (mut list AdoptedStyleSheetsList) validate_and_adopt(sheet &CSSStyleSheet) ! {
	if !sheet.constructed {
		return error("NotAllowedError: StyleSheet's constructed flag is not set")
	}
	constructor_document := sheet.constructor_document or {
		return error('NotAllowedError: Sharing a StyleSheet between documents is not allowed')
	}
	if voidptr(constructor_document) != voidptr(list.document_or_shadow_root.document()) {
		return error('NotAllowedError: Sharing a StyleSheet between documents is not allowed')
	}

	mut mutable_sheet := unsafe { &CSSStyleSheet(sheet) }
	mutable_sheet.add_owning_document_or_shadow_root(list.document_or_shadow_root)
	mutable_sheet.load_pending_image_resources(list.document_or_shadow_root.document())
	// The next rule-cache build must see current outer and nested media matches,
	// even when it happens before Document's regular media-rule pass.
	mutable_sheet.evaluate_media_queries(list.document_or_shadow_root.document())
	list.invalidate_style()
}

fn (list &AdoptedStyleSheetsList) invalidate_style() {
	invalidate_css_style_scope_for_node(list.document_or_shadow_root)
	mut mutable_root := unsafe { &dom.Node(list.document_or_shadow_root) }
	mutable_root.invalidate_style(.adopted_style_sheets_list)
}

pub fn (mut list AdoptedStyleSheetsList) append(sheet &CSSStyleSheet) ! {
	list.validate_and_adopt(sheet)!
	list.sheets << sheet
}

pub fn (mut list AdoptedStyleSheetsList) set(index int, sheet &CSSStyleSheet) ! {
	if index < 0 || index > list.sheets.len {
		return error('RangeError: adopted stylesheet index is out of bounds')
	}
	if index < list.sheets.len { list.detach_index(index) }
	list.validate_and_adopt(sheet)!
	if index == list.sheets.len {
		list.sheets << sheet
		return
	}
	list.sheets[index] = sheet
}

pub fn (mut list AdoptedStyleSheetsList) delete(index int) {
	if index < 0 || index >= list.sheets.len {
		return
	}
	list.detach_index(index)
	list.sheets.delete(index)
}

// An owner is registered once even when a sheet occurs several times. Keep it
// until its last occurrence is removed, including indexed replacement.
fn (list &AdoptedStyleSheetsList) detach_index(index int) {
	mut sheet := unsafe { &CSSStyleSheet(list.sheets[index]) }
	mut another := false
	for position, existing in list.sheets {
		if position != index && voidptr(existing) == voidptr(sheet) { another = true; break }
	}
	if !another { sheet.remove_owning_document_or_shadow_root(list.document_or_shadow_root) }
	list.invalidate_style()
}

pub fn (mut list AdoptedStyleSheetsList) clear() {
	for list.sheets.len > 0 {
		list.delete(0)
	}
}

// DocumentOrShadowRoot's setter clears the observable array and appends the
// incoming sequence one item at a time, preserving callback side effects and
// partial replacement if a later item is rejected.
pub fn (mut list AdoptedStyleSheetsList) replace(sheets []&CSSStyleSheet) ! {
	list.clear()
	for sheet in sheets {
		list.append(sheet)!
	}
}
