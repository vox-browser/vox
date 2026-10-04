// Copyright (c) 2021, Ali Mohammad Pur <mpfard@serenityos.org>
// SPDX-License-Identifier: BSD-2-Clause
// LibWasm/AbstractMachine/Interpreter.h and AbstractMachine.h::HostVisitOps.
// The execution backend remains an owner supplied through this interface.
module webassembly

pub struct BinaryMachineHostVisitOps {
pub:
	visit_trap fn (mut BinaryExternallyManagedTrap) @[required]
}

pub interface BinaryMachineInterpreter {
	trap() BinaryMachineTrap
	did_trap() bool
mut:
	interpret(mut BinaryMachineConfiguration)
	clear_trap()
	visit_external_resources(BinaryMachineHostVisitOps)
}

// This empty default is the exact source Interpreter visitor body. It is
// separate from interpret(), for which the source has no default backend.
pub struct BinaryMachineInterpreterBase {}

pub fn (mut base BinaryMachineInterpreterBase) visit_external_resources(_ BinaryMachineHostVisitOps) {}
