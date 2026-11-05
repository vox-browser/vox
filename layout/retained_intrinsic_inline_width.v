module layout

import css
import dom
import os
import platform

const disable_retained_intrinsic_inline_width = os.getenv('VOX_DISABLE_RETAINED_INTRINSIC_INLINE_WIDTH') != ''
const retained_intrinsic_inline_width_diagnostics = os.getenv('VOX_RETAINED_INTRINSIC_INLINE_WIDTH_DIAGNOSTICS') != ''

__global retained_intrinsic_inline_width_reported bool

struct IntrinsicInlineWidth {
	key InlineMeasurementKey
	inputs []RetainedInlineInput
	contexts []IntrinsicInlineWidthContext
	font_generation u64
	font_policy dom.FontRenderingPolicy
	style_environment u64
	document_viewport dom.Rect
	document_scale f64
	width CSSPixels
}

struct IntrinsicInlineWidthContext {
	viewport css.CSSPixelRect
	scale f64
}

@[heap]
struct IntrinsicInlineWidthCache {
mut:
	entries []IntrinsicInlineWidth
}

// Only measure_disposable_inline_width calls this cache, after proving a
// closed horizontal text context. Its caller consumes the scalar width and
// discards all probe geometry. Unlike line-layout entries, these scalars can
// survive the measurement pool without retaining glyph runs or UsedValues.
fn retained_intrinsic_inline_width(container &BlockContainer, used &UsedValues,
	space AvailableSpace) ?CSSPixels {
	if disable_retained_intrinsic_inline_width
		|| container.retained_intrinsic_inline_widths_ == unsafe { nil } { return none }
	root := unsafe { &Node(container) }
	key := inline_measurement_key(used, .intrinsic_sizing, space, true)
	font_generation := css.css_style_computer_for(root.document()).font_computer().environment_generation()
	for entry in container.retained_intrinsic_inline_widths_.entries {
		if entry.key != key || entry.font_generation != font_generation
			|| entry.font_policy != root.document().font_rendering_policy()
			|| entry.style_environment != root.document().style_environment_version()
			|| entry.document_viewport != root.document().viewport_rect()
			|| entry.document_scale != root.document().layout_coordinate_scale()
			|| !intrinsic_inline_width_inputs_are_current(entry) { continue }
		if retained_intrinsic_inline_width_diagnostics && !retained_intrinsic_inline_width_reported {
			retained_intrinsic_inline_width_reported = true
			eprintln('Vox intrinsic inline width: reused validated scalar across probes')
		}
		return entry.width
	}
	return none
}

fn intrinsic_inline_width_inputs_are_current(entry &IntrinsicInlineWidth) bool {
	if !inline_measurement_inputs_are_current(entry.inputs)
		|| !retained_layout_fonts_are_current(entry.inputs) { return false }
	// These resolved contexts can change without a raw-property mutation.
	// A within-pass line cache does not cross that boundary, but this one does.
	for index, input in entry.inputs {
		style := input.node.computed_values()
		if style.viewport_rect_ != entry.contexts[index].viewport
			|| style.layout_coordinate_scale() != entry.contexts[index].scale { return false }
	}
	return true
}

fn retain_intrinsic_inline_width(container &BlockContainer, key InlineMeasurementKey,
	width CSSPixels) {
	if disable_retained_intrinsic_inline_width { return }
	// Cache records and cloned text belong to the document, never the probe's
	// scratch arena. Tests without a document owner use persistent allocation.
	persistent := platform.enter_persistent_if(platform.transient_arena_entered()
		&& platform.current_retained_arena() == unsafe { nil })
	defer { platform.leave_persistent(persistent) }
	mut retained := platform.enter_retained_allocations()
	defer { retained.finish() }
	root := unsafe { &Node(container) }
	mut inputs := []RetainedInlineInput{}
	if !collect_retained_inline_inputs(root, true, mut inputs) { return }
	mut owned_inputs := []RetainedInlineInput{cap: inputs.len}
	mut contexts := []IntrinsicInlineWidthContext{cap: inputs.len}
	for input in inputs {
		owned_inputs << RetainedInlineInput{ ...input, text: input.text.clone() }
		contexts << IntrinsicInlineWidthContext{
			viewport: input.style.viewport_rect_
			scale: input.style.layout_coordinate_scale()
		}
	}
	entry := IntrinsicInlineWidth{
		key: key
		inputs: owned_inputs
		contexts: contexts
		font_generation: css.css_style_computer_for(root.document()).font_computer().environment_generation()
		font_policy: root.document().font_rendering_policy()
		style_environment: root.document().style_environment_version()
		document_viewport: root.document().viewport_rect()
		document_scale: root.document().layout_coordinate_scale()
		width: width
	}
	mut mutable := unsafe { &BlockContainer(container) }
	if mutable.retained_intrinsic_inline_widths_ == unsafe { nil } {
		mutable.retained_intrinsic_inline_widths_ = &IntrinsicInlineWidthCache{}
	}
	mut cache := mutable.retained_intrinsic_inline_widths_
	// There are normally just min/max-content entries. Bound retained history
	// when definite height or another exact measurement input changes.
	if cache.entries.len == 4 { cache.entries.delete(0) }
	cache.entries << entry
}
