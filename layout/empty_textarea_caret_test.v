module layout

import dom
import html

fn test_empty_focused_textarea_paints_its_caret_above_the_placeholder() {
	for family in ['Arial', '-apple-system,Arial'] {
	for contents in ['', 'Vox'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}textarea{appearance:none;display:block;width:590px;height:24px;
			padding:0;border:0;font:18px/24px ${family};caret-color:rgb(17,23,31)}
		</style><textarea id="field" placeholder="Ask ChatGPT">${contents}</textarea>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		document.set_embedder_window_active(true)
		document.set_cursor_blink_suppressed(true)
		host := &dom.Navigable{active_document_: document}
		mut navigable := html.NavigableModel.create(host, none) or { panic(err) }
		navigable.set_focused(true)
		document.set_cached_navigable(host)
		control := document.get_element_by_id('field') or { panic('field') }
		document.set_focused_area(control.as_node())
		root := layout_document_typed_in_viewport(document, 800, 200)
		commands := root.paint_commands()
		carets := commands.filter(it.kind == 'fill_rect' && it.color == 'rgb(17 23 31)' && it.width == 1)
		assert carets.len == 1
		assert carets[0].height > 0
		if family == 'Arial' {
			assert carets[0].y == 2
			assert carets[0].height == 20
		}
        if contents == '' {
            mut caret_index := -1
            mut placeholder_index := -1
            for index, command in commands {
                if command.kind == 'fill_rect' && command.color == 'rgb(17 23 31)' && command.width == 1 { caret_index = index }
                if command.kind == 'draw_text' && command.text == 'Ask ChatGPT' { placeholder_index = index }
            }
            assert placeholder_index >= 0 && caret_index > placeholder_index
        }
	}
}
}
