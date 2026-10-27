// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// AbstractMachine.h: TableInstance; AbstractMachine.cpp: Store table family.
module webassembly

const machine_max_allowed_table_size = u64(1024 * 1024)

// V cannot return &[]Reference: retain the actual owned vector header here.
pub struct BinaryMachineReferenceVector {
pub mut:
	values []BinaryMachineReference
}

pub struct BinaryMachineTableInstance {
mut:
	elements_       BinaryMachineReferenceVector
	module_anchors_ []&BinaryMachineModuleInstance
	type_           BinaryTableType
}

pub fn BinaryMachineTableInstance.create(type_ BinaryTableType, elements []BinaryMachineReference) BinaryMachineTableInstance {
	return BinaryMachineTableInstance{
		elements_:       BinaryMachineReferenceVector{ values: elements }
		module_anchors_: []&BinaryMachineModuleInstance{len: elements.len, init: unsafe { nil }}
		type_:           type_
	}
}

pub fn (mut instance BinaryMachineTableInstance) elements() &BinaryMachineReferenceVector {
	return &instance.elements_
}

pub fn (instance &BinaryMachineTableInstance) type_() BinaryTableType { return instance.type_ }

pub fn (mut instance BinaryMachineTableInstance) set_element(index uint, reference BinaryMachineReference, module_anchor &BinaryMachineModuleInstance) {
	instance.elements_.values[int(index)] = reference
	instance.module_anchors_[int(index)] = module_anchor
}

pub fn (instance &BinaryMachineTableInstance) module_anchor_at(index uint) &BinaryMachineModuleInstance {
	return instance.module_anchors_[int(index)]
}

pub fn (mut instance BinaryMachineTableInstance) grow(size_to_grow u32, fill_value BinaryMachineReference, fill_module_anchor &BinaryMachineModuleInstance) bool {
	if size_to_grow == 0 { return true }
	new_size := uint(instance.elements_.values.len) + uint(size_to_grow)
	if maximum := instance.type_.limits.maximum {
		if maximum < u64(new_size) { return false }
	}
	if new_size >= uint(u32(-1)) { return false }
	previous_size := instance.elements_.values.len
	// V vectors have signed-int lengths: an unrepresentable try_resize request
	// cannot allocate this vector. Other V allocation failures currently panic.
	if new_size > uint(0x7fffffff) { return false }
	unsafe { instance.elements_.values.grow_len(int(new_size) - previous_size) }
	unsafe { instance.module_anchors_.grow_len(int(new_size) - instance.module_anchors_.len) }
	for index in previous_size .. instance.elements_.values.len {
		instance.elements_.values[index] = fill_value
		instance.module_anchors_[index] = fill_module_anchor
	}
	instance.type_ = BinaryTableType{
		element_type: instance.type_.element_type
		limits:       WasmLimits{
			address_type: instance.type_.limits.address_type
			minimum:      instance.type_.limits.minimum + u64(size_to_grow)
			maximum:      instance.type_.limits.maximum
		}
	}
	return true
}

pub fn (mut store BinaryMachineStore) allocate_table(type_ BinaryTableType) ?u64 {
	if type_.limits.minimum > machine_max_allowed_table_size { return none }
	address := u64(store.tables_.len)
	mut elements := []BinaryMachineReference{cap: int(type_.limits.minimum)}
	for _ in 0 .. int(type_.limits.minimum) {
		elements << BinaryNullReference{ type_: type_.element_type }
	}
	store.tables_ << BinaryMachineTableInstance.create(type_, elements)
	return address
}

pub fn (store &BinaryMachineStore) get_table(address u64) ?&BinaryMachineTableInstance {
	if u64(store.tables_.len) <= address { return none }
	return &store.tables_[int(address)]
}

pub fn (store &BinaryMachineStore) unsafe_get_table(address u64) &BinaryMachineTableInstance {
	return unsafe { &store.tables_[int(address)] }
}
