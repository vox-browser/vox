// Copyright (c) 2020-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import dom
import strconv
import svg

// Translations of the SVG layout-node family. C++ virtual fast_is<T>() is
// represented by the discriminants on Node, following the other typed boxes.
@[heap]
pub struct SVGBox {
	Box
}

fn svg_box_base(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) SVGBox {
	mut box := special_box_base(document, element.as_node(), computed_values)
	box.is_svg_box_ = true
	return SVGBox{
		Box: box
	}
}

pub fn SVGBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &SVGBox {
	return &SVGBox{
		Box: svg_box_base(document, element, computed_values).Box
	}
}

@[heap]
pub struct SVGGraphicsBox {
	SVGBox
}

fn svg_graphics_box_base(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) SVGGraphicsBox {
	mut box := svg_box_base(document, element, computed_values)
	box.is_svg_graphics_box_ = true
	return SVGGraphicsBox{
		SVGBox: box
	}
}

pub fn SVGGraphicsBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &SVGGraphicsBox {
	return &SVGGraphicsBox{
		SVGBox: svg_graphics_box_base(document, element, computed_values).SVGBox
	}
}

@[heap]
pub struct SVGGeometryBox {
	SVGGraphicsBox
mut:
	cached_path_geometry &CachedSVGPathGeometry = unsafe { nil }
}

@[heap]
struct CachedSVGPathGeometry {
	instructions string
	path         svg.Path
	bounds       svg.Rect
}

pub fn SVGGeometryBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &SVGGeometryBox {
	mut box := svg_graphics_box_base(document, element, computed_values)
	box.is_svg_geometry_box_ = true
	return &SVGGeometryBox{
		SVGGraphicsBox: box
	}
}

@[heap]
pub struct SVGImageBox {
	SVGGraphicsBox
}

pub fn SVGImageBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &SVGImageBox {
	mut box := svg_graphics_box_base(document, element, computed_values)
	box.is_svg_image_box_ = true
	return &SVGImageBox{
		SVGGraphicsBox: box
	}
}

@[heap]
pub struct SVGClipBox {
	SVGBox
}

pub fn SVGClipBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &SVGClipBox {
	mut box := svg_box_base(document, element, computed_values)
	box.is_svg_clip_box_ = true
	return &SVGClipBox{
		SVGBox: box
	}
}

@[heap]
pub struct SVGMaskBox {
	SVGGraphicsBox
}

pub fn SVGMaskBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &SVGMaskBox {
	mut box := svg_graphics_box_base(document, element, computed_values)
	box.is_svg_mask_box_ = true
	return &SVGMaskBox{
		SVGGraphicsBox: box
	}
}

@[heap]
pub struct SVGPatternBox {
	SVGBox
}

pub fn SVGPatternBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &SVGPatternBox {
	mut box := svg_box_base(document, element, computed_values)
	box.is_svg_pattern_box_ = true
	return &SVGPatternBox{
		SVGBox: box
	}
}

@[heap]
pub struct SVGTextBox {
	SVGGraphicsBox
}

pub fn SVGTextBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &SVGTextBox {
	mut box := svg_graphics_box_base(document, element, computed_values)
	box.is_svg_text_box_ = true
	return &SVGTextBox{
		SVGGraphicsBox: box
	}
}

@[heap]
pub struct SVGTextPathBox {
	SVGGraphicsBox
}

pub fn SVGTextPathBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &SVGTextPathBox {
	mut box := svg_graphics_box_base(document, element, computed_values)
	box.is_svg_text_path_box_ = true
	return &SVGTextPathBox{
		SVGGraphicsBox: box
	}
}

@[heap]
pub struct SVGForeignObjectBox {
	BlockContainer
}

pub fn SVGForeignObjectBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &SVGForeignObjectBox {
	mut box := special_block_container_base(document, element.as_node(), computed_values)
	box.is_svg_foreign_object_box_ = true
	return &SVGForeignObjectBox{
		BlockContainer: box
	}
}

@[heap]
pub struct SVGSVGBox {
	ReplacedBox
}

pub fn SVGSVGBox.new(document &dom.Document, element &dom.Element, computed_values &css.ComputedProperties) &SVGSVGBox {
	mut box := replaced_box_base(document, element, computed_values)
	box.is_svg_svg_box_ = true
	box.replaced_can_have_children_ = true
	box.natural_size_ = negotiate_svg_natural_metrics(element)
	box.auto_content_box_size_ = box.natural_size_
	return &SVGSVGBox{
		ReplacedBox: box
	}
}

// SVGSVGElement::negotiate_natural_metrics(). Percentages and font-relative
// lengths do not establish intrinsic dimensions; absolute SVG/CSS lengths do.
fn negotiate_svg_natural_metrics(element &dom.Element) css.SizeWithAspectRatio {
	width := svg_absolute_length(element.get_attribute_value('width'))
	height := svg_absolute_length(element.get_attribute_value('height'))
	mut aspect_ratio := ?css.CSSPixelFraction(none)
	if width_value := width {
		if height_value := height {
			if width_value.raw_value() != 0 && height_value.raw_value() != 0 {
				aspect_ratio = css.CSSPixelFraction.new(width_value, height_value)
			}
		}
	}
	if aspect_ratio == none {
		if view_box := svg.parse_viewbox(element.get_attribute_value('viewBox')) {
			view_box_width := css.CSSPixels.nearest_value_for(view_box.width)
			view_box_height := css.CSSPixels.nearest_value_for(view_box.height)
			if view_box_width.raw_value() != 0 && view_box_height.raw_value() != 0 {
				aspect_ratio = css.CSSPixelFraction.new(view_box_width, view_box_height)
			}
		}
	}
	return css.SizeWithAspectRatio{
		width: width
		height: height
		aspect_ratio: aspect_ratio
	}
}

