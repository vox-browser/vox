module layout

import platform

fn test_paint_plan_retires_builder_storage_and_keeps_box_identity() {
	mut box := BlockBox{ tag_name: 'root', stacking_context: true }
	for i in 0 .. 256 {
		box.children << BlockBox{
			tag_name:         'child'
			stacking_context: true
			z_index:          i % 7 - 3
			opacity:          if i % 11 == 0 { 0.0 } else { 1.0 }
		}
	}
	mut arena := platform.new_arena('retained paint plans')
	entry := arena.enter()
	entries, steps := box.compatibility_paint_plan()
	hit_steps := box.compatibility_hit_test_steps(entries.len)
	arena.leave(entry)
	assert entries.len == 257
	assert steps.len < hit_steps.len
	assert entries.cap == entries.len
	assert steps.cap == steps.len
	assert hit_steps.cap == hit_steps.len
	for step in steps {
		assert step.entry_index >= 0 && step.entry_index < entries.len
		assert voidptr(entries[step.entry_index].box) == voidptr(step.box)
	}
	for i in 0 .. box.children.len {
		mut found := false
		for step in hit_steps {
			if voidptr(step.box) == voidptr(unsafe { &box.children[i] }) { found = true }
		}
		assert found
	}
	$if prealloc {
		retained_bytes := entries.len * int(sizeof(PaintOrderEntry)) +
			(steps.len + hit_steps.len) * int(sizeof(CompatibilityPaintStep))
		assert arena.usage().used <= retained_bytes + 256
	}
	arena.release()
}
