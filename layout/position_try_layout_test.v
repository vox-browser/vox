module layout

import html
import css

fn test_named_position_try_fallbacks_select_first_fitting_style_and_keep_base_on_failure() {
	for width, expected in {200:150.0,190:50.0,40:150.0} {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}
			#container{position:relative;width:${width}px;height:100px}
			#target{position:absolute;left:150px;top:10px;width:50px;height:20px;position-try-fallbacks:--missing,--a,--b}
			@position-try --a{left:300px} @position-try --b{left:50px;top:30px}
			</style><div id="container"><div id="target"></div></div>')
		defer { document.finalize() }
		run_document_layout(document,300,200) or { panic('layout') }
		r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
		assert r.x == expected,'width ${width}: ${r.x}, expected ${expected}'
		assert r.y == if expected == 50 { 30.0 } else { 10.0 }
	}
}

fn test_last_successful_position_try_is_committed_only_at_resize_observation_time() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		#container{position:relative;width:400px;height:400px}
		#anchor{position:relative;left:100px;top:100px;width:100px;height:100px;anchor-name:--a}
		#target{position:absolute;position-anchor:--a;width:100px;height:200px;position-area:top center;position-try-fallbacks:flip-block}
		</style><div id="container"><div id="anchor"></div><div id="target"></div></div>')
	defer { document.finalize() }
	mut anchor_style := css.element_style(document.get_element_by_id('anchor') or { panic('anchor') })
	for top, expected in {100:200.0,200:0.0,150:200.0} {
		anchor_style.set_property('top','${top}px','')!
		result := run_document_layout(document,500,500) or { panic('layout') }
		r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
		assert r.y == expected,'top ${top}: ${r.y}, expected ${expected}'
		// The intermediate geometry read at 200 must not replace the recorded
		// successful flip-block option.
		if top != 200 { commit_position_try_options_in_subtree(unsafe { &Node(result.root) }) }
	}
}

fn test_position_try_order_prefers_larger_inset_modified_containing_block() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		#container{position:relative;width:400px;height:400px}
		#anchor{position:absolute;left:150px;top:200px;width:150px;height:150px;anchor-name:--a}
		#target{position:absolute;position-anchor:--a;left:450px;width:40px;height:40px;position-try:most-width --right,--left}
		@position-try --right{inset:auto;left:anchor(right)}
		@position-try --left{inset:auto;right:anchor(left)}
		</style><div id="container"><div id="anchor"></div><div id="target"></div></div>')
	defer { document.finalize() }
	run_document_layout(document,500,500) or { panic('layout') }
	r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
	assert r.x == 110,r.x.str()
}

fn test_position_try_flip_block_transforms_anchor_calculations_and_position_area() {
	for use_area in [false,true] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}
			#container{position:relative;width:200px;height:200px}
			#anchor{position:absolute;left:80px;top:100px;width:50px;height:50px;anchor-name:--a}
			#target{position:absolute;position-anchor:--a;width:40px;height:60px;position-try-fallbacks:flip-block;
				${if use_area { "position-area:bottom center" } else { "left:anchor(left);top:calc(anchor(bottom) + 3px)" }}}
			</style><div id="container"><div id="anchor"></div><div id="target"></div></div>')
		defer { document.finalize() }
		run_document_layout(document,300,300) or { panic('layout') }
		r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
		assert r.y == if use_area { 40.0 } else { 37.0 },'area=${use_area}: ${r.y}'
	}
}

fn test_position_try_origin_overrides_inline_and_preserves_important() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		#container{position:relative;width:100px;height:100px}
		#target{position:absolute;left:20px!important;width:150px;height:20px;position-try-fallbacks:--a}
		@position-try --a{left:50px;top:30px;width:40px}
		</style><div id="container"><div id="target" style="top:9999px"></div></div>')
	defer { document.finalize() }
	run_document_layout(document,300,200) or { panic('layout') }
	r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
	assert r.x == 20 && r.y == 30 && r.width == 40
}

fn test_last_successful_anchor_function_fallback_uses_current_anchor_geometry() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#container{position:relative;width:400px;height:400px}#anchor{position:relative;left:100px;top:100px;width:100px;height:100px;anchor-name:--a}#target{position:absolute;position-anchor:--a;width:100px;height:200px;bottom:anchor(top);left:anchor(left);position-try-fallbacks:flip-block}</style><div id="container"><div id="anchor"></div><div id="target"></div></div>')
	defer { document.finalize() }
	mut style := css.element_style(document.get_element_by_id('anchor') or { panic('anchor') })
	for top, expected in {100:200.0,150:250.0} {
		style.set_property('top','${top}px','')!
		result := run_document_layout(document,500,500) or { panic('layout') }
		r := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
		assert r.y == expected,'${top}: ${r.y}'
		commit_position_try_options_in_subtree(unsafe { &Node(result.root) })
	}
}

fn test_position_try_resolves_custom_properties_before_expanding_inset_shorthand() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#container{position:relative;width:195px;height:70px}#anchor{anchor-name:--a;margin-left:45px;width:100px;height:30px}#target{position:absolute;position-try-fallbacks:--fallback;width:40px;height:15px;margin:5px;--left:anchor(--a right);--top:anchor(--a top)}@position-try --fallback{inset:var(--top) 0px 0px var(--left)}</style><div id="container"><div style="height:20px"></div><div id="anchor"></div><div id="target"></div></div>')
	defer { document.finalize() }
	run_document_layout(document,800,600) or { panic('layout') }
	target := document.get_element_by_id('target') or { panic('target') }
	assert css.parse_css_value(css.ParsingParams{},'anchor(--a top) 0px 0px anchor(--a right)',.inset) != none
	r := target.get_bounding_client_rect()
	assert r.x == 150,'${r.x}'
	assert r.y == 25,'${r.y}'
}
