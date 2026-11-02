module layout

import html

fn atomic_item_overlap_commands(display string, positioned bool) []PaintCommand {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}main{display:${display};width:60px}section{width:60px;height:60px;flex:none;grid-area:1/1}#first{margin-right:-60px}#second{background:blue}svg{display:block}#top{position:absolute;left:0;top:0;width:10px;height:10px;background:lime;z-index:1}</style><main><section id="first"><svg width="60" height="60"><rect width="60" height="60" fill="red"/></svg>${if positioned {
		'<div id="top"></div>'
	} else {
		''
	}}</section><section id="second"></section></main>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 100, 100)
	return display_list_commands(document.record_display_list() or { panic('missing paint') })
}

fn test_flex_and_grid_item_foregrounds_precede_a_later_item_background() {
	for display in ['flex', 'inline-flex', 'grid', 'inline-grid'] {
		commands := atomic_item_overlap_commands(display, false)
		mut svg_index := -1
		mut blue_index := -1
		for index, command in commands {
			if command.kind == 'draw_svg_path' { svg_index = index }
			if command.kind == 'fill_rect' && command.color == 'rgb(0 0 255)' { blue_index = index }
		}
		assert svg_index >= 0 && blue_index > svg_index
	}
}

fn test_atomic_items_keep_real_descendant_contexts_in_the_parent_context() {
	commands := atomic_item_overlap_commands('flex', true)
	mut blue_index := -1
	mut green_index := -1
	for index, command in commands {
		if command.kind == 'fill_rect' && command.color == 'rgb(0 0 255)' { blue_index = index }
		if command.kind == 'fill_rect' && command.color == 'rgb(0 255 0)' { green_index = index }
	}
	assert blue_index >= 0 && green_index > blue_index
}

fn test_ordinary_blocks_retain_the_background_before_foreground_phase() {
	commands := atomic_item_overlap_commands('block', false)
	mut svg_index := -1
	mut blue_index := -1
	for index, command in commands {
		if command.kind == 'draw_svg_path' { svg_index = index }
		if command.kind == 'fill_rect' && command.color == 'rgb(0 0 255)' { blue_index = index }
	}
	assert blue_index >= 0 && svg_index > blue_index
}

fn test_atomic_inline_background_follows_its_enclosing_inline_decoration() {
	for display in ['inline-block', 'inline-flex', 'inline-grid'] {
		for nested in [false, true] {
			content := '<i style="display:${display};width:20px;height:30px;background:blue"></i>'
			mut document := html.parse_document('<!doctype html><style>body{margin:0;font:20px/40px Arial}#host{position:relative;background:rgb(9 8 7);padding:3px;border:1px solid}</style><div><span id="host">${if nested { '<span>${content}</span>' } else { content }}</span></div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(.chromium)
			_ = layout_document_typed_in_viewport(document, 200, 120)
			commands := display_list_commands(document.record_display_list() or { panic('paint') })
			mut parent_index := -1
			mut atomic_index := -1
			for index, command in commands {
				if command.kind == 'fill_rect' && command.color == 'rgb(9 8 7)' { parent_index = index }
				if command.kind == 'fill_rect' && command.color == 'rgb(0 0 255)' { atomic_index = index }
			}
			assert parent_index >= 0
			assert atomic_index > parent_index
		}
	}
}
