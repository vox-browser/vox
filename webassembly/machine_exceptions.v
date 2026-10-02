// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/Types.h FunctionType and AbstractMachine.{h,cpp} tag/exception instances.
module webassembly

pub struct BinaryMachineFunctionType {
pub:
	parameters []BinaryValueType
	results    []BinaryValueType
}

pub struct BinaryMachineTagInstance {
	type_         BinaryMachineFunctionType
	defined_type_ &BinaryCanonicalType = unsafe { nil }
	flags_        u8
}

pub fn BinaryMachineTagInstance.create(type_ BinaryMachineFunctionType, defined_type &BinaryCanonicalType, flags u8) BinaryMachineTagInstance {
	return BinaryMachineTagInstance{ type_: type_, defined_type_: defined_type, flags_: flags }
}

pub fn (instance &BinaryMachineTagInstance) type_() BinaryMachineFunctionType {
	return instance.type_
}

pub fn (instance &BinaryMachineTagInstance) defined_type() &BinaryCanonicalType {
	return instance.defined_type_
}

pub fn (instance &BinaryMachineTagInstance) flags() u8 { return instance.flags_ }

pub struct BinaryMachineExceptionInstance {
	tag_    u64
	params_ []BinaryMachineValue
}

pub fn BinaryMachineExceptionInstance.create(tag u64, params []BinaryMachineValue) BinaryMachineExceptionInstance {
	return BinaryMachineExceptionInstance{ tag_: tag, params_: params }
}

pub fn (instance &BinaryMachineExceptionInstance) tag() u64 { return instance.tag_ }

pub fn (instance &BinaryMachineExceptionInstance) params() []BinaryMachineValue {
	return instance.params_
}

pub fn (mut store BinaryMachineStore) allocate_tag(type_ BinaryMachineFunctionType, defined_type &BinaryCanonicalType, flags u8) ?u64 {
	address := u64(store.tags_.len)
	store.tags_ << BinaryMachineTagInstance.create(type_, defined_type, flags)
	return address
}

pub fn (mut store BinaryMachineStore) allocate_exception(tag_address u64, params []BinaryMachineValue) ?u64 {
	address := u64(store.exceptions_.len)
	store.exceptions_ << BinaryMachineExceptionInstance.create(tag_address, params)
	return address
}

pub fn (store &BinaryMachineStore) get_tag(address u64) ?&BinaryMachineTagInstance {
	if u64(store.tags_.len) <= address { return none }
	return &store.tags_[int(address)]
}

pub fn (store &BinaryMachineStore) get_exception(address u64) ?&BinaryMachineExceptionInstance {
	if u64(store.exceptions_.len) <= address { return none }
	return &store.exceptions_[int(address)]
}

pub fn (store &BinaryMachineStore) exceptions() []BinaryMachineExceptionInstance {
	return store.exceptions_
}