fn svg_absolute_length(source string) ?css.CSSPixels {
	text := source.trim_space().to_lower()
	if text.len == 0 || text.ends_with('%') || text == 'auto' {
		return none
	}
	units := ['px', 'cm', 'mm', 'q', 'in', 'pt', 'pc']
	mut suffix := ''
	for unit in units {
		if text.ends_with(unit) {
			suffix = unit
			break
		}
	}
	number_text := if suffix.len > 0 { text[..text.len - suffix.len].trim_space() } else { text }
	value := strconv.atof64(number_text) or { return none }
	scale := match suffix {
		'cm' { 96.0 / 2.54 }
		'mm' { 96.0 / 25.4 }
		'q' { 96.0 / 101.6 }
		'in' { 96.0 }
		'pt' { 96.0 / 72.0 }
		'pc' { 16.0 }
		else { 1.0 }
	}
	return css.CSSPixels.nearest_value_for(value * scale)
}

fn svg_element_model(element &dom.Element) svg.Element {
	mut attributes := map[string]string{}
	for name in element.get_attribute_names() {
		attributes[name] = element.get_attribute_value(name)
	}
	// SVGFEFloodElement::flood_{color,opacity}() read computed CSS, not merely
	// presentation attributes. Materialize those values in the standalone SVG
	// model so the shared filter-graph translation sees the same inputs.
	if element.local_name() in ['feFlood', 'feDropShadow'] {
		if properties := css.computed_properties_for_element(element) {
			context := css.ColorResolutionContext.for_computed_properties(properties, element.document())
			color := properties.color_or_fallback(.flood_color, context, css.ComputedColor.black())
			attributes['flood-color'] = '#${color.red():02x}${color.green():02x}${color.blue():02x}${color.alpha():02x}'
			attributes['flood-opacity'] = '${properties.flood_opacity()}'
		}
	}
	// SVGFilterElement::gfx_filter() reads this inherited property from each
	// primitive's computed style. Preserve it in the standalone SVG graph model.
	if properties := css.computed_properties_for_element(element) {
		attributes['color-interpolation-filters'] = match properties.color_interpolation_filters() {
			.auto_ { 'auto' }
			.srgb { 'sRGB' }
			.srgb_linear { 'linearRGB' }
			.oklab { 'linearRGB' }
		}
	}
	// SVGFEImageElement hands the decoded frame to the filter builder. The V
	// renderer owns decoded bitmap resources, so retain the equivalent absolute
	// resource URL on the standalone graph model for replay-time lookup.
	if element.local_name() == 'feImage' {
		attributes['href'] = resolved_svg_image_url(element)
		attributes.delete('xlink:href')
	}
	mut children := []svg.Element{}
	mut direct_text := ''
	for child in element.as_node().children_as_vector() {
		if child_element := child.as_element() {
			if child_element.is_svg_element() {
				children << svg_element_model(child_element)
			}
		} else if data := child.as_character_data() {
			direct_text += data.data()
		}
	}
	return svg.Element{
		tag: element.local_name()
		attributes: attributes
		children: children
		text: direct_text
	}
}

pub fn (n &Node) is_svg_box() bool {
	return n.is_svg_box_
}

pub fn (n &Node) is_svg_graphics_box() bool {
	return n.is_svg_graphics_box_
}

pub fn (n &Node) is_svg_geometry_box() bool {
	return n.is_svg_geometry_box_
}

pub fn (n &Node) is_svg_image_box() bool {
	return n.is_svg_image_box_
}

pub fn (n &Node) is_svg_clip_box() bool {
	return n.is_svg_clip_box_
}

pub fn (n &Node) is_svg_mask_box() bool {
	return n.is_svg_mask_box_
}

pub fn (n &Node) is_svg_pattern_box() bool {
	return n.is_svg_pattern_box_
}

pub fn (n &Node) is_svg_svg_box() bool {
	return n.is_svg_svg_box_
}

pub fn (n &Node) is_svg_text_box() bool {
	return n.is_svg_text_box_
}

pub fn (n &Node) is_svg_text_path_box() bool {
	return n.is_svg_text_path_box_
}

pub fn (n &Node) is_svg_foreign_object_box() bool {
	return n.is_svg_foreign_object_box_
}

pub fn (n &Node) as_svg_graphics_box() ?&SVGGraphicsBox {
	if !n.is_svg_graphics_box_ {
		return none
	}
	return unsafe { &SVGGraphicsBox(n) }
}

pub fn (n &Node) as_svg_svg_box() ?&SVGSVGBox {
	if !n.is_svg_svg_box_ {
		return none
	}
	return unsafe { &SVGSVGBox(n) }
}

pub fn (n &Node) as_svg_foreign_object_box() ?&SVGForeignObjectBox {
	if !n.is_svg_foreign_object_box_ {
		return none
	}
	return unsafe { &SVGForeignObjectBox(n) }
}
