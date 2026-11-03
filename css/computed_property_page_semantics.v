module css

import dom
import os
import sync.stdatomic

const disable_semantic_property_pages = os.getenv('VOX_DISABLE_SEMANTIC_PROPERTY_PAGES') != ''
const semantic_property_page_diagnostics = os.getenv('VOX_SEMANTIC_PROPERTY_PAGE_DIAGNOSTICS') != ''

fn computed_page_edge_is_scalar(value &EdgeStyleValue) bool {
	if offset := style_value_from_optional_storage(value.offset_) {
		return computed_page_value_is_scalar(&offset)
	}
	return true
}

// Resource-bearing values keep their existing pointer identity. These immutable
// scalar/container values have complete typed equality and no stylesheet,
// element, font or fetch client hidden behind equal serialization.
fn computed_page_value_is_scalar(value &StyleValue) bool {
	return match value {
		KeywordStyleValue, LengthStyleValue, ColorStyleValue, NumberStyleValue,
		IntegerStyleValue, PercentageStyleValue, StringStyleValue, CustomIdentStyleValue,
		AngleStyleValue, DisplayStyleValue, FlexStyleValue, FrequencyStyleValue,
		ResolutionStyleValue, TimeStyleValue, GridAutoFlowStyleValue, RepeatStyleStyleValue { true }
		StyleValueList {
			mut scalar := true
			for child in value.values_ {
				if !computed_page_value_is_scalar(&child) { scalar = false; break }
			}
			scalar
		}
		SuperellipseStyleValue {
			value.parameter_.len == 1 && computed_page_value_is_scalar(&value.parameter_[0])
		}
		RGBColorStyleValue {
			value.r_.len == 1 && value.g_.len == 1 && value.b_.len == 1 && value.alpha_.len == 1
				&& computed_page_value_is_scalar(&value.r_[0])
				&& computed_page_value_is_scalar(&value.g_[0])
				&& computed_page_value_is_scalar(&value.b_[0])
				&& computed_page_value_is_scalar(&value.alpha_[0])
		}
		FontStyleStyleValue {
			if angle := style_value_from_optional_storage(value.angle_value_) {
				computed_page_value_is_scalar(&angle)
			} else { true }
		}
		EdgeStyleValue { computed_page_edge_is_scalar(value) }
		PositionStyleValue {
			computed_page_edge_is_scalar(&value.edge_x_) && computed_page_edge_is_scalar(&value.edge_y_)
		}
		BackgroundSizeStyleValue {
			value.size_x_.len == 1 && value.size_y_.len == 1
				&& computed_page_value_is_scalar(&value.size_x_[0])
				&& computed_page_value_is_scalar(&value.size_y_[0])
		}
		BorderImageSliceStyleValue {
			value.top_.len == 1 && value.right_.len == 1 && value.bottom_.len == 1 && value.left_.len == 1
				&& computed_page_value_is_scalar(&value.top_[0])
				&& computed_page_value_is_scalar(&value.right_[0])
				&& computed_page_value_is_scalar(&value.bottom_[0])
				&& computed_page_value_is_scalar(&value.left_[0])
		}
		RatioStyleValue {
			value.numerator_.len == 1 && value.denominator_.len == 1
				&& computed_page_value_is_scalar(&value.numerator_[0])
				&& computed_page_value_is_scalar(&value.denominator_[0])
		}
		BorderRadiusStyleValue {
			value.horizontal_radius.len == 1 && value.vertical_radius.len == 1
				&& computed_page_value_is_scalar(&value.horizontal_radius[0])
				&& computed_page_value_is_scalar(&value.vertical_radius[0])
		}
		BorderRadiusRectStyleValue {
			value.top_left_.len == 1 && value.top_right_.len == 1
				&& value.bottom_left_.len == 1 && value.bottom_right_.len == 1
				&& computed_page_value_is_scalar(&value.top_left_[0])
				&& computed_page_value_is_scalar(&value.top_right_[0])
				&& computed_page_value_is_scalar(&value.bottom_left_[0])
				&& computed_page_value_is_scalar(&value.bottom_right_[0])
		}
		TextIndentStyleValue {
			value.length_percentage_.len == 1 && computed_page_value_is_scalar(&value.length_percentage_[0])
		}
		else { false }
	}
}

fn computed_page_scalar_box(value &dom.StyleValue) ?&TypedStyleValueBox {
	if value.css_value_handle == unsafe { nil } { return none }
	box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	if !computed_page_value_is_scalar(&box.value) { return none }
	return box
}

fn computed_page_semantic_hash(page &ComputedPropertyPage) u64 {
	cached := stdatomic.load_u64(&page.semantic_hash_)
	if cached != 0 { return cached }
	mut key := u64(14695981039346656037)
	for value in page.values {
		if value == unsafe { nil } {
			key = (key ^ u64(0)) * 1099511628211
			continue
		}
		if _ := computed_page_scalar_box(value) {
			// Text only selects a bucket. Complete typed equality below separates
			// rounded serializations, color syntax, units and non-reflexive values.
			key = (key ^ u64(1)) * 1099511628211
			key = (key ^ u64(value.css_text.len)) * 1099511628211
			for byte in value.css_text { key = (key ^ u64(byte)) * 1099511628211 }
		} else {
			key = (key ^ u64(voidptr(value))) * 1099511628211
		}
	}
	if key == 0 { key = 1 }
	mut mutable := unsafe { &ComputedPropertyPage(page) }
	stdatomic.store_u64(&mutable.semantic_hash_, key)
	return key
}

fn computed_page_semantic_values_equal(first &ComputedPropertyPage, second &ComputedPropertyPage) bool {
	for index, value in first.values {
		other := second.values[index]
		if voidptr(value) == voidptr(other) { continue }
		if value == unsafe { nil } || other == unsafe { nil } || value.css_text != other.css_text { return false }
		a := computed_page_scalar_box(value) or { return false }
		b := computed_page_scalar_box(other) or { return false }
		equal := if retain_style_value_union_comparisons {
			a.value.equals(b.value)
		} else { scalar_style_values_equal(&a.value, &b.value) }
		if !equal { return false }
	}
	return true
}

fn (mut pool ComputedPropertyPageInterner) intern_semantic_page(page &ComputedPropertyPage) &ComputedPropertyPage {
	key := computed_page_semantic_hash(page)
	for previous in pool.semantic_pages[key] {
		if computed_page_semantic_values_equal(previous, page) {
			if semantic_property_page_diagnostics {
				pool.semantic_hits++
				if pool.semantic_hits <= 10 { eprintln('VOX_SEMANTIC_PROPERTY_PAGE reused=${pool.semantic_hits}') }
			}
			return previous
		}
	}
	if pool.semantic_pages.len < computed_property_page_pool_limit && pool.semantic_pages[key].len < 8 {
		pool.semantic_pages[key] << unsafe { page }
	}
	return page
}
