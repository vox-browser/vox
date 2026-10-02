module html

import dom
import webidl

@[heap]
struct StrategyBuiltinCalls {
mut:
	created []bool
}

fn strategy_test_creator(mut calls StrategyBuiltinCalls) QueuingStrategyNativeFunctionCreator {
	return fn [mut calls] (byte_length bool) !&webidl.CallbackType {
		calls.created << byte_length
		return &webidl.CallbackType{
			callback: fn [byte_length] (_ webidl.Value, arguments []webidl.Value) !webidl.Value {
				if !byte_length { return webidl.number_value(1) }
				assert arguments.len == 1
				return arguments[0]
			}
		}
	}
}

fn test_source_owner_global_retains_distinct_cached_size_callback_records() {
	mut calls := &StrategyBuiltinCalls{}
	mut scope := WindowOrWorkerGlobalScopeMixin.create(dom.origin_create_opaque(), false, false)
	scope.install_queuing_strategy_function_creator(strategy_test_creator(mut calls))!
	assert calls.created.len == 0
	first := scope.count_queuing_strategy_size_callback()!
	second := scope.byte_length_queuing_strategy_size_callback()!
	assert calls.created == [false, true]
	assert voidptr(first) == voidptr(scope.count_queuing_strategy_size_callback()!)
	assert voidptr(second) == voidptr(scope.byte_length_queuing_strategy_size_callback()!)
	assert voidptr(first) != voidptr(second)
	assert webidl.invoke_callback(*first, none, [])!.number_value == 1
	if _ := scope.install_queuing_strategy_function_creator(strategy_test_creator(mut calls)) { assert false }
}

fn test_universal_source_scope_uses_same_lazy_callback_contract_and_separate_global_identity() {
	mut calls := &StrategyBuiltinCalls{}
	realm := &ScriptingRealm{}
	mut one := UniversalGlobalScopeMixin.create(&dom.EventTarget{}, realm, none)
	mut two := UniversalGlobalScopeMixin.create(&dom.EventTarget{}, realm, none)
	one.install_queuing_strategy_function_creator(strategy_test_creator(mut calls))!
	two.install_queuing_strategy_function_creator(strategy_test_creator(mut calls))!
	first := one.byte_length_queuing_strategy_size_callback()!
	second := two.byte_length_queuing_strategy_size_callback()!
	assert calls.created == [true, true]
	assert voidptr(first) != voidptr(second)
	actual := webidl.object_value_with_id({'byteLength': webidl.number_value(7)}, 411)
	result := webidl.invoke_callback(*first, none, [actual])!
	assert result.opaque_id == actual.opaque_id
}
