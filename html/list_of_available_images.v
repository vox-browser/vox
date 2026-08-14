// Copyright (c) 2023, Andreas Kling <andreas@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ListOfAvailableImages.cpp. DecodedImageData remains an opaque
// handle until the graphics-backed decoded-image classes are translated.
module html

import dom

pub struct AvailableImageKey {
pub:
	url    string
	mode   CORSSettingAttribute
	origin ?dom.Origin
}

pub fn (key &AvailableImageKey) equals(other &AvailableImageKey) bool {
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

@[heap]
pub struct AvailableImageEntry {
pub:
	image_data                  voidptr
	ignore_higher_layer_caching bool
}

struct StoredAvailableImage {
	key   AvailableImageKey
	entry &AvailableImageEntry
}

pub struct ListOfAvailableImages {
mut:
	images []StoredAvailableImage
}

pub fn (mut images ListOfAvailableImages) add(key AvailableImageKey, image_data voidptr, ignore_higher_layer_caching bool) {
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

pub fn (mut images ListOfAvailableImages) remove(key AvailableImageKey) {
	for index, stored in images.images {
		if stored.key.equals(&key) {
			images.images.delete(index)
			return
		}
	}
}

pub fn (images &ListOfAvailableImages) get(key AvailableImageKey) ?&AvailableImageEntry {
	for stored in images.images {
		if stored.key.equals(&key) {
			return stored.entry
		}
	}
	return none
}
