module layout

import html

fn test_anchor_scope_limits_names_to_the_same_inclusive_subtree() {
	for scope in ['all','--a','--b'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{position:relative;width:100px;height:100px}.a{anchor-name:--a;height:10px}#scope{anchor-scope:${scope}}.target{position:absolute;position-anchor:--a;top:anchor(bottom);left:0;width:1px;height:1px}</style><div id="cb"><div class="a"></div><div class="a"></div><div id="scope"><div class="a"></div><div id="inside" class="target"></div></div><div id="outside" class="target"></div></div>')
		defer { document.finalize() }
		run_document_layout(document,200,200) or { panic('layout') }
		outside := (document.get_element_by_id('outside') or { panic('outside') }).get_bounding_client_rect()
		inside := (document.get_element_by_id('inside') or { panic('inside') }).get_bounding_client_rect()
		assert outside.y == if scope == '--b' { 30.0 } else { 20.0 },'${scope}: ${outside.y}'
		assert inside.y == 30,'${scope}: ${inside.y}'
	}
}
