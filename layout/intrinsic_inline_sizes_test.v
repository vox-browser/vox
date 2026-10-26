module layout

import html

fn intrinsic_inline_find(node &Node, id string) ?&Node {
	if source := node.dom_node() {
		if element := source.as_element() {
			if element.get_attribute_value('id') == id { return node }
		}
	}
	for child in node.children() {
		if found := intrinsic_inline_find(child, id) { return found }
	}
	return none
}

fn check_intrinsic_inline_widths(markup string, scale f64) {
	mut document := html.parse_document('<!doctype html><style>
		body { margin:0; font:13.7px/18px Verdana; letter-spacing:.13px }
		#measure { width:160px }
	</style><div id="measure">${markup}</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	document.set_layout_coordinate_scale(scale)
	result := run_document_layout(document, 640, 480) or { panic('layout') }
	node := intrinsic_inline_find(result.root, 'measure') or { panic('measure') }
	mut box := unsafe { &Box(node.as_box() or { panic('box') }) }
	mut state := result.state
	styled := node.as_node_with_style() or { panic('style') }
	before := state.get(styled)
	width := before.content_width()
	height := before.content_height()
	line_count := before.line_boxes.len
	first_line_width := if line_count > 0 { before.line_boxes[0].width() } else { CSSPixels.new(0) }
	actual := calculate_inline_intrinsic_widths(mut state, box) or {
		// Empty containers return zero before the intrinsic fast path is entered.
		assert !node.has_children(), 'unsupported scale=${scale} markup=${markup}'
		IntrinsicInlineWidths{}
	}
	// Call the complete algorithm directly, bypassing the new cache entry.
	expected_min := calculate_content_width_with_constraint(mut state, box, .min_content)
	expected_max := calculate_content_width_with_constraint(mut state, box, .max_content)
	assert actual.minimum == expected_min, 'min scale=${scale} markup=${markup}: ${actual.minimum.to_double()} != ${expected_min.to_double()}'
	assert actual.maximum == expected_max, 'max scale=${scale} markup=${markup}: ${actual.maximum.to_double()} != ${expected_max.to_double()}'
	for maximum_first in [false, true] {
		box.reset_cached_intrinsic_sizes()
		if maximum_first {
			assert calculate_max_content_width(mut state, box) == expected_max
		} else {
			assert calculate_min_content_width(mut state, box) == expected_min
		}
		if node.has_children() {
			cache := box.cached_intrinsic_sizes()
			cached_min := cache.min_content_width or { panic('minimum not measured together') }
			cached_max := cache.max_content_width or { panic('maximum not measured together') }
			assert cached_min == expected_min
			assert cached_max == expected_max
		}
		assert calculate_min_content_width(mut state, box) == expected_min
		assert calculate_max_content_width(mut state, box) == expected_max
	}
	after := state.get(styled)
	assert after.content_width() == width && after.content_height() == height
	assert after.line_boxes.len == line_count
	if line_count > 0 {
		assert after.line_boxes[0].width() == first_line_width
	}
}

fn test_inline_intrinsic_widths_share_items_without_changing_fractional_text_widths() {
	for scale in [0.5, 1.0, 2.0, 3.0] {
		for markup in ['alpha beta gamma', '  alpha  beta   gamma   ', '', '    ',
			'<span>alpha</span><span>beta gamma</span>', 'alpha <b>beta gamma</b> delta',
			'<span>alpha </span> <span> beta gamma </span> ', 'alpha<br>beta gamma<br><br>delta',
			'<span style="font-size:11.3px">alpha beta</span> gamma',
			'<span style="letter-spacing:-.17px;word-spacing:.27px">alpha beta gamma</span>',
			'alpha\tbeta', 'alpha beta gamma', '‘Wé Pay for It’ — déjà vu',
			'Что-то пошло не так.'] {
			check_intrinsic_inline_widths(markup, scale)
		}
	}
}

fn test_inline_intrinsic_widths_keep_wrap_and_forced_break_rules() {
	for scale in [1.0, 2.0] {
		for markup in ['alpha-beta gamma/delta', 'alpha,beta.gamma delta',
			'<span style="white-space:nowrap">alpha beta</span> gamma',
			'alpha <span style="white-space:nowrap">beta gamma</span> delta',
			'<span style="white-space:pre-line">alpha\nbeta gamma\n</span>',
			'<span>alpha</span><span style="white-space:nowrap">beta gamma</span>delta'] {
			check_intrinsic_inline_widths(markup, scale)
		}
	}
}

fn test_inline_intrinsic_widths_fall_back_for_layout_dependent_or_unsupported_content() {
	for markup in ['<span style="display:inline-block;width:24px">alpha</span> beta',
		'<img width="24" height="12"> beta', '<div>alpha</div> beta',
		'<span style="float:left">alpha</span> beta',
		'<span style="position:absolute">alpha</span> beta',
		'<span style="padding-left:2px">alpha</span> beta',
		'<span style="margin-right:-2px">alpha</span> beta',
		'<span style="border-left:1px solid">alpha</span> beta',
		'<span style="direction:rtl">alpha</span> beta',
		'<span style="unicode-bidi:bidi-override">alpha</span> beta', 'alpha שלום beta',
		'<span style="writing-mode:vertical-rl">alpha</span> beta',
		'<span style="text-align:justify">alpha beta</span>',
		'<span style="overflow-wrap:anywhere">alpha</span> beta',
		'<span style="word-break:break-all">alpha</span> beta',
		'<span style="white-space:pre">alpha beta</span>',
		'<span style="white-space:pre">alpha\tbeta</span>'] {
		mut document := html.parse_document('<!doctype html><div id="measure">${markup}</div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 640, 480) or { panic('layout') }
		node := intrinsic_inline_find(result.root, 'measure') or { panic('measure') }
		box := node.as_box() or { panic('box') }
		mut state := result.state
		assert calculate_inline_intrinsic_widths(mut state, box) == none, markup
	}
}

fn test_inline_intrinsic_widths_keep_special_container_sizing_on_full_layout() {
	for declaration in ['display:flex', 'display:grid', 'overflow:hidden', 'text-indent:1px',
		'contain:size', 'contain:inline-size', 'container-type:inline-size', 'writing-mode:vertical-rl',
		'direction:rtl', 'column-count:2', 'line-clamp:1'] {
		mut document := html.parse_document('<!doctype html><div id="measure" style="${declaration}">alpha beta</div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 640, 480) or { panic('layout') }
		node := intrinsic_inline_find(result.root, 'measure') or { panic('measure') }
		box := node.as_box() or { panic('box') }
		mut state := result.state
		assert calculate_inline_intrinsic_widths(mut state, box) == none, declaration
	}
}

fn test_inline_intrinsic_widths_keep_default_font_policy_on_full_layout() {
	mut document := html.parse_document('<!doctype html><div id="measure">alpha beta</div>')
	defer { document.finalize() }
	result := run_document_layout(document, 640, 480) or { panic('layout') }
	node := intrinsic_inline_find(result.root, 'measure') or { panic('measure') }
	box := node.as_box() or { panic('box') }
	mut state := result.state
	assert calculate_inline_intrinsic_widths(mut state, box) == none
}
