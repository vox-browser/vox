// Copyright (c) 2024, Tim Flynn <trflynn89@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/FileFilter.cpp.
module html

pub enum FileFilterFileType {
	audio
	image
	video
}

pub struct FileFilterMimeType {
pub:
	value string
}

pub struct FileFilterExtension {
pub:
	value string
}

pub type FileFilterType = FileFilterExtension | FileFilterFileType | FileFilterMimeType

pub struct FileFilter {
pub mut:
	filters []FileFilterType
}

fn file_filters_equal(a FileFilterType, b FileFilterType) bool {
	match a {
		FileFilterFileType {
			if b is FileFilterFileType {
				return a == (b as FileFilterFileType)
			}
			return false
		}
		FileFilterMimeType {
			if b is FileFilterMimeType {
				return a == (b as FileFilterMimeType)
			}
			return false
		}
		FileFilterExtension {
			if b is FileFilterExtension {
				return a == (b as FileFilterExtension)
			}
			return false
		}
	}
}

pub fn (mut file_filter FileFilter) add_filter(filter FileFilterType) {
	for existing in file_filter.filters {
		if file_filters_equal(existing, filter) {
			return
		}
	}
	file_filter.filters << filter
}
