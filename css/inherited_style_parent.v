module css

import dom
import os

const retain_repeated_inherited_parent = os.getenv('VOX_RETAIN_REPEATED_INHERITED_PARENT') != ''
const inherited_parent_diagnostics = os.getenv('VOX_INHERITED_PARENT_DIAGNOSTICS') != ''

__global inherited_parent_reported bool

// The synchronous inherited-property loop mutates only the child's values.
// Borrow its current inheritance parent once, while reading that parent's live
// property and animation stores for each property. Nothing survives the call.
fn non_animated_inherit_value_from_parent(property_id PropertyID, parent ?&ComputedProperties) &dom.StyleValue {
	if source := parent {
		return source.property(property_id, .no) or {
			computed_interpolation_property_initial_value(property_id)
		}
	}
	return computed_interpolation_property_initial_value(property_id)
}

fn animated_inherit_value_from_parent(property_id PropertyID, parent ?&ComputedProperties) ?AnimatedInheritValue {
	source := parent or { return none }
	value := source.animated_property_value(property_id) or { return none }
	return AnimatedInheritValue{
		value: value
		is_result_of_transition: if source.is_animated_property_result_of_transition(property_id) { .yes } else { .no }
	}
}

fn report_inherited_parent_reuse(computed &ComputedProperties, parent ?&ComputedProperties) {
	if !inherited_parent_diagnostics || retain_repeated_inherited_parent
		|| inherited_parent_reported || parent == none { return }
	mut properties := computed.inherited_property_iterator()
	if _ := properties.next() {
		inherited_parent_reported = true
		eprintln('Vox inherited style: reused synchronous parent lookup')
	}
}
