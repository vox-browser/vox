module libgc

fn test_external_entity_tags_preserve_balanced_ordinal_enumeration() {
	assert balanced_external_entity_table_tag(0).value == 0x00ff
	assert balanced_external_entity_table_tag(1).value == 0x017f
	assert balanced_external_entity_table_tag(12869).value == 0xff00
	assert !ExternalEntityTableTag{}.is_balanced()
	assert !ExternalEntityTableTag{ value: 0xffff }.is_balanced()
	for ordinal in [u16(0), 1, 8, 6400, 12869] {
		assert balanced_external_entity_table_tag(ordinal).is_balanced()
	}
}

fn test_external_entity_handles_reject_stale_wrong_tag_and_invalid_generation() {
	mut table := ExternalEntityTable{}
	tag := balanced_external_entity_table_tag(0)
	other_tag := balanced_external_entity_table_tag(1)
	first := table.allocate_entry(tag)
	second := table.allocate_entry(other_tag)
	assert first.index == 0 && first.generation == 1 && second.index == 1
	assert first.is_valid() && table.is_valid(first, tag)
	assert !table.is_valid(first, other_tag)
	assert !ExternalEntityTableHandle{}.is_valid()
	assert !ExternalEntityTableHandle{ index: 0 }.is_valid()
	assert !table.is_valid(ExternalEntityTableHandle{ index: 999, generation: 1 }, tag)
	table.free_entry(first, other_tag)
	assert table.is_valid(first, tag)
	table.free_entry(first, tag)
	table.free_entry(first, tag)
	table.free_entry(second, other_tag)
	assert !table.is_valid(first, tag) && !table.is_valid(second, other_tag)
	assert table.free_entry_indices == [u32(0), 1]
	reused_second := table.allocate_entry(tag)
	reused_first := table.allocate_entry(other_tag)
	assert reused_second.index == 1 && reused_second.generation == 2
	assert reused_first.index == 0 && reused_first.generation == 2
	assert table.is_valid(reused_second, tag) && table.is_valid(reused_first, other_tag)
	assert !table.is_valid(second, other_tag)
}

fn test_external_entity_generation_wrap_skips_the_invalid_zero_generation() {
	mut table := ExternalEntityTable{}
	tag := balanced_external_entity_table_tag(0)
	initial := table.allocate_entry(tag)
	table.entries[int(initial.index)].generation = u32(0xffffffff)
	last_generation := ExternalEntityTableHandle{ index: initial.index, generation: u32(0xffffffff) }
	assert table.is_valid(last_generation, tag)
	table.free_entry(last_generation, tag)
	next := table.allocate_entry(tag)
	assert next.index == initial.index && next.generation == 1
	assert table.is_valid(next, tag) && !table.is_valid(last_generation, tag)
}
