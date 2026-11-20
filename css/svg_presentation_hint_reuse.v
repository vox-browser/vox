module css

import dom
import os

// SVG presentation attributes were parsed again, and path data parsed and
// serialized again, every time an element was styled: about 5% of the style
// pass on the archived github.com/vlang/v page, whose octicons repeat the same
// fill, width, height and d values. The parse depends only on the document,
// the property and the attribute text, so within one style batch equal
// attributes share one parsed value. Parsed values are immutable, as the
// declaration values every matching element shares are.
const disable_svg_presentation_hint_reuse = os.getenv('VOX_DISABLE_SVG_PRESENTATION_HINT_REUSE') != ''
const svg_presentation_hint_reuse_limit = 4096

@[heap]
struct SvgPresentationHintCache {
mut:
	entries map[string]&dom.StyleValue
}

fn svg_presentation_hint_value(computer &StyleComputer, element &dom.Element, property_id PropertyID, source string) ?&dom.StyleValue {
	if disable_svg_presentation_hint_reuse || computer == unsafe { nil }
		|| computer.computed_property_page_batch_depth_ == 0 {
		value := parse_svg_presentation_attribute_value(element.document(), property_id, source)?
		return dom_style_value_from_value_logic(value)
	}
	key := '${int(property_id)}|${source}'
	if computer.svg_presentation_hints_ != unsafe { nil } {
		if cached := computer.svg_presentation_hints_.entries[key] {
			return cached
		}
	}
	value := parse_svg_presentation_attribute_value(element.document(), property_id, source)?
	boxed := dom_style_value_from_value_logic(value)
	mut owner := unsafe { &StyleComputer(computer) }
	if owner.svg_presentation_hints_ == unsafe { nil } {
		owner.svg_presentation_hints_ = &SvgPresentationHintCache{}
	}
	mut cache := owner.svg_presentation_hints_
	if cache.entries.len < svg_presentation_hint_reuse_limit {
		cache.entries[key] = boxed
	}
	return boxed
}
