module layout

import html

fn test_definite_block_width_equation_uses_the_containing_direction() {
	for parent_direction in ['ltr', 'rtl'] {
		child_direction := if parent_direction == 'rtl' { 'ltr' } else { 'rtl' }
		for margins in ['', 'margin-left:auto;margin-right:auto;',
			'margin-left:10px;margin-right:20px;'] {
			document :=
				html.parse_document('<!doctype html><style>html,body{margin:0}#parent{width:100px;direction:${parent_direction}}#child{width:300px;height:10px;direction:${child_direction};${margins}}</style><div id="parent"><div id="child"></div></div>')
			_ = layout_document_typed_in_viewport(document, 400, 100)
			child := document.get_element_by_id('child') or { panic('child') }
			parent := document.get_element_by_id('parent') or { panic('parent') }
			child_rect := child.get_bounding_client_rect()
			parent_rect := parent.get_bounding_client_rect()
			expected := if parent_direction == 'rtl' {
				if margins.contains('10px') { f64(-220) } else { f64(-200) }
			} else {
				if margins.contains('10px') { f64(10) } else { f64(0) }
			}
			assert child_rect.x - parent_rect.x == expected
			assert child_rect.width == 300
		}
	}
}

fn test_clamped_auto_width_replays_the_source_rtl_equation() {
	document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}#parent{width:100px;direction:rtl}#child{min-width:300px;height:10px}</style><div id="parent"><div id="child"></div></div>')
	_ = layout_document_typed_in_viewport(document, 400, 100)
	child := document.get_element_by_id('child') or { panic('child') }
	parent := document.get_element_by_id('parent') or { panic('parent') }
	assert child.get_bounding_client_rect().x - parent.get_bounding_client_rect().x == -200
}
