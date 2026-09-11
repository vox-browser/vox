module integration

import html
import layout

fn typed_layout_node_with_id(root &layout.Node, id string) ?&layout.Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := typed_layout_node_with_id(child, id) {
			return found
		}
	}
	return none
}

fn test_typed_layout_is_the_renderer_source() {
	document := html.parse_document('<!doctype html><html><head><style>
		html { background:#e8edf3; font-size:20px }
		body { width:200px; margin:10px; padding:10px; background:white }
		p { line-height:24px; margin:0 }
	</style></head><body><p>four four four</p></body></html>')
	root := layout.layout_document_typed_in_viewport(document, 320, 200)
	assert root.tag_name == 'html'
	assert root.width == 320
	assert root.children.len > 0
	body := root.children.filter(it.tag_name == 'body')[0]
	assert body.width == 200
	paragraph := body.children.filter(it.tag_name == 'p')[0]
	assert paragraph.lines.len == 1
	// The renderer transport preserves LayoutState::commit()'s PaintableFragment
	// boundary instead of expanding the run into compatibility word objects.
	assert paragraph.lines[0].fragments.map(it.text) == ['four four four']
	assert root.paint_commands().any(it.kind == 'draw_text' && it.text == 'four four four')
}

fn test_default_page_geometry_and_text_spacing_come_from_typed_layout() {
	document := html.parse_document('<!doctype html><html><head><style>
		html { font-size:16px }
		body { width:760px; margin:28px auto; padding:36px; border:1px solid black }
		h1 { font-size:34px; margin:0 0 12px }
		p { line-height:1.55; margin:10px 0 }
	</style></head><body>
		<h1>Ladybird, rendered by V</h1>
		<p>This native window was compiled from the translated LibWeb V modules.</p>
	</body></html>')
	root := layout.layout_document_typed_in_viewport(document, 1024, 494)
	body := root.children.filter(it.tag_name == 'body')[0]
	assert body.width == 760
	// (1024 - (760 content + 72 padding + 2 border)) / 2 + 1 border + 36 padding.
	assert body.x == 132
	heading := body.children.filter(it.tag_name == 'h1')[0]
	assert heading.lines.len == 1
	assert heading.lines[0].fragments.map(it.text) == ['Ladybird, rendered by V']
	paragraph := body.children.filter(it.tag_name == 'p')[0]
	assert paragraph.lines.len == 1
	assert paragraph.lines[0].fragments.map(it.text) == [
		'This native window was compiled from the translated LibWeb V modules.',
	]
	commands := root.paint_commands()
	assert commands.any(it.kind == 'draw_text' && it.text == 'Ladybird, rendered by V')
	assert commands.any(it.kind == 'draw_text'
		&& it.text == 'This native window was compiled from the translated LibWeb V modules.')
}

fn test_svg_geometry_reaches_the_renderer_with_viewbox_transform_and_paint() {
	document := html.parse_document('<!doctype html><html><head><style>
		html, body { margin: 0 }
	</style></head><body><svg width="200" height="100" viewBox="0 0 100 50">
		<rect id="shape" x="20" y="10" width="30" height="15"
			fill="red" stroke="blue" stroke-width="2"/>
	</svg></body></html>')
	root := layout.layout_document_typed_in_viewport(document, 320, 200)
	commands := root.paint_commands()
	paths := commands.filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	path := paths[0]
	assert path.path.starts_with('M 20 10')
	assert path.path_transform[0] == 2
	assert path.path_transform[1] == 0
	assert path.path_transform[2] == 0
	assert path.path_transform[3] == 2
	assert path.color == 'rgb(255 0 0)'
	assert path.stroke_color == 'rgb(0 0 255)'
	assert path.stroke_width == 2
	assert path.width >= 60
	assert path.height >= 30

	output := root.render_svg(320, 200)
	assert output.contains('<path d="M 20 10')
	assert output.contains('transform="matrix(2 0 0 2')
	assert output.contains('fill="rgb(255 0 0)"')
	assert output.contains('stroke="rgb(0 0 255)"')
}

fn test_svg_non_scaling_stroke_is_retained_for_device_space_painting() {
	document := html.parse_document('<!doctype html><style>body{margin:0}</style><svg width="400" height="200" viewBox="0 0 1 1" preserveAspectRatio="none"><path d="M0,.5 L1,.5" fill="none" stroke="red" vector-effect="non-scaling-stroke"/></svg>')
	root := layout.layout_document_typed_in_viewport(document, 400, 200)
	paths := root.paint_commands().filter(it.kind == 'draw_svg_path')
	assert paths.len == 1
	assert paths[0].path_transform[0] == 400
	assert paths[0].path_transform[3] == 200
	assert paths[0].stroke_width == 1
	assert paths[0].non_scaling_stroke
	assert root.render_svg(400, 200).contains('vector-effect="non-scaling-stroke"')
}

fn test_symbol_list_markers_are_painted_as_generated_text() {
	document :=
		html.parse_document('<!doctype html><style>html, body { margin:0 }</style><ul><li>disc</li></ul>')
	root := layout.layout_document_typed_in_viewport(document, 320, 200)
	markers := root.paint_commands().filter(it.kind == 'draw_text' && it.text.trim_space() == '•')
	assert markers.len == 1
	assert markers[0].text == '• '
	assert root.render_svg(320, 200).contains('>• ')
}

fn test_relative_positioning_moves_paint_but_preserves_normal_flow() {
	document := html.parse_document('<!doctype html><style>
		html, body, p { margin:0 }
		#block { position:relative; left:20px; top:10px; width:100px; height:20px }
		#child { width:10px; height:10px }
		#sibling { width:100px; height:20px }
		#flex { display:flex; width:200px }
		#flex-one, #flex-two { flex:none; width:50px; height:10px }
		#flex-one { position:relative; left:30px }
		span { position:relative; left:15px; top:5px }
	</style><body>
		<div id="block"><div id="child"></div></div><div id="sibling"></div>
		<div id="flex"><div id="flex-one"></div><div id="flex-two"></div></div>
		<p><span>shift</span></p>
	</body>')
	layout_result := layout.run_document_layout(document, 320, 200) or { panic('layout failed') }
	block_layout_node := typed_layout_node_with_id(layout_result.root, 'block') or {
		panic('missing #block layout node')
	}
	block_styled := block_layout_node.as_node_with_style() or { panic('#block has no style') }
	block_used := layout_result.used_values_for(block_styled) or { panic('#block has no geometry') }
	assert block_used.offset.x().to_double() == 0
	assert block_used.offset.y().to_double() == 0
	assert block_used.inset_left.to_double() == 20
	assert block_used.inset_top.to_double() == 10
	root := layout.layout_document_typed_in_viewport(document, 320, 200)
	body := root.children.filter(it.tag_name == 'body')[0]
	block_element := document.get_element_by_id('block') or { panic('missing #block') }
	block := root.find_box(i64(block_element.as_node().unique_id())) or {
		panic('missing block box')
	}
	assert block.x == 20
	assert block.y == 10
	assert block.children[0].x == 20
	assert block.children[0].y == 10
	sibling_element := document.get_element_by_id('sibling') or { panic('missing #sibling') }
	sibling := root.find_box(i64(sibling_element.as_node().unique_id())) or {
		panic('missing sibling box')
	}
	assert sibling.x == 0
	assert sibling.y == 20
	flex := body.children.filter(it.width == 200)[0]
	assert flex.children[0].x == 30
	assert flex.children[1].x == 50
	paragraph := body.children.filter(it.tag_name == 'p')[0]
	fragment := paragraph.lines[0].fragments.filter(it.text == 'shift')[0]
	assert fragment.x == 15
	assert fragment.y == paragraph.y + 5
}
