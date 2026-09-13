// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of AudioArray. V slices are always in-bounds views, so their
// current length directly represents the typed-array witness length.
module webaudio

pub fn float32_array_length(array []f32) int {
	return array.len
}

// Sample data crossing to a renderer must own its storage because the exposed
// array can be changed by the caller at any time.
pub fn copy_float32_array(array []f32) []f32 {
	return array.clone()
}

pub fn overwrite_float32_array(mut array []f32, values []f32) {
	assert values.len <= array.len
	for index, value in values {
		array[index] = value
	}
}
