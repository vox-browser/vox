module css

import dom
import platform

fn test_computed_sample_scan_reuses_only_complete_clean_root_inspections() {
	$if prealloc {
		mut arena := platform.new_arena('computed scan clean roots')
		defer { arena.release() }
		retiring := RetiringAnimationSamples{arena: arena}
		style := ComputedProperties.new()
		mut scan := AnimationSampleReferenceScan{retiring: &retiring, use_clean_computed: true}
		slot := animation_sample_computed_scan_slot(style)
		assert !scan.computed_references_arena_at_depth(style, 1)
		assert scan.clean_computed[slot] == unsafe { nil }
		assert !scan.computed_references_arena_at_depth(style, 0)
		assert scan.clean_computed[slot] == voidptr(style)
		assert !scan.computed_references_arena_at_depth(style, 0)
		assert scan.computed_references_arena_at_depth(style, 8)
		assert !scan.computed_references_arena_at_depth(unsafe { nil }, 0)
	}
}

fn test_computed_sample_scan_collisions_cannot_hide_a_late_sample() {
	$if prealloc {
		mut arena := platform.new_arena('computed scan collisions')
		defer { arena.release() }
		entry := arena.enter()
		sample := &dom.StyleValue{css_text: 'sample'}
		arena.leave(entry)
		retiring := RetiringAnimationSamples{arena: arena}
		mut owners := []&ComputedProperties{}
		mut by_slot := map[int]&ComputedProperties{}
		mut first := unsafe { &ComputedProperties(nil) }
		mut second := unsafe { &ComputedProperties(nil) }
		for _ in 0 .. 257 {
			style := ComputedProperties.new()
			owners << style
			slot := animation_sample_computed_scan_slot(style)
			if previous := by_slot[slot] {
				first = previous
				second = style
				break
			}
			by_slot[slot] = style
		}
		assert first != unsafe { nil } && second != unsafe { nil }
		second.set_raw_property_at_index(number_of_longhand_properties - 1, sample)
		mut scan := AnimationSampleReferenceScan{retiring: &retiring, use_clean_computed: true}
		assert !scan.computed_references_arena_at_depth(first, 0)
		assert scan.computed_references_arena_at_depth(second, 0)
		assert scan.clean_computed[animation_sample_computed_scan_slot(first)] == voidptr(first)
		assert !scan.computed_references_arena_at_depth(first, 0)
	}
}

fn test_computed_sample_scan_rechecks_mutable_payloads_between_inspections() {
	$if prealloc {
		mut arena := platform.new_arena('computed scan changing owners')
		defer { arena.release() }
		retiring := RetiringAnimationSamples{arena: arena}
		mut style := ComputedProperties.new()
		mut value := &dom.StyleValue{css_text: 'clean'}
		style.set_property_without_modifying_flags(.fill, value)
		assert !retiring.computed_references_arena(style)
		entry := arena.enter()
		borrowed := ['retired', 'text'].join(' ')
		arena.leave(entry)
		value.css_text = borrowed
		assert retiring.computed_references_arena(style)
		value.css_text = 'clean again'
		assert !retiring.computed_references_arena(style)
	}
}

fn test_computed_sample_scan_keeps_recursive_projection_depth_and_cycles() {
	$if prealloc {
		mut arena := platform.new_arena('computed scan depth policy')
		defer { arena.release() }
		retiring := RetiringAnimationSamples{arena: arena}
		leaf := ComputedProperties.new()
		mut scan := AnimationSampleReferenceScan{retiring: &retiring, use_clean_computed: true}
		assert !scan.computed_references_arena_at_depth(leaf, 0)
		mut root := leaf
		for _ in 0 .. 8 {
			mut parent := ComputedProperties.new()
			parent.device_layout_projection_ = &DeviceLayoutStyleProjection{
				scale: 2
				provenance: unsafe { nil }
				style: root
			}
			root = parent
		}
		assert scan.computed_references_arena_at_depth(root, 0)
		mut cycle := ComputedProperties.new()
		cycle.device_layout_projection_ = &DeviceLayoutStyleProjection{
			scale: 2
			provenance: unsafe { nil }
			style: cycle
		}
		assert scan.computed_references_arena_at_depth(cycle, 0)
	}
}

fn test_computed_sample_scan_temporary_memo_does_not_accumulate_in_caller_arena() {
	$if prealloc {
		mut arena := platform.new_arena('computed scan retiring owner')
		defer { arena.release() }
		retiring := RetiringAnimationSamples{arena: arena}
		style := ComputedProperties.new()
		mut caller := platform.new_arena('computed scan caller')
		defer { caller.release() }
		entry := caller.enter()
		assert !retiring.computed_references_arena(style)
		before := caller.usage().used
		for _ in 0 .. 32 { assert !retiring.computed_references_arena(style) }
		assert caller.usage().used == before
		caller.leave(entry)
	}
}
