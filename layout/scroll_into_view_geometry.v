// Copyright (c) 2026, Ladybird contributors.
//
// SPDX-License-Identifier: BSD-2-Clause
module layout

import css
import dom
import html

// Painting::scroll_snapport_rect(Node, scrollport). The viewport takes its
// padding from the actual document element; percentages use this scrollport,
// including the visual viewport's smaller visible size when zoomed.
fn scroll_into_view_snapport(node &dom.Node, scrollport dom.Rect) dom.Rect {
	layout_node := node.layout_node() or { return scrollport }
	if !layout_node.has_geometry_ { return scrollport }
	mut source := unsafe { layout_node }
	if node.is_document() {
		element := node.document().document_element() or { return scrollport }
		source = element.as_node().layout_node() or { return scrollport }
	}
	handle := source.real_layout_handle()
	if handle == unsafe { nil } { return scrollport }
	typed := unsafe { &Node(handle) }
	padding := typed.computed_values().length_box(.scroll_padding_left, .scroll_padding_top,
		.scroll_padding_right, .scroll_padding_bottom, css.LengthPercentageOrAuto.make_auto())
	context := css.LengthResolutionContext.for_layout_node(source)
	top :=
		padding.top().to_px_or_zero(context, css.CSSPixels.nearest_value_for(scrollport.height)).to_double()
	right := padding.right().to_px_or_zero(context,
		css.CSSPixels.nearest_value_for(scrollport.width)).to_double()
	bottom := padding.bottom().to_px_or_zero(context,
		css.CSSPixels.nearest_value_for(scrollport.height)).to_double()
	left :=
		padding.left().to_px_or_zero(context, css.CSSPixels.nearest_value_for(scrollport.width)).to_double()
	return dom.Rect{
		x:      scrollport.x + left
		y:      scrollport.y + top
		width:  scrollport.width - left - right
		height: scrollport.height - top - bottom
	}
}

// The geometry setup in Element.cpp::determine_the_scroll_into_view_position.
// DOM cannot import Layout/Painting/HTML, so this callback reads their retained
// records on its behalf. No alternate bounds or scroll state are constructed.
fn viewport_scroll_into_view_geometry(target voidptr, scrolling_box &dom.Node) ?dom.ScrollIntoViewGeometry {
	if scrolling_box.is_document() {
		document := scrolling_box.document()
		settings_handle := document.relevant_settings_object()
		if settings_handle == unsafe { nil } { return none }
		settings := unsafe { &html.EnvironmentSettingsObject(settings_handle) }
		global := settings.global_object()
		if global.data.kind != .window { return none }
		mut window := unsafe { &html.WindowModel(global) }
		if voidptr(window.associated_document()) != voidptr(document) { return none }
		visual := window.visual_viewport() or { return none }
		offset := visual.offset()
		scroll := window.navigable_model().viewport_scroll_offset()
		return dom.ScrollIntoViewGeometry{
			scrollport:              scroll_into_view_snapport(scrolling_box, dom.Rect{
				x:      offset.x().to_double()
				y:      offset.y().to_double()
				width:  css.CSSPixels.nearest_value_for(visual.width()).to_double()
				height: css.CSSPixels.nearest_value_for(visual.height()).to_double()
			})
			current_scroll_position: dom.CSSPixelPoint_{
				x_: scroll.x().plus(offset.x()).to_double()
				y_: scroll.y().plus(offset.y()).to_double()
			}
		}
	}
	layout_node := scrolling_box.layout_node() or { return none }
	if !layout_node.has_geometry_ { return none }
	box := scrolling_box.paintable_box() or { return none }
	snapport := scroll_into_view_snapport(scrolling_box, dom.Rect{
		x:      box.padding_box_x_
		y:      box.padding_box_y_
		width:  box.padding_box_width_
		height: box.padding_box_height_
	})
	// The retained visual context currently contains the layout viewport and
	// ancestor scroll frames, matching IncludeVisualViewportTransform::No.
	rects := viewport_transform_client_rects(target, scrolling_box, [
		dom.CSSPixelRect_{
			x_:      snapport.x
			y_:      snapport.y
			width_:  snapport.width
			height_: snapport.height
		},
	])
	if rects.len != 1 { return none }
	return dom.ScrollIntoViewGeometry{
		scrollport:              dom.Rect{rects[0].x_, rects[0].y_, rects[0].width(), rects[0].height()}
		current_scroll_position: box.scroll_offset()
	}
}
