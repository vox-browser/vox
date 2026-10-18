module layout

import css
import painting

fn test_direct_inline_fragment_slots_preserve_all_metadata_and_replace_stale_values() {
	for top in [?f64(none), ?f64(3.25)] {
		source := TextFragment{
			x: 10.5, y: 20.25, width: 80, height: 15
			text: 'retained glyphs', color: css.Color{1,2,3,255}
			paint_line_top: top
			paintable_fragment: painting.PaintableFragment{text_value:'retained glyphs',offset:painting.Point{4,6}}
			selection_style: TextSelectionStyle{decoration:'underline'}
			background_images: [BackgroundImageLayer{url:'preserved.svg'}]
		}
		mut output := TextFragment{x:999,y:999,text:'stale',shadows:[BoxShadow{blur:3}]}
		assert rebase_retained_inline_fragment_into(&source, 2.5, -3.25, mut output)
		expected := TextFragment{
			...source
			x:13, y:17
			paint_line_top: if value := top { ?f64(value - 3.25) } else { none }
			paintable_fragment: painting.PaintableFragment{...source.paintable_fragment,offset:painting.Point{6.5,2.75}}
		}
		assert output.str() == expected.str()
		assert source.x == 10.5 && source.y == 20.25
		assert source.paintable_fragment.offset == painting.Point{4,6}
		assert output.shadows.len == 0
	}
}

fn test_direct_inline_fragment_slots_reject_saturation_without_publishing_partial_lines() {
	mut output := TextFragment{text:'sentinel',x:123}
	for fragment in [TextFragment{x:CSSPixels.from_raw(2_147_483_647).to_double()},
		TextFragment{x:CSSPixels.from_raw(-2_147_483_647).to_double()},
		TextFragment{x:100,y:100}] {
		assert !rebase_retained_inline_fragment_into(&fragment, 100_000_000, 0, mut output)
		assert output.text == 'sentinel' && output.x == 123
	}
	lines := [TextLine{fragments:[TextFragment{text:'first',x:0},TextFragment{x:CSSPixels.from_raw(2_147_483_600).to_double()}]}]
	assert rebase_retained_inline_lines(lines, 4, 0) == none
	assert lines[0].fragments[0].text == 'first' && lines[0].fragments[0].x == 0
}
