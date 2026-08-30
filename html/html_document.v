// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLDocument.{h,cpp}.
module html

import dom

// Ladybird's HTMLDocument adds bindings identity to DOM::Document without
// adding document state. The V port represents that inheritance explicitly by
// retaining the underlying DOM document.
@[heap]
pub struct HTMLDocument {
pub:
	document &dom.Document @[required]
}

pub fn HTMLDocument.construct_impl() !&HTMLDocument {
	return HTMLDocument.create(dom.url_about_blank())
}

pub fn HTMLDocument.create(url dom.URL) &HTMLDocument {
	return &HTMLDocument{
		document: dom.Document.create(url)
	}
}

pub fn (document &HTMLDocument) as_document() &dom.Document {
	return document.document
}
