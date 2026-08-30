// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebAssembly/WebAssembly.{h,cpp}. Native LibWasm execution is
// the explicit platform boundary; compilation/instantiation settlement is
// deterministic in the V port while validation and descriptor semantics run.
module webassembly

import webidl

pub struct WebAssemblyInstantiatedSource {
pub:
	module   &Module
	instance &Instance
}

pub fn validate(source webidl.BufferSource) bool {
	compile_module(webidl.get_buffer_source_copy(source)) or { return false }
	return true
}

pub fn compile(source webidl.BufferSource) !&Module {
	return compile_a_webassembly_module(webidl.get_buffer_source_copy(source))
}

pub fn instantiate(source webidl.BufferSource, imports ImportObject) !WebAssemblyInstantiatedSource {
	compiled := compile(source)!
	instance := Instance.construct(compiled, imports)!
	return WebAssemblyInstantiatedSource{
		module:   compiled
		instance: instance
	}
}

pub fn instantiate_module(compiled &Module, imports ImportObject) !&Instance {
	return Instance.construct(compiled, imports)
}

pub struct StreamingResponse {
pub:
	content_type string
	body         []u8
	ok           bool = true
}

pub fn compile_streaming(response StreamingResponse) !&Module {
	if !response.ok {
		return error('TypeError: WebAssembly response is not ok')
	}
	if response.content_type.to_lower().split(';')[0].trim_space() != 'application/wasm' {
		return error('TypeError: WebAssembly response has an unsupported MIME type')
	}
	return compile_a_webassembly_module(response.body)
}

pub fn instantiate_streaming(response StreamingResponse, imports ImportObject) !WebAssemblyInstantiatedSource {
	compiled := compile_streaming(response)!
	instance := Instance.construct(compiled, imports)!
	return WebAssemblyInstantiatedSource{
		module:   compiled
		instance: instance
	}
}
