module css

import dom
import os
import sync.stdatomic

const retain_keyframe_scalar_context = os.getenv('VOX_RETAIN_KEYFRAME_SCALAR_CONTEXT') != ''
const keyframe_scalar_context_diagnostics = os.getenv('VOX_KEYFRAME_SCALAR_CONTEXT_DIAGNOSTICS') != ''
__global keyframe_scalar_context_reported stdatomic.AtomicVal[bool]

// These transform arguments are unchanged by absolutization in the keyframe
// computation's CSS-pixel context. Relative lengths, calculations and other
// compound values keep the full context and its dependency tracking.
fn keyframe_transform_arguments_are_resolved(value TransformationStyleValue) bool {
	for argument in value.values_ {
		match argument {
			NumberStyleValue, AngleStyleValue, PercentageStyleValue {}
			LengthStyleValue { if !argument.length_.is_px() { return false } }
			else { return false }
		}
	}
	return true
}

fn keyframe_transform_is_resolved(value &StyleValue) bool {
	match value {
		KeywordStyleValue { return value.keyword_ == .none_ }
		TransformationStyleValue { return keyframe_transform_arguments_are_resolved(value) }
		StyleValueList {
			for item in value.values_ {
				if item !is TransformationStyleValue { return false }
				if !keyframe_transform_arguments_are_resolved(item) { return false }
			}
			return true
		}
		else { return false }
	}
}

// Specified values have already had substitution functions and CSS-wide
// keywords resolved, and logical aliases mapped, before reaching this helper.
// Reuse the cascade's existing scalar proof. Opacity still runs its ordinary
// clamping/conversion algorithm; it does not require length/font context.
fn keyframe_value_without_context(id PropertyID, value &dom.StyleValue) ?&dom.StyleValue {
	if retain_keyframe_scalar_context { return none }
	mut resolved := ?&dom.StyleValue(none)
	if computed_scalar_value_is_resolved(id, value) {
		resolved = value
	} else if id == .transform || id in [.opacity, .fill_opacity, .flood_opacity,
		.shape_image_threshold, .stop_opacity, .stroke_opacity] {
		if typed := typed_style_value_logic_from_dom(value) {
			if id == .transform {
				if keyframe_transform_is_resolved(&typed) { resolved = value }
			} else if typed is NumberStyleValue || typed is PercentageStyleValue {
				resolved = StyleComputer.compute_opacity(value)
			}
		}
	}
	result := resolved or { return none }
	if keyframe_scalar_context_diagnostics && keyframe_scalar_context_reported.compare_and_swap(false, true) {
		eprintln('Vox keyframe scalar context: resolved value computed without font context')
	}
	return result
}
