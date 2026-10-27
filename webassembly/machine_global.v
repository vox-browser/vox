// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/AbstractMachine/AbstractMachine.h: GlobalInstance; .cpp: Store globals.
module webassembly

@[heap]
pub struct BinaryMachineGlobalInstance {
mut:
	mutable_ bool
	value_   BinaryMachineValue
	type_    BinaryValueType
}

pub fn BinaryMachineGlobalInstance.create(value BinaryMachineValue, mutable_ bool, type_ BinaryValueType) &BinaryMachineGlobalInstance {
	return &BinaryMachineGlobalInstance{ mutable_: mutable_, value_: value, type_: type_ }
}

pub fn (global &BinaryMachineGlobalInstance) is_mutable() bool { return global.mutable_ }

pub fn (global &BinaryMachineGlobalInstance) value() BinaryMachineValue { return global.value_ }

pub fn (global &BinaryMachineGlobalInstance) type_() BinaryGlobalType {
	return BinaryGlobalType{ type_: global.type_, mutable_: global.mutable_ }
}

pub fn (mut global BinaryMachineGlobalInstance) set_value(value BinaryMachineValue) {
	assert global.mutable_
	global.value_ = value
}

pub fn BinaryMachineGlobalInstance.value_offset() uint {
	return __offsetof(BinaryMachineGlobalInstance, value_)
}

// Source-owned stable instance pointers and real vector-index store addresses.
// Other Store allocation families and active Configuration/Heap integration
// are translated separately; this record is not an instruction executor.
@[heap]
pub struct BinaryMachineStore {
mut:
	functions_             []BinaryMachineFunctionInstance
	memories_              []&BinaryMachineMemoryInstance
	tables_                []BinaryMachineTableInstance
	globals_               []&BinaryMachineGlobalInstance
	datas_                 []BinaryMachineDataInstance
	elements_              []BinaryMachineElementInstance
	tags_                  []BinaryMachineTagInstance
	exceptions_            []BinaryMachineExceptionInstance
	heap_                  ?BinaryMachineHeap
	active_configurations_ BinaryMachineActiveConfigurations
}

pub fn BinaryMachineStore.create() &BinaryMachineStore { return &BinaryMachineStore{} }

pub fn (mut store BinaryMachineStore) allocate_global(type_ BinaryGlobalType, value BinaryMachineValue) ?u64 {
	address := u64(store.globals_.len)
	store.globals_ << BinaryMachineGlobalInstance.create(value, type_.mutable_, type_.type_)
	return address
}

pub fn (store &BinaryMachineStore) get_global(address u64) ?&BinaryMachineGlobalInstance {
	if u64(store.globals_.len) <= address { return none }
	return store.globals_[int(address)]
}

pub fn (store &BinaryMachineStore) unsafe_get_global(address u64) &BinaryMachineGlobalInstance {
	return unsafe { store.globals_[int(address)] }
}

pub fn (store &BinaryMachineStore) globals() []&BinaryMachineGlobalInstance {
	return store.globals_
}
