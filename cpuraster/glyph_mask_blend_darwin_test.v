module cpuraster

import runtime

fn test_glyph_mask_stripes_match_ordered_blends_in_both_directions() {
	if runtime.nr_cpus() < 2 { return }
	for size in [[211, 63]!, [63, 211]!] {
		width, height := size[0], size[1]
		pitch := width * 4 + 12
		initial := []u8{len: pitch * height, init: if index % 4 == 3 {
			u8(255)
		} else {
			u8(index * 37)
		}}
		viewport := IRect{0, 0, width, height}
		mut batch := GlyphMaskBatch{}
		for mask_index in 0 .. 4 {
			bounds := IRect{mask_index * 3 - 7, mask_index * 4 - 9, width - 3 + mask_index, height + 4 - mask_index}
			row_bytes := bounds.width() + 7
			mask := Mask{
				bounds:    bounds
				row_bytes: row_bytes
				image:     []u8{len: row_bytes * bounds.height(), init: u8(mask_index * 29 + index * 37)}
			}
			batch.add(mask, bounds.intersect(viewport) or { panic('expected a visible mask') })
		}
		for lowp in [true, false] {
			mut serial := initial.clone()
			mut parallel := initial.clone()
			serial_pipeline := new_pipeline_blitter(mut serial, pitch, 0xff1a92c5, 0.63, .src_over)
			parallel_pipeline := new_pipeline_blitter(mut parallel, pitch, 0xff1a92c5, 0.63, .src_over)
			mut serial_blitter := PipelineBlitter{ ...serial_pipeline, lowp: lowp }
			parallel_blitter := PipelineBlitter{ ...parallel_pipeline, lowp: lowp }
			for blit in batch.blits { serial_blitter.blit_mask(&blit.mask, blit.clip) }
			assert batch.blend_parallel(&parallel_blitter)
			assert serial == parallel
			assert parallel != initial
		}
	}
}
