module main

import platform
import layout
import html
import dom

fn test_retained_glyph_keys_ignore_forks_but_preserve_exact_replay_changes() {
	font := &platform.Font{ family: 'Arial', point_size: 16 }
	first := &platform.GlyphRun{
		font_:            font
		glyph_indices_:   [u16(1), 2]
		glyph_positions_: [f64(0), 0, 7, 0]
	}
	mut clone := &platform.GlyphRun{
		font_:            font
		glyph_indices_:   first.glyph_indices().clone()
		glyph_positions_: first.glyph_positions().clone()
	}
	base := layout.PaintCommand{ kind: 'draw_text', text: 'ab', glyph_run: first, font_size: 16 }
	same := layout.PaintCommand{ ...base, glyph_run: clone }
	key := scroll_raster_command_hash(&base, 0)
	assert voidptr(first) != voidptr(clone)
	if disable_glyph_content_keys {
		assert scroll_raster_command_hash(&same, 0) != key
		return
	}
	assert scroll_raster_command_hash(&same, 0) == key
	clone.glyph_positions_[2] += 0.00001 // Smaller than geometry-key quantization.
	assert scroll_raster_command_hash(&same, 0) != key
	clone.glyph_positions_[2] = 7
	clone.glyph_indices_[1] = 3
	assert scroll_raster_command_hash(&same, 0) != key
	clone.glyph_indices_[1] = 2
	clone.face_ = .emoji
	assert scroll_raster_command_hash(&same, 0) != key
	clone.face_ = .document
	clone.font_ = &platform.Font{ family: 'Arial', point_size: 16 }
	assert scroll_raster_command_hash(&same, 0) != key
	clone.font_ = font
	clone.replay_data_dirty_ = true
	assert scroll_raster_command_hash(&same, 0) != key
	clone.replay_data_dirty_ = false
	clone.glyph_positions_ = [f64(0)]
	assert scroll_raster_command_hash(&same, 0) != key
	clone.glyph_positions_ = []f64{}
	clone.glyph_indices_ = []u16{}
	assert scroll_raster_command_hash(&same, 0) != key
}

fn test_equal_text_node_replacement_keeps_unchanged_glyph_pixels_reusable() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style><p id="text">unchanged timestamp</p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut app := BrowserApp{ document: document }
	app.relayout(400, 332)
	before := app.paint_commands.filter(it.kind == 'draw_text')
	assert before.len > 0
	keys := before.map(scroll_raster_command_hash(&it, 0))
	target := document.get_element_by_id('text')?
	old_text := target.as_node().first_child()?
	mut node := unsafe { &dom.Node(target.as_node()) }
	node.set_text_content('unchanged timestamp')!
	assert voidptr(target.as_node().first_child()?) != voidptr(old_text)
	app.relayout(400, 332)
	after := app.paint_commands.filter(it.kind == 'draw_text')
	assert after.len == before.len
	if !disable_glyph_content_keys {
		assert after.map(scroll_raster_command_hash(&it, 0)) == keys
		previous := ScrollRasterKeyFrame{
			valid:    true
			document: 7
			width:    400
			height:   332
			keys:     scroll_raster_frame_keys(before, 0, 1, 400, 332)
		}
		mut stats := ScrollRasterDiffStats{}
		damage := scroll_raster_content_damage(&previous,
			scroll_raster_frame_keys(after, 0, 1, 400, 332), 7, 0, 400, 332, mut stats) or {
			panic('identical glyph replay must remain eligible for reuse')
		}
		assert damage.len == 0
		assert stats.changed == 0
	}
}
