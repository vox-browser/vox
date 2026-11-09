module layout

import cpuraster
import css
import dom
import math
import painting
import skia
import svg

pub struct SVGDOMGeometry {
pub:
	path svg.Path
	packed_path skia.Path
	bounds dom.DOMRect
	stroke_width f64
	stroke_cap int
	stroke_join int
	stroke_miter f64
	dashes []f32
	dash_offset f64
}

// Geometry APIs depend on computed geometry, even inside a subtree that does
// not participate in layout. Querying it must not require a rendered SVG box.
pub fn svg_dom_geometry(element &dom.Element) SVGDOMGeometry {
	computed := css.up_to_date_computed_properties_for_element(element)
	mut viewport_width,mut viewport_height := 300.0,150.0
	mut ancestor := element.as_node().parent_element()
	for {
		parent := ancestor or { break }
		if parent.is_svg_element() && parent.local_name() == 'svg' {
			if viewbox := svg.parse_viewbox(parent.get_attribute_value('viewBox')) {
				viewport_width,viewport_height = viewbox.width,viewbox.height
			} else {
				style := css.up_to_date_computed_properties_for_element(parent)
				viewport_width = style.length_percentage_to_px(.width,element.document().viewport_rect().width) or { 300.0 }
				viewport_height = style.length_percentage_to_px(.height,element.document().viewport_rect().height) or { 150.0 }
			}
			break
		}
		ancestor = parent.as_node().parent_element()
	}
	box := SVGGeometryBox.new(element.document(),element,computed)
	node := unsafe { &Node(box) }
	viewport := css.CSSPixelSize.new(css.CSSPixels.nearest_value_for(viewport_width),css.CSSPixels.nearest_value_for(viewport_height))
	path := svg.geometry_path(svg_geometry_element_model(node,element,viewport),viewport_width,viewport_height)
	projection := svg_paint_path_projection(path,if computed.fill_rule() == .evenodd { painting.WindingRule.even_odd } else { painting.WindingRule.nonzero },true,true)
	bounds := svg_path_bounds(path) or { svg.Rect{} }
	return SVGDOMGeometry{
		path:path
		packed_path:skia.Path{segments:projection.packed_segments,even_odd:computed.fill_rule() == .evenodd}
		bounds:dom.DOMRect{x:bounds.x,y:bounds.y,width:bounds.width,height:bounds.height}
		stroke_width:svg_used_stroke_width(unsafe { &css.ComputedValues(computed) },math.sqrt((viewport_width*viewport_width+viewport_height*viewport_height)/2),element.document().font_rendering_policy() == .chromium)
		stroke_cap:match computed.stroke_linecap() { .butt { 0 } .round { 1 } .square { 2 } }
		stroke_join:match computed.stroke_linejoin() { .round { 0 } .bevel { 1 } else { 2 } }
		stroke_miter:computed.stroke_miterlimit()
		dashes:resolved_svg_stroke_dasharray(computed,(viewport_width+viewport_height)/2).map(f32(it))
		dash_offset:unsafe { &css.ComputedValues(computed) }.stroke_dashoffset().to_px(computed.length_resolution_context(),css.CSSPixels.nearest_value_for((viewport_width+viewport_height)/2)).to_double()
	}
}

pub fn (geometry SVGDOMGeometry) point_at_length(distance f64) svg.Point {
	point := cpuraster.canvas_path(geometry.packed_path.segments,geometry.packed_path.even_odd).point_at_distance(distance)
	return svg.Point{x:point.x,y:point.y}
}

pub fn (geometry SVGDOMGeometry) contains_point(x f64,y f64,stroke bool) bool {
	return skia.path_hit_test(skia.PathHitTest{path:geometry.packed_path,x:f32(x),y:f32(y),areas:if stroke { u8(2) } else { u8(1) },width:f32(geometry.stroke_width),cap:geometry.stroke_cap,join:geometry.stroke_join,miter:f32(geometry.stroke_miter),dashes:geometry.dashes,dash_offset:f32(geometry.dash_offset)})
}
