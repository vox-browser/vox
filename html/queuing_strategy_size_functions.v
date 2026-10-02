// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// UniversalGlobalScope.cpp and WindowOrWorkerGlobalScope.cpp: retained builtin
// size functions. Native function creation/GetV belong to the actual engine.
module html

import webidl

pub type QueuingStrategyNativeFunctionCreator = fn (bool) !&webidl.CallbackType

@[heap]
struct GlobalQueuingStrategySizeFunctions {
mut:
	creator ?QueuingStrategyNativeFunctionCreator
	count ?&webidl.CallbackType
	byte_length ?&webidl.CallbackType
}

fn (mut functions GlobalQueuingStrategySizeFunctions) function(byte_length bool) !&webidl.CallbackType {
	if byte_length {
		if cached := functions.byte_length { return cached }
	} else {
		if cached := functions.count { return cached }
	}
	creator := functions.creator or {
		return error('Queuing strategy builtin function requires the owning engine creator')
	}
	callback := creator(byte_length)!
	if byte_length { functions.byte_length = callback } else { functions.count = callback }
	return callback
}

fn (mut functions GlobalQueuingStrategySizeFunctions) install(creator QueuingStrategyNativeFunctionCreator) ! {
	if functions.count != none || functions.byte_length != none || functions.creator != none {
		return error('Queuing strategy builtin functions already have an owning engine')
	}
	functions.creator = creator
}

fn (mut scope UniversalGlobalScopeMixin) strategy_functions() &GlobalQueuingStrategySizeFunctions {
	if isnil(scope.queuing_strategy_size_functions_) {
		scope.queuing_strategy_size_functions_ = &GlobalQueuingStrategySizeFunctions{}
	}
	return scope.queuing_strategy_size_functions_
}

pub fn (mut scope UniversalGlobalScopeMixin) install_queuing_strategy_function_creator(creator QueuingStrategyNativeFunctionCreator) ! {
	mut functions := scope.strategy_functions()
	functions.install(creator)!
}

// The existing scalar helpers are explicit standalone adapters; source getters
// return these retained CallbackType records representing actual JS functions.
pub fn (mut scope UniversalGlobalScopeMixin) count_queuing_strategy_size_callback() !&webidl.CallbackType {
	mut functions := scope.strategy_functions()
	return functions.function(false)
}

pub fn (mut scope UniversalGlobalScopeMixin) byte_length_queuing_strategy_size_callback() !&webidl.CallbackType {
	mut functions := scope.strategy_functions()
	return functions.function(true)
}

fn (mut scope WindowOrWorkerGlobalScopeMixin) strategy_functions() &GlobalQueuingStrategySizeFunctions {
	if isnil(scope.queuing_strategy_size_functions_) {
		scope.queuing_strategy_size_functions_ = &GlobalQueuingStrategySizeFunctions{}
	}
	return scope.queuing_strategy_size_functions_
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) install_queuing_strategy_function_creator(creator QueuingStrategyNativeFunctionCreator) ! {
	mut functions := scope.strategy_functions()
	functions.install(creator)!
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) count_queuing_strategy_size_callback() !&webidl.CallbackType {
	mut functions := scope.strategy_functions()
	return functions.function(false)
}

pub fn (mut scope WindowOrWorkerGlobalScopeMixin) byte_length_queuing_strategy_size_callback() !&webidl.CallbackType {
	mut functions := scope.strategy_functions()
	return functions.function(true)
}
