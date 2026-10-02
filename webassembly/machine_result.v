// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/AbstractMachine/AbstractMachine.h: Trap, Result and instantiation errors.
module webassembly

pub struct BinaryExternallyManagedTrap {
pub mut:
	data [64]u8
}

// This is the source's unsafe POD boundary: T must be trivially copyable and
// destructible. It does not take ownership of managed objects in those bytes.
pub fn (trap &BinaryExternallyManagedTrap) unsafe_external_object_as[T]() &T {
	assert sizeof(T) <= sizeof(trap.data)
	return unsafe { &T(&trap.data[0]) }
}

pub struct BinaryUncaughtException {
pub:
	address u64
}

pub type BinaryMachineTrapData = string | BinaryExternallyManagedTrap | BinaryUncaughtException

pub struct BinaryMachineTrap {
pub mut:
	data BinaryMachineTrapData
}

pub fn (trap BinaryMachineTrap) format() string {
	return match trap.data {
		string { trap.data }
		BinaryUncaughtException { 'uncaught exception' }
		BinaryExternallyManagedTrap { '<Externally managed Trap Data>' }
	}
}

pub fn BinaryMachineTrap.from_string(message string) BinaryMachineTrap {
	return BinaryMachineTrap{ data: message }
}

pub fn BinaryMachineTrap.from_external_object[T](object T) BinaryMachineTrap {
	assert sizeof(T) <= 64
	mut external := BinaryExternallyManagedTrap{}
	unsafe { C.memcpy(&external.data[0], &object, sizeof(T)) }
	return BinaryMachineTrap{ data: external }
}

pub struct BinaryMachineResultValues {
pub mut:
	values []BinaryMachineValue
}

pub type BinaryMachineResultData = BinaryMachineResultValues | BinaryMachineTrap

pub struct BinaryMachineResult {
mut:
	data BinaryMachineResultData
}

pub fn BinaryMachineResult.from_values(values []BinaryMachineValue) BinaryMachineResult {
	return BinaryMachineResult{ data: BinaryMachineResultValues{ values: values } }
}

pub fn BinaryMachineResult.from_trap(trap BinaryMachineTrap) BinaryMachineResult {
	return BinaryMachineResult{ data: trap }
}

pub fn (result BinaryMachineResult) is_trap() bool {
	return result.data is BinaryMachineTrap
}

pub fn (mut result BinaryMachineResult) values() &BinaryMachineResultValues {
	if result.data is BinaryMachineResultValues { return &result.data }
	panic('Result does not contain values')
}

pub fn (mut result BinaryMachineResult) trap() &BinaryMachineTrap {
	if result.data is BinaryMachineTrap { return &result.data }
	panic('Result does not contain a trap')
}

pub enum BinaryInstantiationErrorSource {
	linking
	start_function
}

pub struct BinaryInstantiationError {
pub:
	error         string = 'Unknown error'
	relevant_trap ?BinaryMachineTrap
	source        BinaryInstantiationErrorSource = .linking
}

pub enum BinaryLinkOtherError {
	invalid_imported_module
}

pub struct BinaryMachineLinkError {
pub mut:
	missing_imports []string
	other_errors    []BinaryLinkOtherError
}
