// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
// LibGC/ExternalEntityTable.{h,cpp}.
module libgc

import math.bits

pub const external_entity_invalid_index = u32(0xffffffff)
pub const external_entity_tag_count = u16(12870)

pub struct ExternalEntityTableHandle {
pub:
	index      u32 = external_entity_invalid_index
	generation u32
}

pub fn (handle ExternalEntityTableHandle) is_valid() bool {
	return handle.index != external_entity_invalid_index && handle.generation != 0
}

pub struct ExternalEntityTableTag {
pub:
	value u16
}

pub fn (tag ExternalEntityTableTag) is_balanced() bool {
	return bits.ones_count_32(u32(tag.value)) == 8
}

pub fn balanced_external_entity_table_tag(ordinal u16) ExternalEntityTableTag {
	assert ordinal < external_entity_tag_count
	mut matching_tag := u16(0)
	for candidate := u32(0); candidate <= u32(0xffff); candidate++ {
		if bits.ones_count_32(candidate) != 8 { continue }
		if matching_tag == ordinal { return ExternalEntityTableTag{ value: u16(candidate) } }
		matching_tag++
	}
	panic('Unreachable balanced external entity table tag')
}

struct ExternalEntityTableEntry {
mut:
	generation u32 = 1
	tag        ExternalEntityTableTag
	allocated  bool
}

pub struct ExternalEntityTable {
mut:
	entries            []ExternalEntityTableEntry
	free_entry_indices []u32
}

pub fn (mut table ExternalEntityTable) allocate_entry(tag ExternalEntityTableTag) ExternalEntityTableHandle {
	assert tag.is_balanced()
	mut index := u32(0)
	if table.free_entry_indices.len == 0 {
		assert u64(table.entries.len) < u64(external_entity_invalid_index)
		index = u32(table.entries.len)
		table.entries << ExternalEntityTableEntry{}
	} else {
		index = table.free_entry_indices.pop()
	}
	mut entry := unsafe { &table.entries[int(index)] }
	assert !entry.allocated
	entry.allocated = true
	entry.tag = tag
	return ExternalEntityTableHandle{ index: index, generation: entry.generation }
}

pub fn (table &ExternalEntityTable) is_valid(handle ExternalEntityTableHandle, expected_tag ExternalEntityTableTag) bool {
	return table.entry_for(handle, expected_tag) != unsafe { nil }
}

pub fn (mut table ExternalEntityTable) free_entry(handle ExternalEntityTableHandle, expected_tag ExternalEntityTableTag) {
	mut entry := table.entry_for(handle, expected_tag)
	if entry == unsafe { nil } { return }
	entry.allocated = false
	entry.generation++
	if entry.generation == 0 { entry.generation++ }
	table.free_entry_indices << handle.index
}

fn (table &ExternalEntityTable) entry_for(handle ExternalEntityTableHandle, expected_tag ExternalEntityTableTag) &ExternalEntityTableEntry {
	if !handle.is_valid() || u64(handle.index) >= u64(table.entries.len) { return unsafe { nil } }
	entry := unsafe { &table.entries[int(handle.index)] }
	if !entry.allocated || entry.generation != handle.generation || entry.tag != expected_tag {
		return unsafe { nil }
	}
	return entry
}
