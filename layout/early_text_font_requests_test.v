module layout

import css
import dom
import html

fn early_text_font_document(markup string) &dom.Document {
	mut document := html.parse_document(markup)
	document.set_viewport_rect(dom.Rect{width: 400, height: 300})
	prepare_document_style_inputs(document)
	document.update_style()
	return document
}

fn test_existing_text_starts_its_selected_face_before_layout_and_keeps_other_faces_unused() {
	$if !macos { return }
	document := early_text_font_document('<!doctype html><style>
		@font-face{font-family:EarlyText;src:url(file:///System/Library/Fonts/Supplemental/Arial.ttf);unicode-range:U+0000-007F}
		@font-face{font-family:EarlyText;src:url(file:///System/Library/Fonts/Supplemental/Times%20New%20Roman.ttf);unicode-range:U+0370-03FF}
		@font-face{font-family:UnusedText;src:url(file:///System/Library/Fonts/Supplemental/Arial.ttf)}
		p{font-family:EarlyText}.hidden{display:none;font-family:UnusedText}
	</style><p>Visible text.</p><p class="hidden">Hidden text.</p>')
	defer { document.finalize() }
	faces := css.css_style_computer_for(document).font_face_set_.set_entries()
	assert faces.len == 3
	assert faces[0].status() == .unloaded
	assert request_fonts_for_existing_document_text(document) == !disable_early_text_font_requests
	assert faces[0].status() == if disable_early_text_font_requests { .unloaded } else { .loaded }
	assert faces[1].status() == .unloaded
	assert faces[2].status() == .unloaded
	assert document.layout_root == unsafe { nil }
	assert document.layout_engine_handle() == unsafe { nil }
	assert document.cached_display_list() == none
	_ = layout_document_typed_in_viewport(document, 400, 300)
	assert document.layout_is_up_to_date()
	assert faces[0].status() == .loaded
}

fn test_existing_text_font_request_does_not_resolve_missing_or_dirty_styles() {
	$if !macos { return }
	mut unstyled := html.parse_document('<!doctype html><p>Not styled</p>')
	defer { unstyled.finalize() }
	assert !request_fonts_for_existing_document_text(unstyled)
	root := unstyled.document_element() or { panic('missing document element') }
	assert root.el_computed_properties() == none
	mut document := early_text_font_document('<!doctype html><style>@font-face{font-family:DirtyText;src:url(file:///System/Library/Fonts/Supplemental/Arial.ttf)}p{font-family:DirtyText}</style><p>Text</p>')
	defer { document.finalize() }
	faces := css.css_style_computer_for(document).font_face_set_.set_entries()
	mut paragraph := css.query_selector(document.as_node(), 'p') or { panic('missing paragraph') }
	paragraph.set_attribute_value('style', 'font-family:serif')
	assert document.needs_style_update_after_layout() || document.element_needs_style_update(paragraph)
	assert !request_fonts_for_existing_document_text(document)
	assert faces[0].status() == .unloaded
	document.update_style()
	assert request_fonts_for_existing_document_text(document) == !disable_early_text_font_requests
	assert faces[0].status() == .unloaded
}

fn test_existing_text_font_requests_leave_pending_stylesheets_and_existing_layout_alone() {
	$if !macos { return }
	mut document := early_text_font_document('<!doctype html><style>@font-face{font-family:PendingText;src:url(file:///System/Library/Fonts/Supplemental/Arial.ttf)}p{font-family:PendingText}</style><p>Text</p>')
	defer { document.finalize() }
	faces := css.css_style_computer_for(document).font_face_set_.set_entries()
	document.increment_number_of_pending_style_sheet_requests()
	assert !request_fonts_for_existing_document_text(document)
	assert faces[0].status() == .unloaded
	document.decrement_number_of_pending_style_sheet_requests()
	_ = layout_document_typed_in_viewport(document, 400, 300)
	assert faces[0].status() == .loaded
	assert !request_fonts_for_existing_document_text(document)
	assert document.layout_is_up_to_date()
}

fn test_existing_text_font_request_keeps_invisible_and_collapsed_text_unused() {
	$if !macos { return }
	document := early_text_font_document('<!doctype html><style>@font-face{font-family:UnusedEarlyText;src:url(file:///System/Library/Fonts/Supplemental/Arial.ttf)}p{font-family:UnusedEarlyText}</style><p> \n\t </p><p style="visibility:hidden">Invisible</p><p style="display:none">Hidden</p>')
	defer { document.finalize() }
	faces := css.css_style_computer_for(document).font_face_set_.set_entries()
	assert request_fonts_for_existing_document_text(document) == !disable_early_text_font_requests
	assert faces[0].status() == .unloaded
	assert document.layout_root == unsafe { nil }
}
