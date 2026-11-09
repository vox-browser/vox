module layout

import html
import os

fn test_vertical_middle_images_use_directional_alphabetic_and_central_baselines() {
	font := os.join_path(@VMODROOT, 'Tests', 'Browser', 'Brave', 'resources', 'Ahem.ttf')
	for orientation in ['sideways', 'mixed'] {
		for mode in ['vertical-lr', 'vertical-rl'] {
			mut document := html.parse_document('<!doctype html><style>@font-face{font-family:BaselineAhem;src:url(file://${font})}body{margin:0}#grid{display:grid;writing-mode:${mode};text-orientation:${orientation};font:20px/1 BaselineAhem;width:100px;height:400px;grid-template-columns:repeat(4,100px)}#grid>div{align-self:baseline;min-width:0}img{width:50px;height:50px}#middle img{vertical-align:middle}#wide{width:100px;align-self:start!important}</style><div id="grid"><div id="text">ahem</div><div id="plain"><img></div><div id="middle"><img></div><div id="wide"></div></div>')
			defer { document.finalize() }
			_ = layout_document_typed_in_viewport(document, 800, 600)
			middle := (document.get_element_by_id('middle') or { panic('middle') }).get_bounding_client_rect()
			assert middle.width == 50, '${mode} ${orientation}: ${middle.width}'
			if mode == 'vertical-lr' {
				text := (document.get_element_by_id('text') or { panic('text') }).get_bounding_client_rect()
				expected_text := if orientation == 'mixed' { 15.0 } else { 13.0 }
				expected_middle := if orientation == 'mixed' { 8.0 } else { 0.0 }
				assert text.x == expected_text, '${orientation} text: ${text.x}'
				assert middle.x == expected_middle, '${orientation} middle: ${middle.x}'
			}
		}
	}
}

fn test_central_baselines_keep_fractional_half_leading_in_system_fonts() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;writing-mode:vertical-lr;grid-auto-flow:column;align-items:last baseline;width:200px}#grid>div:nth-child(1){font-size:20px;line-height:20px;align-self:first baseline;writing-mode:vertical-rl;margin-right:20px;padding-right:20px}#grid>div:nth-child(2){font-size:30px;line-height:30px}#grid>div:nth-child(3){font-size:16px;line-height:16px}#grid>div:nth-child(4){font-size:20px;line-height:20px;align-self:first baseline;margin-left:20px;padding-left:20px}#grid>div:nth-child(5){font-size:30px;line-height:30px;writing-mode:vertical-rl}#grid>div:nth-child(6){font-size:16px;line-height:16px;writing-mode:vertical-rl}</style><div id="grid"><div>line1<br>line2</div><div id="large">line1<br>line2</div><div id="small">line1<br>line2</div><div>line1<br>line2</div><div>line1<br>line2</div><div>line1<br>line2</div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 800, 600)
	large := (document.get_element_by_id('large') or { panic('large') }).get_bounding_client_rect()
	small := (document.get_element_by_id('small') or { panic('small') }).get_bounding_client_rect()
	// Last central baselines share the midpoint of each final line box.
	assert large.x == 105 && small.x == 126, '${large.x},${small.x}'
}
