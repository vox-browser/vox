// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Page.cpp rendered Range search/selection and Window.cpp's find caller.
module page

import dom

fn (p &Page) rendered_search_documents() []&dom.Document {
	root := p.local_root_navigable_ or { return []&dom.Document{} }
	active := root.active_document() or { return []&dom.Document{} }
	window := active.get_window() or { return []&dom.Document{} }
	mut result := []&dom.Document{}
	for document in dom.documents_in_main_thread_event_loop() {
		if candidate := document.get_window() {
			if voidptr(candidate) == voidptr(window) { result << document }
		}
	}
	return result
}

fn (mut p Page) perform_rendered_find(query FindInPageQuery, direction int) FindInPageResult {
	root := p.local_root_navigable_ or { return FindInPageResult{} }
	active_document := root.active_document() or { return FindInPageResult{} }
	mut matches := []&dom.Range{}
	mut update_index := false
	for document in p.documents_in_active_window() {
		current_matches := document.find_matching_text(query.string_, if query.case_sensitivity == .case_sensitive {
			.case_sensitive
		} else {
			.case_insensitive
		})
		if voidptr(document) == voidptr(active_document) {
			mut active_range := ?&dom.Range(none)
			if selection := document.get_selection() {
				if !selection.is_collapsed() { active_range = selection.range() }
			}
			if current := active_range {
				mut found_index := ?int(none)
				if p.last_find_query_ == none {
					found_index = 0
				} else {
					for index, candidate in current_matches {
						comparison := candidate.compare_boundary_points(.start_to_start, current) or { continue }
						if comparison >= 0 {
							found_index = index
							break
						}
					}
				}
				p.find_match_index_ = uint((found_index or { 0 }) + matches.len)
				update_index = true
			} else {
				p.find_match_index_ = uint(matches.len)
			}
		}
		matches << current_matches
	}
	if active := root.active_document() {
		if url_without_fragment(p.last_find_url_) != url_without_fragment(active.url_string()) {
			p.last_find_url_ = active.url_string()
			p.find_match_index_ = 0
		}
	}
	if direction != 0 && update_index && matches.len > 0 {
		if direction > 0 {
			if p.find_match_index_ >= uint(matches.len - 1) {
				if query.wrap_around == .no { return FindInPageResult{} }
				p.find_match_index_ = 0
			} else {
				p.find_match_index_++
			}
		} else {
			if p.find_match_index_ == 0 {
				if query.wrap_around == .no { return FindInPageResult{} }
				p.find_match_index_ = uint(matches.len - 1)
			} else {
				p.find_match_index_--
			}
		}
	}
	p.update_find_in_page_selection(matches, query.clear_selection_on_no_match)
	return FindInPageResult{ current_match_index: p.find_match_index_, total_match_count: uint(matches.len) }
}

fn (mut p Page) select_rendered_find_match(matches []&dom.Range, clear_on_no_match ClearSelectionOnNoMatch) {
	if matches.len == 0 {
		if clear_on_no_match == .yes { p.clear_selection() }
		return
	}
	p.clear_selection()
	range := matches[p.find_match_index_]
	document := range.start_container().document()
	if document.get_window() == none { return }
	selection := document.get_selection() or { return }
	mut mutable_selection := unsafe { &dom.Selection(selection) }
	mutable_selection.add_range(range)
	p.selected_match = FindMatch{ document_id: document.url_string(), start: range.start_offset(), end: range.end_offset(), range: range }
	dom.scroll_a_range_into_view(range, .instant, .nearest, .nearest)
}

fn page_find_from_window_callback(target voidptr, query string) bool {
	mut p := unsafe { &Page(target) }
	result := if last := p.last_find_query_ {
		if last.string_ == query {
			p.find_in_page_next_match()
		} else {
			p.find_in_page(FindInPageQuery{ string_: query, wrap_around: .no, clear_selection_on_no_match: .no })
		}
	} else {
		p.find_in_page(FindInPageQuery{ string_: query, wrap_around: .no, clear_selection_on_no_match: .no })
	}
	count := result.total_match_count or { return false }
	return count > 0
}
