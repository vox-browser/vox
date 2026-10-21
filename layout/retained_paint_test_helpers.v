module layout

import css
import painting

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
	} $else $if T is &css.LengthQueryContainerCache || T is &PaintSRGBColor
		|| T is &PaintSVGSolidColorData || T is &PaintSVGGradientData
		|| T is &PaintLocalBorderData || T is &PaintBoxShadowData
		|| T is &PaintBackgroundLayerData || T is &PaintImageData
		|| T is &PaintSVGPathData || T is &LinearGradient
		|| T is &painting.TableCellCoordinates || T is &painting.BordersDataWithElementKind
		|| T is &painting.FieldSetPaintable || T is &CompatibilityOverlayData
		|| T is &CompatibilityOverflowClip || T is &LayoutRect
		|| T is &painting.ClipPathVisualData || T is &painting.SVGClipVisualData
		|| T is &painting.SVGMaskVisualData
		|| T is &PaintClip || T is &PaintClipList
		|| T is &PaintVisualLayer || T is &PaintVisualLayerList
		|| T is &painting.ImagePaintable || T is &painting.CanvasPaintable
		|| T is &painting.VideoPaintable || T is &painting.NavigableContainerViewportPaintable
		|| T is &painting.SVGPatternPaintStyle || T is &painting.GfxFilter {
		// These are finite value snapshots, independently allocated by reference
		// builders. Recurse through their payloads, stopping at borrowed owners.
		if voidptr(actual) == voidptr(expected) { return true }
		if voidptr(actual) == unsafe { nil } || voidptr(expected) == unsafe { nil } { return false }
		return retained_paint_payload_equal(*actual, *expected)
	} $else $if T is $pointer {
		return voidptr(actual) == voidptr(expected)
	} $else $if T is css.StyleValue {
		return actual.equals(expected)
	} $else $if T is painting.ResolvedCSSFilter {
		return retained_paint_payload_equal(actual.operations, expected.operations)
			&& retained_paint_payload_equal(actual.svg_filter_bounds(), expected.svg_filter_bounds())
			&& retained_paint_payload_equal(actual.to_gfx_filter(1.0), expected.to_gfx_filter(1.0))
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

