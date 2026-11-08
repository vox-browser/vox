module layout

import html
import painting

fn test_compact_recorders_skip_collapsed_paths_and_keep_visible_effect_scopes_balanced() {
	mut tree := painting.AccumulatedVisualContextTree.create()
	visible := tree.append(painting.EffectsVisualData{ opacity: .5 }, 0)
	clip := tree.append(painting.ClipPathVisualData{
		bounding_rect: painting.IntRect{0, 0, 1, 1}
		polygon:       [painting.Point{.5, .5}, painting.Point{.5, .5}, painting.Point{.5, .5}]
	}, visible)
	hidden := tree.append(painting.EffectsVisualData{ opacity: .25 }, clip)
	box := BlockBox{ accumulated_visual_context_index: visible }
	steps := [CompatibilityPaintStep{ entry_index: 0, phase: .foreground, box: &box }]
	mut buckets := [][]PaintCommand{len: compatibility_paint_phase_count}
	buckets[int(CompatibilityPaintPhase.foreground)] = [
		PaintCommand{ kind: 'fill_rect', width: 10, height: 10, text: 'before' },
		PaintCommand{ kind: 'fill_rect', width: 10, height: 10, text: 'hidden', visual_context_index: hidden },
		PaintCommand{ kind: 'fill_rect', x: 20, width: 10, height: 10, text: 'after' },
	]
	actual := record_cached_paint_commands_with_visual_context(steps, buckets, 3, tree, painting.ScrollStateSnapshot{}, false)
	replayed, layer_steps := replay_cached_paint_commands_with_visual_context(steps, buckets, 3, tree, painting.ScrollStateSnapshot{}, false)
	reference := lower_visual_replay_steps(replayed, layer_steps)
	assert actual.map(it.kind) == ['begin_css_effect_layer', 'fill_rect', 'fill_rect',
		'end_css_effect_layer']
	assert actual.map(it.kind) == reference.map(it.kind)
	assert actual.map(it.text) == reference.map(it.text)
	assert actual[1].text == 'before' && actual[2].text == 'after'
	assert actual[0].visual_layer().opacity == 0.5
	assert actual[3].visual_layer().scope_id == actual[0].visual_layer().scope_id
	assert buckets[int(CompatibilityPaintPhase.foreground)][1].text == 'hidden'
}

fn test_fixed_svg_header_discards_collapsed_accessibility_clip_before_layer_planning() {
	for shape in ['inset(50%)', 'inset(50% 0)', 'inset(0 50%)', 'inset(75%)', 'inset(50% round 4px)'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;min-height:2000px}header{position:fixed;top:0;left:0;width:800px;height:56px;background:white}
			.hidden{position:absolute;width:1px;height:1px;clip-path:${shape};overflow:hidden;background:#123456}
		</style><header><a class="hidden">Skip to main content</a>
		<svg width="20" height="20"><path d="M1 1C17 3 2 18 18 18L10 4Z"/></svg>Visible</header>')
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 800, 600)
		list := document.record_display_list() or { panic('missing paint') }
		result := document_layout_result(document) or { panic('missing layout') }
		commands := display_list_commands(list)
		plan := chromium_raster_layer_plan(document, commands, 1)
		mut empty_paths := 0
		for node in result.visual_context_tree.nodes {
			if node.data is painting.ClipPathVisualData {
				assert !node.data.bounding_rect.is_empty()
				assert node.has_empty_effective_clip
				empty_paths++
			}
		}
		assert empty_paths > 0
		assert commands.all(it.color != 'rgb(18 52 86)')
		assert commands.all(!it.text.contains('Skip'))
		assert commands.any(it.kind == 'draw_text' && it.text.contains('Visible'))
		mut svg_layer := -1
		for index, command in commands {
			if command.kind == 'draw_svg_path' { svg_layer = plan.command_layers[index] }
		}
		assert svg_layer > 0
		assert plan.layers[svg_layer].composited_contents
		document.finalize()
	}
}
