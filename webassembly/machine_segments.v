// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/AbstractMachine/AbstractMachine.{h,cpp}: data and element instances/store.
module webassembly

pub struct BinaryMachineDataInstance {
mut:
	data_ BinaryMachineDataVector
}

// V forbids returning &[]u8. Keep the source vector header in a record so its
// mutable accessor still reaches the actual owned length, capacity and bytes.
pub struct BinaryMachineDataVector {
pub mut:
	bytes []u8
}

pub fn BinaryMachineDataInstance.create(data []u8) BinaryMachineDataInstance {
	return BinaryMachineDataInstance{ data_: BinaryMachineDataVector{ bytes: data } }
}

pub fn (instance &BinaryMachineDataInstance) size() uint { return uint(instance.data_.bytes.len) }

pub fn (mut instance BinaryMachineDataInstance) data() &BinaryMachineDataVector {
	return &instance.data_
}

pub struct BinaryMachineElementInstance {
	type_       BinaryValueType
	references_ []BinaryMachineReference
}

pub fn BinaryMachineElementInstance.create(type_ BinaryValueType, references []BinaryMachineReference) BinaryMachineElementInstance {
	return BinaryMachineElementInstance{ type_: type_, references_: references }
}

pub fn (instance &BinaryMachineElementInstance) type_() BinaryValueType { return instance.type_ }

pub fn (instance &BinaryMachineElementInstance) references() []BinaryMachineReference {
	return instance.references_
}

pub fn (mut store BinaryMachineStore) allocate_data(initializer []u8) ?u64 {
	address := u64(store.datas_.len)
	store.datas_ << BinaryMachineDataInstance.create(initializer)
	return address
}

pub fn (mut store BinaryMachineStore) allocate_element(type_ BinaryValueType, references []BinaryMachineReference) ?u64 {
	address := u64(store.elements_.len)
	store.elements_ << BinaryMachineElementInstance.create(type_, references)
	return address
}

pub fn (store &BinaryMachineStore) get_data(address u64) ?&BinaryMachineDataInstance {
	if u64(store.datas_.len) <= address { return none }
	return &store.datas_[int(address)]
}

pub fn (store &BinaryMachineStore) get_element(address u64) ?&BinaryMachineElementInstance {
	if u64(store.elements_.len) <= address { return none }
	return &store.elements_[int(address)]
}

pub fn (store &BinaryMachineStore) elements() []BinaryMachineElementInstance {
	return store.elements_
}
