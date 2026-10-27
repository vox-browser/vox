module layout

import dom
import html
import page

fn window_find_fixture(source string) (&dom.Document, &html.WindowModel, &page.Page) {
	mut owner := page.Page.create(1) or { panic(err) }
	mut document := html.parse_document_with_url('<!doctype html>${source}', dom.URL{ value: 'https://find.example/' })
	document.set_page(unsafe { &dom.Page(owner) })
	window := html.WindowModel.create_top_level(document, none, 'find') or { panic(err) }
	owner.set_local_root_navigable(window.navigable_model().host_navigable()) or { panic(err) }
	_ = run_document_layout(document, 300, 100) or { panic('missing layout') }
	return document, window, owner
}

fn test_window_find_selects_real_rendered_ranges_without_wrap_or_no_match_selection_clear() {
	document, pointer, _ := window_find_fixture('<p id="p">Hello <span>world</span>; hello world</p><script>hello world</script>')
	mut window := unsafe { &html.WindowModel(pointer) }
	assert window.find('HELLO world')
	selection := document.get_selection() or { panic('missing selection') }
	first := selection.range() or { panic('missing first selection') }
	assert first.start_offset() == 0
	assert first.end_offset() == 5
	assert first.start_container() != first.end_container()
	assert window.find('HELLO world')
	second := selection.range() or { panic('missing second selection') }
	assert second.start_offset() == 2
	assert second.end_offset() == 13
	assert !window.find('HELLO world')
	assert (selection.range() or { panic('lost selection') }) == second
	assert !window.find('missing')
	assert (selection.range() or { panic('lost selection') }) == second
	assert !window.find('')
	assert (selection.range() or { panic('lost selection') }) == second
}

fn test_page_find_uses_current_selection_and_clears_only_when_requested() {
	document, _, pointer := window_find_fixture('<p id="p">one one one</p>')
	mut owner := unsafe { &page.Page(pointer) }
	result := owner.find_in_page(page.FindInPageQuery{ string_: 'one' })
	assert result.total_match_count or { uint(0) } == 3
	assert owner.find_in_page_next_match().current_match_index == 1
	assert owner.find_in_page_next_match().current_match_index == 2
	assert owner.find_in_page_next_match().current_match_index == 0
	assert owner.find_in_page_previous_match().current_match_index == 2
	selection := document.get_selection() or { panic('missing selection') }
	mut current := unsafe { &dom.Selection(selection) }
	current.remove_all_ranges()
	assert owner.find_in_page_next_match().current_match_index == 0
	owner.find_in_page(page.FindInPageQuery{ string_: 'missing' })
	assert selection.range() == none
}

fn test_window_find_excludes_hidden_text_and_rechecks_live_layout_and_selection() {
	document, pointer, _ := window_find_fixture('<p id="p" style="display:none">needle</p><p>other</p>')
	mut window := unsafe { &html.WindowModel(pointer) }
	assert !window.find('needle')
	mut element := document.get_element_by_id('p') or { panic('missing p') }
	element.set_attribute_value('style', 'display:block')
	assert window.find('needle')
	selection := document.get_selection() or { panic('missing selection') }
	range := selection.range() or { panic('missing range') }
	assert range.start_container() == (element.as_node().first_child() or { panic('missing text') })
	assert range.get_client_rects().length() > 0
}

fn test_find_enumerates_only_documents_in_the_active_window() {
	_, pointer, owner := window_find_fixture('<p>owner text</p>')
	mut other := html.parse_document('<!doctype html><p>foreign needle</p>')
	other.set_page(unsafe { &dom.Page(owner) })
	_ = html.WindowModel.create_top_level(other, none, 'other') or { panic(err) }
	_ = run_document_layout(other, 300, 100) or { panic('missing other layout') }
	mut window := unsafe { &html.WindowModel(pointer) }
	assert !window.find('foreign needle')
	assert window.find('owner text')
	assert owner.documents_in_active_window().len == 1
}
