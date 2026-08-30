// Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/MediaError.cpp.
module html

pub enum MediaErrorCode as u16 {
	aborted           = 1
	network           = 2
	decode            = 3
	src_not_supported = 4
}

pub struct MediaError {
pub:
	code    MediaErrorCode
	message string
}

pub fn (media_error &MediaError) code() MediaErrorCode {
	return media_error.code
}

pub fn (media_error &MediaError) message() string {
	return media_error.message
}
