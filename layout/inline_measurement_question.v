module layout

import os

const disable_closed_inline_measurement_question_reuse = os.getenv('VOX_DISABLE_CLOSED_INLINE_MEASUREMENT_QUESTION_REUSE') != ''

// Called only after inline_measurement_root_is_closed(): no atomic boxes,
// floats, positioned descendants or clamping can consume available height or
// distinguish intrinsic from normal line layout. The caller still owns the
// root's height and constraints; retain those fields in the key.
fn closed_inline_measurement_key(used &UsedValues, mode LayoutMode, space AvailableSpace,
	width_only bool) InlineMeasurementKey {
	key := inline_measurement_key(used, mode, space, width_only)
	if disable_closed_inline_measurement_question_reuse { return key }
	return InlineMeasurementKey{
		...key
		mode: .normal
		space: AvailableSpace.new(space.width, AvailableSize.make_indefinite())
	}
}
