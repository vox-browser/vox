module libjs

// Translated from LibJS/Runtime/Completion.h. Throw completions travel through
// V's error channel as a ThrowCompletion carrying the thrown JavaScript value, so
// `!Value` mirrors upstream ThrowCompletionOr<Value>.

// 6.2.3 The Completion Record Specification Type, https://tc39.es/ecma262/#sec-completion-record-specification-type
pub enum CompletionType {
	empty
	normal
	break_
	continue_
	return_
	throw_
}

pub struct Completion {
pub mut:
	type_ CompletionType = .normal
	value Value
}

pub fn normal_completion(value Value) Completion {
	return Completion{
		type_: .normal
		value: value
	}
}

// "abrupt completion refers to any completion with a [[Type]] value other than normal"
pub fn (completion Completion) is_abrupt() bool {
	return completion.type_ != .normal
}

pub fn (completion Completion) is_error() bool {
	return completion.type_ == .throw_
}

pub fn (completion Completion) release_error() IError {
	if completion.type_ != .throw_ {
		panic('release_error() called on a ${completion.type_} completion')
	}
	return throw_completion(completion.value)
}

pub struct ThrowCompletion {
	Error
pub:
	value Value
}

pub fn (completion ThrowCompletion) msg() string {
	return 'Uncaught exception: ${completion.value.str()}'
}

// 5.2.3.2 Throw an Exception, https://tc39.es/ecma262/#sec-throw-an-exception
pub fn throw_completion(value Value) IError {
	return ThrowCompletion{
		value: value
	}
}

pub fn is_throw_completion(err IError) bool {
	return err is ThrowCompletion
}

// thrown_value extracts the JavaScript value carried by a throw completion.
pub fn thrown_value(err IError) Value {
	if err is ThrowCompletion {
		return err.value
	}
	panic('expected a throw completion, got: ${err.msg()}')
}

pub fn completion_from_error(err IError) Completion {
	return Completion{
		type_: .throw_
		value: thrown_value(err)
	}
}
