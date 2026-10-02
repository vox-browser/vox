// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/AbstractMachine/AbstractMachine.cpp: Store memory ownership.
module webassembly

// Store's actual GC::Heap boundary. The collector is translated separately;
// implementations must execute collection, rather than substitute success.
pub interface BinaryMachineHeap {
mut:
	collect_garbage()
}

pub fn (mut store BinaryMachineStore) set_heap(heap BinaryMachineHeap) { store.heap_ = heap }

pub fn (store &BinaryMachineStore) heap() BinaryMachineHeap {
	return store.heap_ or { panic('Store.heap requires its actual GC heap') }
}

fn (mut store BinaryMachineStore) create_memory_instance(type_ WasmLimits) !&BinaryMachineMemoryInstance {
	instance := BinaryMachineMemoryInstance.create(type_) or {
		if mut heap := store.heap_ {
			heap.collect_garbage()
			return BinaryMachineMemoryInstance.create(type_)
		}
		return err
	}
	return instance
}

pub fn (mut store BinaryMachineStore) allocate_memory(type_ WasmLimits) ?u64 {
	address := u64(store.memories_.len)
	instance := store.create_memory_instance(type_) or { return none }
	store.memories_ << instance
	return address
}

pub fn (store &BinaryMachineStore) get_memory(address u64) ?&BinaryMachineMemoryInstance {
	if u64(store.memories_.len) <= address { return none }
	return store.memories_[int(address)]
}

pub fn (store &BinaryMachineStore) unsafe_get_memory(address u64) &BinaryMachineMemoryInstance {
	return unsafe { store.memories_[int(address)] }
}
