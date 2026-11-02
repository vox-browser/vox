// Copyright (c) 2021-2022, Linus Groh <linusg@serenityos.org>
// Copyright (c) 2023-2024, stelar7 <dudedbz@gmail.com>
// Copyright (c) 2024, Jelle Raaijmakers <jelle@ladybird.org>
// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs


// Bindings::create_algorithm_dictionary in SubtleCrypto.cpp. The ordinary
// realm Object prototype is observable when later parameter conversion reads
// properties absent from this source-created dictionary.
fn (host &CryptoHost) algorithm_dictionary(value voidptr, is_object bool) !voidptr {
	if is_object { return value }
	mut runtime := unsafe { &Runtime(host.runtime) }
	dictionary := C.JSObjectMake(runtime.context, unsafe { nil }, unsafe { nil })
	runtime.retain_javascript_value(dictionary)!
	defer { runtime.release_javascript_value(dictionary) }
	runtime.call_javascript_function(host.define_data, C.vox_jsc_JSValueMakeUndefined(runtime.context), [
		dictionary,
		runtime.binding_string('name'),
		value,
	])!
	return dictionary
}
