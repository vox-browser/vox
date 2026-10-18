module layout

import css
import dom

// A validated ordinary subtree has no generated boxes or list-item markers.
// Without counter operations, every descendant inherits the root's resolved
// counter set unchanged. Read live style slots so direct computed-value writes
// cannot make a cached validation hide a new operation.
fn retained_flow_has_no_counter_operations(elements []&dom.Element) bool {
	if elements.len == 0 { return false }
	for element in elements {
		properties := css.computed_properties_for_element(element) or { return false }
		values := unsafe { &css.ComputedValues(properties) }
		if properties.display().is_list_item() || values.counter_reset().len != 0
			|| values.counter_increment().len != 0 || values.counter_set().len != 0 {
			return false
		}
	}
	return true
}

fn resolve_retained_flow_counters(retained RetainedFlowSubtree, mut builder TreeBuilderState) {
	can_pass := retained_flow_has_no_counter_operations(retained.elements)
	for index, element in retained.elements {
		properties := css.computed_properties_for_element(element) or { continue }
		resolve_layout_counters(mut builder, dom.AbstractElement.new(element, none), properties)
		if index == 0 && can_pass {
			// Resolve the root normally so its external parent/sibling state is
			// current. Publish independent DOM snapshots, exactly as the full
			// resolver does, including clearing old sets when the input is empty.
			mut counters := ?css.CountersSet(none)
			if current := builder.counter_sets[builder.last_processed_key] { counters = current }
			for descendant in retained.elements[1..] {
				mut target := dom.AbstractElement.new(descendant, none)
				css.set_counters_set_for_abstract_element(mut target, counters)
			}
			// Internal entries need not be stored in this fresh builder:
			// no later sibling outside the subtree can consult its internal child
			// lists. Preserve the exact order of all following counter creators.
			builder.counter_tree_order_index += i64(retained.elements.len - 1)
			last := dom.AbstractElement.new(retained.elements.last(), none)
			builder.last_processed_key = abstract_element_counter_key(&last)
			if current := counters {
				builder.counter_sets[builder.last_processed_key] = current
			} else {
				builder.counter_sets.delete(builder.last_processed_key)
			}
			return
		}
	}
}
