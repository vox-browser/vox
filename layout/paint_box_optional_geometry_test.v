module layout

import css
import html
import painting

fn optional_geometry_box() BlockBox {
	return BlockBox{
		width:                  80
		height:                 40
		table_cell_coordinates: retained_box_paint_payload(?painting.TableCellCoordinates(painting.TableCellCoordinates{ row_index: 2, column_span: 3 }))
		background_gradient:    retained_box_paint_payload(?LinearGradient(LinearGradient{
			colors: [css.Color{255, 0, 0, 255}, css.Color{0, 0, 255, 255}]
		}))
		css_clip:               retained_box_paint_payload(?LayoutRect(LayoutRect{1, 2, 30, 40}))
		clip_path:              retained_box_paint_payload(?painting.ClipPathVisualData(painting.ClipPathVisualData{
			polygon: [painting.Point{0, 0}, painting.Point{20, 0}, painting.Point{0, 20}]
		}))
		svg_clip:               retained_box_paint_payload(?painting.SVGClipVisualData(painting.SVGClipVisualData{ cache_key: 17 }))
		svg_mask:               retained_box_paint_payload(?painting.SVGMaskVisualData(painting.SVGMaskVisualData{ cache_key: 23 }))
	}
}

fn test_boxes_without_optional_geometry_do_not_embed_its_storage() {
	assert sizeof(BlockBox) <= 4000
	box := BlockBox{}
	assert box.table_cell_coordinates == none
	assert box.table_cell_borders == none
	assert box.background_gradient == none
	assert box.fieldset_paintable == none
	assert box.overlay == none
	assert box.overflow_clip == none
	assert box.css_clip == none
	assert box.clip_path == none
	assert box.svg_clip == none
	assert box.svg_mask == none
	assert retained_box_paint_payload[LayoutRect](none) == none
}

fn test_optional_geometry_snapshots_survive_return_copy_and_collection() {
	box := optional_geometry_box()
	copy := box
	for _ in 0 .. 3 {
		gc_collect()
		coordinates := copy.table_cell_coordinates or { panic('missing coordinates') }
		assert coordinates.row_index == 2 && coordinates.column_span == 3
		clip := copy.css_clip or { panic('missing CSS clip') }
		assert *clip == LayoutRect{1, 2, 30, 40}
		path := copy.clip_path or { panic('missing clip path') }
		assert path.polygon.len == 3 && path.polygon[1].x == 20
		assert (copy.svg_clip or { panic('missing SVG clip') }).cache_key == 17
		assert (copy.svg_mask or { panic('missing SVG mask') }).cache_key == 23
		gradient := copy.background_gradient or { panic('missing gradient') }
		assert gradient.colors.len == 2
		commands := copy.paint_commands().filter(it.kind == 'fill_gradient')
		assert commands.len == 1
		assert voidptr(commands[0].gradient or { panic('missing command gradient') }) == voidptr(gradient)
	}
}

fn test_rebasing_an_overflow_clip_preserves_the_retained_snapshot() {
	mut document := html.parse_document('<!doctype html><div id="target" style="width:80px;height:40px;overflow:hidden">text</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 300, 200)
	target := document.get_element_by_id('target')?
	node := unsafe { &Node(target.as_node().unsafe_layout_node()?.real_layout_handle()) }
	result := document_layout_result(document)?
	used := result.state.try_get(node.as_node_with_style()?)?
	snapshot := RetainedBlockPaintBox{
		box:    BlockBox{
			x:             10
			y:             20
			width:         80
			height:        40
			overflow_clip: &CompatibilityOverflowClip{ rect: LayoutRect{10, 20, 80, 40} }
		}
		origin: css.CSSPixelPoint.new(css.CSSPixels.nearest_value_for(10), css.CSSPixels.nearest_value_for(20))
	}
	mut output := BlockBox{}
	assert rebase_retained_paint_box_into(&snapshot, node, used, result.state,
		css.CSSPixelPoint.new(css.CSSPixels.nearest_value_for(17), css.CSSPixels.nearest_value_for(29)), mut output)
	original := snapshot.box.overflow_clip or { panic('missing original clip') }
	translated := output.overflow_clip or { panic('missing translated clip') }
	assert original.rect == LayoutRect{10, 20, 80, 40}
	assert translated.rect == LayoutRect{17, 29, 80, 40}
	assert voidptr(original) != voidptr(translated)
}
