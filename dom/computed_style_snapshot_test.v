module dom

import platform

$if gcboehm ? {
	fn C.GC_gcollect()
	fn C.GC_get_total_bytes() usize
}

fn test_computed_style_default_snapshot_reads_and_resets_do_not_allocate() {
	mut properties := &CSSComputedProperties_{}
	assert sizeof(CSSComputedProperties_) <= 120
	assert properties.rare_properties_ == unsafe { nil }
	before := platform.thread_arena_usage().used
	mut before_gc := usize(0)
	$if gcboehm ? {
		before_gc = C.GC_get_total_bytes()
	}
	for _ in 0 .. 64 {
		assert properties.scrollbar_width() == 'auto'
		assert properties.view_transition_name() == none
		assert properties.anchor_names().len == 0
		assert properties.color_schemes().len == 0
		properties.set_rare_properties(CSSComputedPropertiesRareData{})
	}
	$if prealloc {
		assert platform.thread_arena_usage().used == before
	}
	$if gcboehm ? {
		assert C.GC_get_total_bytes() == before_gc
	}
	assert properties.rare_properties_ == unsafe { nil }
}

fn test_computed_style_rare_replacement_preserves_value_copies() {
	mut properties := &CSSComputedProperties_{}
	data := CSSComputedPropertiesRareData{
		scrollbar_width:      'thin'
		view_transition_name: 'first'
		anchor_names:         ['--first', '--shared']
		color_schemes:        ['light', 'dark']
	}
	properties.set_rare_properties(data)
	snapshot := *properties
	before := platform.thread_arena_usage().used
	properties.set_rare_properties(data)
	assert voidptr(properties.rare_properties_) == voidptr(snapshot.rare_properties_)
	$if prealloc {
		assert platform.thread_arena_usage().used == before
	}
	mut alias := properties
	alias.set_rare_properties(CSSComputedPropertiesRareData{ view_transition_name: '' })
	assert properties.scrollbar_width() == 'auto'
	assert properties.view_transition_name()? == ''
	assert properties.anchor_names().len == 0
	assert snapshot.scrollbar_width() == 'thin'
	assert snapshot.view_transition_name()? == 'first'
	assert snapshot.anchor_names() == ['--first', '--shared']
	assert snapshot.color_schemes() == ['light', 'dark']
	alias.set_rare_properties(CSSComputedPropertiesRareData{})
	assert properties.rare_properties_ == unsafe { nil }
	$if gcboehm ? {
		C.GC_gcollect()
	}
	assert snapshot.view_transition_name()? == 'first'
	assert snapshot.color_schemes() == ['light', 'dark']
}

fn test_computed_style_rare_inputs_and_array_getters_are_independent() {
	mut names := ['--original'.clone()]
	mut schemes := ['dark'.clone()]
	name := 'transition'.clone()
	mut properties := &CSSComputedProperties_{}
	properties.set_rare_properties(CSSComputedPropertiesRareData{
		view_transition_name: name
		anchor_names:         names
		color_schemes:        schemes
	})
	data := properties.rare_properties()
	assert data.anchor_names.data != names.data
	assert data.color_schemes.data != schemes.data
	assert voidptr(data.anchor_names[0].str) != voidptr(names[0].str)
	owned_name := data.view_transition_name or { panic('missing transition name') }
	assert voidptr(owned_name.str) != voidptr(name.str)
	names[0] = '--changed'
	schemes.clear()
	mut returned_names := properties.anchor_names()
	mut returned_schemes := properties.color_schemes()
	returned_names[0] = '--getter-change'
	returned_schemes[0] = 'light'
	assert properties.anchor_names() == ['--original']
	assert properties.color_schemes() == ['dark']
	assert properties.view_transition_name()? == 'transition'
}

fn test_computed_style_rare_publication_survives_caller_scratch_retirement() {
	mut owner := platform.new_retained_arena('computed DOM style snapshot owner')
	mut entry := owner.enter()
	mut properties := &CSSComputedProperties_{}
	scratch := platform.begin_thread_scratch('computed DOM style snapshot input')
	properties.set_rare_properties(CSSComputedPropertiesRareData{
		scrollbar_width:      'thin'.clone()
		view_transition_name: 'retained-transition'.clone()
		anchor_names:         ['--retained'.clone()]
		color_schemes:        ['dark'.clone(), 'light'.clone()]
	})
	scratch.finish()
	for _ in 0 .. 4 {
		reuse := platform.begin_thread_scratch('computed DOM style snapshot input')
		assert 'x'.repeat(4096).len == 4096
		reuse.finish()
	}
	$if gcboehm ? {
		C.GC_gcollect()
	}
	assert properties.scrollbar_width() == 'thin'
	assert properties.view_transition_name()? == 'retained-transition'
	assert properties.anchor_names() == ['--retained']
	assert properties.color_schemes() == ['dark', 'light']
	$if prealloc {
		data := properties.rare_properties()
		assert owner.arena.contains(voidptr(data))
		assert owner.arena.contains(data.scrollbar_width.str)
		name := data.view_transition_name or { panic('missing retained name') }
		assert owner.arena.contains(name.str)
		assert owner.arena.contains(data.anchor_names.data)
		assert owner.arena.contains(data.anchor_names[0].str)
		assert owner.arena.contains(data.color_schemes.data)
		assert owner.arena.contains(data.color_schemes[0].str)
		assert owner.arena.contains(data.color_schemes[1].str)
	}
	entry.finish()
	owner.release()
}
