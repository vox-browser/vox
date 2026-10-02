// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module browserjs

// Embedding projection of actual engine values into the translated source
// HTML serialization records. Create before author scripts so intrinsics are
// captured once; the owning Runtime roots them until close.
@[heap]
pub struct StructuredCloneBridge {
	runtime &Runtime
	intrinsic_ voidptr
}
