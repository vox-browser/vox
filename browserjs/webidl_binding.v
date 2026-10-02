// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import webidl

// The generated binding supplies the source IDL argument/result conversion;
// the host owns actual engine calls, Promise Resolve and native capabilities.
pub type JavaScriptWebIDLValueConverter = fn (webidl.Value) !voidptr

@[heap]
struct WebIDLJavaScriptPromiseBridge {
	runtime &Runtime
	native &webidl.Promise
	capability JavaScriptPromiseCapability
mut:
	settled bool
}
