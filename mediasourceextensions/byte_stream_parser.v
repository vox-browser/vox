// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ByteStreamParser.h. V does not support a mutable interface
// field with the ownership shape used here, so this small tagged adapter keeps
// the format-independent SourceBufferProcessor contract explicit.
module mediasourceextensions

enum ByteStreamParserKind {
	webm
	isobmff
}

@[heap]
struct ByteStreamParser {
	kind ByteStreamParserKind
mut:
	webm_    &WebMByteStreamParser = unsafe { nil }
	isobmff_ &ISOBMFFByteStreamParser = unsafe { nil }
}

fn ByteStreamParser.create_webm() &ByteStreamParser {
	return &ByteStreamParser{
		kind: .webm
		webm_: WebMByteStreamParser.create()
	}
}

fn ByteStreamParser.create_isobmff() &ByteStreamParser {
	return &ByteStreamParser{
		kind: .isobmff
		isobmff_: ISOBMFFByteStreamParser.create()
	}
}

fn (parser &ByteStreamParser) sniff_segment_type(bytes []u8) SegmentType {
	return match parser.kind {
		.webm { parser.webm_.sniff_segment_type(bytes) }
		.isobmff { parser.isobmff_.sniff_segment_type(bytes) }
	}
}

fn (parser &ByteStreamParser) ignored_element_length(bytes []u8) !int {
	return match parser.kind {
		.webm { parser.webm_.ignored_element_length(bytes)! }
		.isobmff { parser.isobmff_.ignored_element_length(bytes)! }
	}
}

fn (mut parser ByteStreamParser) parse_initialization_segment(bytes []u8) !WebMInitializationSegmentResult {
	return match parser.kind {
		.webm { parser.webm_.parse_initialization_segment(bytes)! }
		.isobmff { parser.isobmff_.parse_initialization_segment(bytes)! }
	}
}

fn (mut parser ByteStreamParser) parse_media_segment(bytes []u8) !WebMMediaSegmentResult {
	return match parser.kind {
		.webm { parser.webm_.parse_media_segment(bytes)! }
		.isobmff { parser.isobmff_.parse_media_segment(bytes)! }
	}
}

fn (mut parser ByteStreamParser) reset_parser_state() {
	match parser.kind {
		.webm { parser.webm_.reset_parser_state() }
		.isobmff { parser.isobmff_.reset_parser_state() }
	}
}
