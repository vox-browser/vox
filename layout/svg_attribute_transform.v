module layout

import dom
import svg

// SVG::element_transform reads only the local transform and <use> offsets.
// Keep that projection independent of the recursive resource model: coordinate
// walks visit the outer SVG repeatedly while painting its individual paths.
fn svg_element_attribute_transform(element &dom.Element) svg.AffineTransform {
	transform := element.get_attribute_value('transform')
	tag := element.local_name()
	if transform == '' && tag != 'use' {
		return svg.AffineTransform{}
	}
	mut attributes := {
		'transform': transform
	}
	if tag == 'use' {
		attributes['x'] = element.get_attribute_value('x')
		attributes['y'] = element.get_attribute_value('y')
	}
	return svg.element_transform(svg.Element{
		tag:        tag
		attributes: attributes
	})
}
