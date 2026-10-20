module layout

import css
import dom

// CSSOM and media queries retain CSS pixels. Formatting consumes a separate
// style projection and the document's physical layout viewport instead.
fn computed_values_in_layout_coordinates(style &css.ComputedProperties,
	document &dom.Document) &css.ComputedValues {
	return css.resolve_computed_values_for_document(css.computed_style_in_layout_coordinates(style, document), document)
}

fn layout_to_css_transform(document &dom.Document) [6]f64 {
	scale := document.layout_coordinate_scale()
	if scale == 1 { return [6]f64{} }
	return [1.0 / scale, 0, 0, 1.0 / scale, 0, 0]!
}

fn natural_size_in_layout_coordinates(size css.SizeWithAspectRatio,
	document &dom.Document) css.SizeWithAspectRatio {
	scale := document.layout_coordinate_scale()
	if scale == 1 { return size }
	return css.SizeWithAspectRatio{
		width:        if width := size.width { ?CSSPixels(width.scaled(scale)) } else { none }
		height:       if height := size.height { ?CSSPixels(height.scaled(scale)) } else { none }
		aspect_ratio: size.aspect_ratio
	}
}

fn scaled_dom_point(point dom.CSSPixelPoint_, scale f64) dom.CSSPixelPoint_ {
	return dom.CSSPixelPoint_{ x_: point.x() * scale, y_: point.y() * scale }
}

fn box_layout_coordinate_scale(box &BlockBox) f64 {
	if box.layout_handle == unsafe { nil } { return 1 }
	return unsafe { &Node(box.layout_handle) }.document().layout_coordinate_scale()
}

fn scroll_snap_destination_in_css_coordinates(destination SnapDestination,
	scale f64) dom.ScrollSnapDestination_ {
	result := scroll_snap_destination_to_dom(destination)
	return dom.ScrollSnapDestination_{
		...result
		position: scaled_dom_point(result.position, 1.0 / scale)
	}
}

fn snap_selection_strategy_in_layout_coordinates(strategy dom.ScrollSnapSelectionStrategy_,
	scale f64) SnapSelectionStrategy {
	value := snap_selection_strategy_from_dom(strategy)
	return SnapSelectionStrategy{
		...value
		start_offset:                if point := value.start_offset {
			?dom.CSSPixelPoint_(scaled_dom_point(point, scale))
		} else {
			none
		}
		displacement:                scaled_dom_point(value.displacement, scale)
		starting_positions_boundary: if point := value.starting_positions_boundary {
			?dom.CSSPixelPoint_(scaled_dom_point(point, scale))
		} else {
			none
		}
	}
}
