module css

import platform
import svg

// The d attribute is raw SVG path data. The CSS path() parser also parses that
// data and keeps its normalized spelling; avoid constructing and tokenizing
// an escaped CSS string just to get the same path back.
fn svg_presentation_path_value(source string) ?StyleValue {
	$if prealloc {
		mut scratch := platform.begin_thread_scratch('SVG presentation path')
		path := svg.parse_path_data(source)
		if path.instructions.len == 0 {
			scratch.finish()
			return none
		}
		serialized := path.serialize()
		scratch.leave()
		owned := serialized.clone()
		scratch.finish()
		return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapePath{
			fill_rule: .nonzero
			path_instructions: owned
		})))
	}
	path := svg.parse_path_data(source)
	if path.instructions.len == 0 { return none }
	return StyleValue(BasicShapeStyleValue.create(BasicShape(BasicShapePath{
		fill_rule: .nonzero
		path_instructions: path.serialize()
	})))
}
