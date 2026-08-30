// Copyright (c) 2023, Andreas Kling <andreas@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ListOfAvailableImages.cpp.
module html

import dom

pub struct Key {
pub:
	url    string
	mode   CORSSettingAttribute
	origin ?dom.Origin
}

pub fn (key &Key) equals(other &Key) bool {
	if key.url != other.url || key.mode != other.mode {
		return false
	}
	if origin := key.origin {
		if other_origin := other.origin {
			return origin == other_origin
		}
		return false
	}
	if _ := other.origin {
		return false
	}
	return true
}

pub fn (key &Key) hash() u32 {
	// FNV-1a over the same three value components used by equality. The native
	// implementation memoizes this value; caching is not observable.
	mut value := u32(2_166_136_261)
	for byte in key.url.bytes() {
		value = (value ^ u32(byte)) * u32(16_777_619)
	}
	value = (value ^ u32(key.mode)) * u32(16_777_619)
	if origin := key.origin {
		for byte in origin.serialize().bytes() {
			value = (value ^ u32(byte)) * u32(16_777_619)
		}
	}
	return value
}

@[heap]
pub struct AvailableImageEntry {
pub:
	image_data                  DecodedImageData
	ignore_higher_layer_caching bool
}

struct StoredAvailableImage {
	key   Key
	entry &AvailableImageEntry
}

pub struct ListOfAvailableImages {
mut:
	images []StoredAvailableImage
}

pub fn (mut images ListOfAvailableImages) add(key Key, image_data DecodedImageData, ignore_higher_layer_caching bool) {
	entry := &AvailableImageEntry{
		image_data:                  image_data
		ignore_higher_layer_caching: ignore_higher_layer_caching
	}
	for index, stored in images.images {
		if stored.key.equals(&key) {
			images.images[index] = StoredAvailableImage{
				key:   key
				entry: entry
			}
			return
		}
	}
	images.images << StoredAvailableImage{
		key:   key
		entry: entry
	}
}

pub fn (mut images ListOfAvailableImages) remove(key Key) {
	for index, stored in images.images {
		if stored.key.equals(&key) {
			images.images.delete(index)
			return
		}
	}
}

pub fn (images &ListOfAvailableImages) get(key Key) ?&AvailableImageEntry {
	for stored in images.images {
		if stored.key.equals(&key) {
			return stored.entry
		}
	}
	return none
}
