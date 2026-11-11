module main

import html
import layout

fn test_single_axis_containment_overrides_only_the_physical_inline_dimension() {
	for vertical in [false, true] {
		mode := if vertical { 'vertical-lr' } else { 'horizontal-tb' }
		mut document := html.parse_document('<!doctype html><style>body{margin:0}.test{contain:inline-size;display:inline-block;writing-mode:${mode};contain-intrinsic-size:100px 50px}.test::before{content:"";display:block;width:40px;height:20px}</style><div id="ordinary" class="test"></div><canvas id="replaced" class="test" width="40" height="20" style="aspect-ratio:auto"></canvas>')
		_ = layout.layout_document_typed_in_viewport(document, 400, 300)
		for id in ['ordinary', 'replaced'] {
			r := (document.get_element_by_id(id) or { panic(id) }).get_bounding_client_rect()
			assert r.width == if vertical { 40 } else { 100 }, '${id}: ${r.width}'
			assert r.height == if vertical { 50 } else { 20 }, '${id}: ${r.height}'
		}
		document.finalize()
	}
}

fn test_hidden_content_uses_explicit_intrinsic_sizes_like_size_containment() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}.test{width:max-content;height:max-content;contain-intrinsic-size:10px 20px}.test::before{content:"";display:block;width:320px;height:240px}#hidden{content-visibility:hidden}#contained{contain:size}</style><div id="hidden" class="test"></div><div id="contained" class="test"></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 400, 300)
	for id in ['hidden', 'contained'] {
		r := (document.get_element_by_id(id) or { panic(id) }).get_bounding_client_rect()
		assert r.width == 10, '${id}: ${r.width}'
		assert r.height == 20, '${id}: ${r.height}'
	}
}
