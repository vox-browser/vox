module main

import html
import layout

fn test_svg_shadow_scope_preserves_the_viewport_source_clip_and_declines_ancestor_clips() {
	mut document := html.parse_document($embed_file('@VMODROOT/Tests/Browser/Brave/input/verge-svg-filter-space.html').to_string())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('paint') })
	mut start := -1
	for i, c in commands {
		if c.kind == 'begin_css_filter_layer' {
			start = i
			break
		}
	}
	assert start >= 0
	layers := []int{len: commands.len}
	assert svg_drop_shadow_group_end(commands, layers, start) == start + 3
	geometry := layout.css_svg_filter_geometry(document, commands[start].visual_layer().scope_id) or { panic('SVG geometry') }
	leaf := commands[start + 1]
	assert leaf.has_clip && leaf.clip_list != unsafe { nil }
	assert svg_drop_shadow_source_clips_supported(&leaf, geometry)
	mut changed := commands.clone()
	changed[start] = layout.PaintCommand{ ...commands[start], has_clip: true }
	assert svg_drop_shadow_group_end(changed, layers, start) == start
	changed = commands.clone()
	changed[start + 1] = layout.PaintCommand{ ...leaf, opacity: .5 }
	assert svg_drop_shadow_group_end(changed, layers, start) == start
	assert svg_drop_shadow_group_end(commands[..start + 2], layers[..start + 2], start) == start
	mut separate := layers.clone()
	separate[start + 1] = 1
	assert svg_drop_shadow_group_end(commands, separate, start) == start
	clip := leaf.clip_list.items[0]
	for replacement in [
		layout.PaintClip{ ...clip, is_path: true },
		layout.PaintClip{ ...clip, rect: layout.LayoutRect{clip.rect.x, clip.rect.y, 1, 1} },
		layout.PaintClip{ ...clip, transform: [f64(1), .2, 0, 1, 0, 0]! },
	] {
		clipped := layout.PaintCommand{ ...leaf, clip_list: &layout.PaintClipList{ items: [replacement] } }
		assert !svg_drop_shadow_source_clips_supported(&clipped, geometry)
	}
}
