module css

import dom

fn test_adopted_sheet_replacement_detaches_old_owner_and_duplicate_deletion_keeps_remaining_owner() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	root := document.as_node()
	mut list := create_adopted_style_sheets_list(root)
	first := css_style_sheet_construct(none, document)!
	second := css_style_sheet_construct(none, document)!
	list.append(first)!
	list.append(first)!
	assert first.owning_documents_or_shadow_roots.len == 1
	list.delete(1)
	assert first.owning_documents_or_shadow_roots.len == 1
	list.set(0, second)!
	assert first.owning_documents_or_shadow_roots.len == 0
	assert second.owning_documents_or_shadow_roots.len == 1
	assert voidptr(list.item(0)?) == voidptr(second)
	if _ := list.item(-1) { assert false, 'negative index must be absent' }
	if _ := list.item(1) { assert false, 'past-end index must be absent' }
	list.clear()
	assert second.owning_documents_or_shadow_roots.len == 0
}

fn test_adopted_sheet_lists_keep_distinct_shadow_owners_and_delete_before_rejected_replacement() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut first_host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut second_host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	first_root := first_host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	second_root := second_host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	mut first := create_adopted_style_sheets_list(first_root.as_node())
	mut second := create_adopted_style_sheets_list(second_root.as_node())
	sheet := css_style_sheet_construct(none, document)!
	first.append(sheet)!
	second.append(sheet)!
	assert sheet.owning_documents_or_shadow_roots.len == 2
	first.clear()
	assert sheet.owning_documents_or_shadow_roots.len == 1
	assert voidptr(sheet.owning_documents_or_shadow_roots[0]) == voidptr(second_root.as_node())
	mut foreign_document := dom.Document.create(dom.URL{value: 'https://foreign.test/'})
	defer { foreign_document.finalize() }
	foreign_sheet := css_style_sheet_construct(none, foreign_document)!
	second.set(0, foreign_sheet) or { assert err.msg().starts_with('NotAllowedError:') }
	assert voidptr(second.item(0)?) == voidptr(sheet)
	assert sheet.owning_documents_or_shadow_roots.len == 0
	assert foreign_sheet.owning_documents_or_shadow_roots.len == 0
}
