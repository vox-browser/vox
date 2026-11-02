module layout

import html

fn test_completed_unfilled_animation_releases_its_compositor_surface() {
	for property, values in {
		'transform': ['translateX(0)', 'translateX(40px)']
		'opacity': ['1', '.5']
	} {
		for fill in ['none', 'backwards', 'forwards', 'both'] {
			mut document := html.parse_document('<!doctype html><style>
				@keyframes move{from{${property}:${values[0]}}to{${property}:${values[1]}}}
				div{width:100px;height:40px;background:red;animation:move 1s linear ${fill}}
				</style><div></div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(.chromium)
			_ = layout_document_typed_in_viewport(document, 300, 200)
			document.update_animations_and_send_events(0)
			document.update_animations_and_send_events(500)
			_ = layout_document_typed_in_viewport(document, 300, 200)
			active := display_list_commands(document.record_display_list() or { panic('paint') })
			assert active.any(it.kind == 'begin_css_effect_layer'), '${property} ${fill}: active'
			document.update_animations_and_send_events(2000)
			_ = layout_document_typed_in_viewport(document, 300, 200)
			finished := display_list_commands(document.record_display_list() or { panic('paint') })
			assert finished.any(it.kind == 'begin_css_effect_layer') == (fill in ['forwards', 'both']), '${property} ${fill}: finished'
		}
	}
}

fn test_completed_svg_animation_rejoins_its_parent_picture() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;height:2000px}@keyframes swing{from{transform:rotate(35deg)}to{transform:rotate(0)}}
		header{transform:translateZ(0);width:300px;height:64px;background:#89cc52}
		svg{width:24px;height:24px;animation:swing 1s ease-out;transform-origin:center top}
		</style><header><svg><path fill="#fcfdff" d="M4 4L12 2L20 20L4 20Z"/></svg><span>Later</span></header>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1024, 768)
	document.update_animations_and_send_events(0)
	document.update_animations_and_send_events(2000)
	_ = layout_document_typed_in_viewport(document, 1024, 768)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	assert commands.filter(it.kind == 'begin_css_effect_layer').len == 1
	plan := chromium_raster_layer_plan(document, commands, 1)
	mut owner := -1
	mut checked := 0
	for index, command in commands {
		if (command.kind == 'fill_rect' && command.width == 300 && command.height == 64)
			|| command.kind == 'draw_svg_path' || (command.kind == 'draw_text' && command.text == 'Later') {
			if owner < 0 { owner = plan.command_layers[index] }
			assert plan.command_layers[index] == owner
			checked++
		}
	}
	assert checked == 3
}

fn test_chromium_css_animation_keeps_its_surface_while_paused() {
	for chromium in [false, true] {
		for state in ['running', 'paused'] {
			for property, values in {
				'transform': ['translateX(0)', 'translateX(80px)']
				'opacity': ['1', '.5']
				'color': ['red', 'blue']
			} {
				mut document := html.parse_document('<!doctype html><style>
					@keyframes move{from{${property}:${values[0]}}to{${property}:${values[1]}}}
					div{width:100px;height:40px;background:red;animation:move 10s infinite ${state}}
					</style><div></div>')
				defer { document.finalize() }
				if chromium { document.set_font_rendering_policy(.chromium) }
				_ = layout_document_typed_in_viewport(document, 300, 200)
				commands := display_list_commands(document.record_display_list() or { panic('paint') })
				expected := chromium && property in ['transform', 'opacity']
				assert commands.any(it.kind == 'begin_css_effect_layer') == expected, '${state} ${property}'
			}
		}
	}
}

fn test_chromium_css_animation_surface_disappears_when_animation_is_removed() {
	mut document := html.parse_document('<!doctype html><style>
		@keyframes move{from{transform:translateX(0)}to{transform:translateX(80px)}}
		#target{width:100px;height:40px;background:red;animation:move 10s infinite paused}
		</style><div id="target"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut target := document.get_element_by_id('target') or { panic('target') }
	for removed in [false, true, false] {
		target.set_attribute_value('style', if removed { 'animation:none' } else { '' })
		_ = layout_document_typed_in_viewport(document, 300, 200)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		assert commands.any(it.kind == 'begin_css_effect_layer') == !removed
	}
}

fn test_chromium_css_animation_does_not_promote_empty_timing() {
	for timing in ['0s infinite paused', '10s 0 paused'] {
		mut document := html.parse_document('<!doctype html><style>
			@keyframes move{from{transform:translateX(0)}to{transform:translateX(80px)}}
			div{width:100px;height:40px;background:red;animation:move ${timing}}
			</style><div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 300, 200)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		assert !commands.any(it.kind == 'begin_css_effect_layer'), timing
	}
}

fn test_chromium_css_animation_uses_the_exact_pseudo_element_target() {
	mut document := html.parse_document('<!doctype html><style>
		@keyframes move{from{transform:translateX(0)}to{transform:translateX(80px)}}
		div::before{content:"";display:block;width:20px;height:20px;background:red;animation:move 10s infinite paused}
		div::after{content:"";display:block;width:20px;height:20px;background:blue}
		</style><div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 300, 200)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	assert commands.filter(it.kind == 'begin_css_effect_layer').len == 1
	mut depth := 0
	for command in commands {
		if command.kind == 'begin_css_effect_layer' { depth++ }
		if command.kind == 'fill_rect' && command.color == 'red' { assert depth == 1 }
		if command.kind == 'fill_rect' && command.color == 'blue' { assert depth == 0 }
		if command.kind == 'end_css_effect_layer' { depth-- }
	}
	assert depth == 0
}

fn test_unclipped_paused_transform_prevents_merging_later_disjoint_paint_behind_it() {
	for clip in ['none', 'inside', 'ancestor'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;height:2000px;background:white}
			@keyframes move{from{transform:translateX(0)}to{transform:translateX(600px)}}
			#frame{position:absolute;left:24px;top:0;width:164px;height:600px;overflow:${if clip == 'ancestor' { 'hidden' } else { 'visible' }}}
			#animated{position:absolute;top:88px;width:164px;height:40px;background:red;animation:move 10s infinite paused;overflow:${if clip == 'inside' { 'hidden' } else { 'visible' }}}
			#later{position:absolute;left:484px;top:88px}
			</style><div id="frame"><div id="animated">Moving</div></div><div id="later">Later</div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 800, 600)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		plan := chromium_raster_layer_plan(document, commands, 1)
		mut seen := false
		for index, command in commands {
			if command.kind != 'draw_text' || command.text != 'Later' { continue }
			seen = true
			owner := plan.command_layers[index]
			assert (owner > 0) == (clip != 'ancestor'), clip
			assert plan.layers[owner].composited_contents == (clip != 'ancestor'), clip
		}
		assert seen
	}
}
