// Copyright (c) 2023, Andreas Kling <andreas@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ListOfAvailableImages.cpp.
@[has_globals]
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
pub mut:
	cache_touch_serial u64
}

struct StoredAvailableImage {
	key   Key
	entry &AvailableImageEntry
}

pub struct ListOfAvailableImages {
mut:
	images []StoredAvailableImage
}

__global html_available_image_cache_touch_serial u64

fn next_available_image_cache_touch_serial() u64 {
	html_available_image_cache_touch_serial++
	return html_available_image_cache_touch_serial
}

pub fn (mut images ListOfAvailableImages) add(key Key, image_data DecodedImageData, ignore_higher_layer_caching bool) {
	entry := &AvailableImageEntry{
		image_data:                  image_data
		ignore_higher_layer_caching: ignore_higher_layer_caching
		cache_touch_serial:          next_available_image_cache_touch_serial()
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

pub fn (mut images ListOfAvailableImages) get(key Key) ?&AvailableImageEntry {
	for stored in images.images {
		if stored.key.equals(&key) {
			mut entry := stored.entry
			entry.cache_touch_serial = next_available_image_cache_touch_serial()
			return stored.entry
		}
	}
	return none
}

fn (images &ListOfAvailableImages) prunable_size_and_count() (uint, uint) {
	mut size := uint(0)
	mut count := uint(0)
	for stored in images.images {
		if stored.entry.image_data.has_clients() {
			continue
		}
		image_size := stored.entry.image_data.external_memory_size()
		if uint(-1) - size < image_size {
			size = uint(-1)
		} else {
			size += image_size
		}
		count++
	}
	return size, count
}

pub fn (mut images ListOfAvailableImages) prune_to_limits(external_memory_limit uint, count_limit uint) {
	mut size, mut count := images.prunable_size_and_count()
	for size > external_memory_limit || count > count_limit {
		mut least_recently_used_index := -1
		mut least_recently_used_serial := u64(-1)
		for index, stored in images.images {
			if stored.entry.image_data.has_clients()
				|| stored.entry.cache_touch_serial >= least_recently_used_serial {
				continue
			}
			least_recently_used_index = index
			least_recently_used_serial = stored.entry.cache_touch_serial
		}
		if least_recently_used_index < 0 {
			break
		}
		images.images.delete(least_recently_used_index)
		new_size, new_count := images.prunable_size_and_count()
		if new_size == size && new_count == count {
			break
		}
		size = new_size
		count = new_count
	}
}
