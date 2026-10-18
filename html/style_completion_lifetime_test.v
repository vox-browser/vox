module html

import css
import dom

#include "style_completion_lifetime_test.h"

fn C.vox_inline_style_has_lifecycle_hook(document voidptr) bool

$if gcboehm ? {
	fn C.vox_inline_style_watch(index u32, owner voidptr)
	fn C.vox_inline_style_collect(depth u32)
	fn C.vox_inline_style_run_worker(work fn ())
	fn C.vox_inline_style_owners_alive() u32
}

fn style_completion_parse_discovery_document() {
	mut document := dom.Document.create(dom.URL{value: 'https://inline-style-owner.test/'})
	document.set_scripting_enabled_by_embedder(false)
	assert !C.vox_inline_style_has_lifecycle_hook(voidptr(document))
	mut parser := HTMLParser.create_with_scripting_mode(document, '<!doctype html><style>@layer shared { p { color: red } } @media (min-width: 700px) { p { color: blue } }</style><section><p>inline discovery style</p></section>', .disabled)
	parser.run()
	assert document.readiness() == .complete
	assert document.get_browsing_context() == none
	assert !C.vox_inline_style_has_lifecycle_hook(voidptr(document))
	document.set_viewport_rect(dom.Rect{width: 800, height: 600})
	css.sync_document_style_elements(document)
	mut scope := css.style_scope_for_dom_node(document.as_node())
	assert scope.style_sheet_list().sheets.len == 1
	assert !C.vox_inline_style_has_lifecycle_hook(voidptr(document))
	$if gcboehm ? {
		C.vox_inline_style_watch(0, voidptr(document))
		C.vox_inline_style_watch(1, voidptr(parser))
	}
	document.finalize()
}

fn test_disabled_inline_style_discovery_document_and_parser_are_collectible() {
	$if gcboehm ? {
		C.vox_inline_style_run_worker(style_completion_parse_discovery_document)
		C.vox_inline_style_collect(8)
		C.vox_inline_style_collect(8)
		assert C.vox_inline_style_owners_alive() == 0
	} $else {
		style_completion_parse_discovery_document()
	}
}
