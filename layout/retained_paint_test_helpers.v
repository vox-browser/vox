module layout

import css

// Paint payloads borrow their document, layout and glyph owners. Comparing a
// recursively generated str() walks those owners' complete object graphs and
// can exhaust memory before an assertion finishes. Compare payload fields and
// borrowed owner identities instead, without formatting either graph.
fn retained_optional_paint_payload_equal[T](actual ?T, expected ?T) bool {
	if left := actual {
		if right := expected {
			return retained_paint_payload_equal[T](left, right)
		}
		return false
	}
	return expected == none
}

fn retained_paint_payload_equal[T](actual T, expected T) bool {
	$if T is $option {
		return retained_optional_paint_payload_equal(actual, expected)
	} $else $if T is &css.LengthQueryContainerCache {
		if voidptr(actual) == voidptr(expected) { return true }
		if voidptr(actual) == unsafe { nil } || voidptr(expected) == unsafe { nil } { return false }
		return retained_paint_payload_equal(*actual, *expected)
	} $else $if T is $pointer {
		return voidptr(actual) == voidptr(expected)
	} $else $if T is css.StyleValue {
		return actual.equals(expected)
	} $else $if T is $array {
		if actual.len != expected.len { return false }
		for index in 0 .. actual.len {
			if !retained_paint_payload_equal(actual[index], expected[index]) { return false }
		}
		return true
	} $else $if T is css.CalculationResolutionContext {
		if left := actual.anchor_resolver {
			if right := expected.anchor_resolver {
				if voidptr(left) != voidptr(right) { return false }
			} else {
				return false
			}
		} else if expected.anchor_resolver != none {
			return false
		}
		return retained_paint_payload_equal(actual.percentage_basis, expected.percentage_basis)
			&& retained_paint_payload_equal(actual.length_resolution_context, expected.length_resolution_context)
			&& retained_paint_payload_equal(actual.abstract_element, expected.abstract_element)
			&& actual.anchor_resolver_context == expected.anchor_resolver_context
	} $else $if T is $struct {
		$for field in T.fields {
			if !retained_paint_payload_equal(actual.$(field.name), expected.$(field.name)) {
				return false
			}
		}
		return true
	} $else {
		return actual == expected
	}
}

