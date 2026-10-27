module html

import css
import dom
import skia
import svg
import url

fn (context &OffscreenCanvasRenderingContext2D) canvas_skia_filters() []skia.Filter {
	mut filters := []skia.Filter{}
	for function in context.drawing_state.filter_functions {
		if function.kind == .svg_reference {
			document := context.font_resolution_document() or { continue }
			if graph := canvas_svg_filter_graph(document, function.reference,
				f64(context.canvas_.width()), f64(context.canvas_.height())) {
				filters << skia.Filter{ kind: 3, graph: graph }
			}
		} else {
			filters << canvas_skia_filter(function)
		}
	}
	return filters
}

fn canvas_svg_filter_model(element &dom.Element) ?svg.Element {
	if element.local_name() !in ['filter', 'feGaussianBlur', 'feMorphology', 'feMerge', 'feMergeNode',
		'feOffset', 'feColorMatrix'] {
		return none
	}
	mut attributes := map[string]string{}
	for name in element.get_attribute_names() {
		attributes[name] = element.get_attribute_value(name)
	}
	// Explicit primitive subregions and non-default edge modes need separate
	// per-node crops. Preserve the existing unresolved behavior for those graphs.
	if element.local_name() != 'filter' {
		for name in ['x', 'y', 'width', 'height'] {
			if name in attributes { return none }
		}
		if (attributes['edgeMode'] or { 'none' }) != 'none' { return none }
	}
	// Resolving a canvas filter may be the document's first CSS consumer. Use
	// the CSS entry point to install its hooks and refresh pending inheritance.
	properties := css.up_to_date_computed_properties_for_element(element)
	attributes['color-interpolation-filters'] = match properties.color_interpolation_filters() {
		.auto_, .srgb { 'sRGB' }
		else { 'linearRGB' }
	}
	mut children := []svg.Element{}
	for child in element.as_node().children_as_vector() {
		if child_element := child.as_element() {
			if child_element.is_svg_element() {
				children << canvas_svg_filter_model(child_element)?
			}
		}
	}
	return svg.Element{ tag: element.local_name(), attributes: attributes, children: children }
}

fn canvas_svg_filter_graph(document &dom.Document, reference string, width f64, height f64) ?skia.SvgFilterGraph {
	mut resource_url := document.encoding_parse_url(reference)?
	fragment := resource_url.fragment()?
	if fragment.len == 0 { return none }
	resource_url.set_fragment(none)
	if resource_url.serialize() != document.url_string().all_before('#') { return none }
	element := document.get_element_by_id(url.percent_decode(fragment).bytestr())?
	if !element.is_svg_element() || element.local_name() != 'filter' { return none }
	model := canvas_svg_filter_model(element)?
	graph := model.gfx_filter()
	mut nodes := []skia.SvgFilterNode{}
	for node in graph.nodes {
		kind := match node.kind {
			'blur' { skia.SvgFilterNodeKind.blur }
			'erode' { skia.SvgFilterNodeKind.erode }
			'dilate' { skia.SvgFilterNodeKind.dilate }
			'merge' { skia.SvgFilterNodeKind.merge }
			'offset' { skia.SvgFilterNodeKind.offset }
			'color-matrix' { skia.SvgFilterNodeKind.color_matrix }
			'color-space-conversion' {
				if (node.string_parameters['destination'] or { '' }) == 'linear-rgb' {
					skia.SvgFilterNodeKind.to_linear_rgb
				} else {
					skia.SvgFilterNodeKind.to_srgb
				}
			}
			else { return none }
		}
		mut matrix := [20]f32{}
		if kind == .color_matrix {
			if node.matrix.len != 20 { return none }
			for i, value in node.matrix { matrix[i] = f32(value) }
		}
		nodes << skia.SvgFilterNode{
			kind:   kind
			inputs: node.input_ids.clone()
			x:      f32(if kind == .offset {
				node.parameters['dx']
			} else {
				node.parameters['radius_x']
			})
			y:      f32(if kind == .offset {
				node.parameters['dy']
			} else {
				node.parameters['radius_y']
			})
			matrix: matrix
		}
	}
	object_bounds := model.filter_units() == .object_bounding_box
	mut region := [4]f32{}
	for i, name in ['x', 'y', 'width', 'height'] {
		fallback := svg.percentage(if i < 2 { -10 } else { 120 })
		value := if specified := model.attributes[name] {
			svg.parse_number_percentage(specified)?
		} else {
			fallback
		}
		region[i] = f32(if object_bounds {
			value.value
		} else {
			value.resolve_relative_to(if i % 2 == 0 { width } else { height })
		})
	}
	return skia.SvgFilterGraph{
		nodes:            nodes
		root:             graph.root_id or { -1 }
		region:           region
		object_bounds:    object_bounds
		primitive_bounds: model.primitive_units() == .object_bounding_box
	}
}
