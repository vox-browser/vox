// Copyright (c) 2023, Andreas Kling <andreas@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the source-selection algorithms in Libraries/LibWeb/HTML/SourceSet.cpp.
module html

import strconv

pub struct PixelDensityDescriptorValue {
pub:
	value f64
}

pub struct WidthDescriptorValue {
pub:
	value f64
}

pub struct EmptyImageSourceDescriptor {}

pub type ImageSourceDescriptor = EmptyImageSourceDescriptor
	| PixelDensityDescriptorValue
	| WidthDescriptorValue

pub struct ImageSource {
pub mut:
	url        string
	descriptor ImageSourceDescriptor = EmptyImageSourceDescriptor{}
}

pub struct ImageSourceAndPixelDensity {
pub:
	source        ImageSource
	pixel_density f64 = 1.0
}

pub struct SourceSet {
pub mut:
	sources     []ImageSource
	source_size f64
}

pub fn (source_set &SourceSet) is_empty() bool {
	return source_set.sources.len == 0
}

fn image_source_pixel_density(source ImageSource) f64 {
	if source.descriptor is PixelDensityDescriptorValue {
		descriptor := source.descriptor as PixelDensityDescriptorValue
		return descriptor.value
	}
	panic('image source does not have a pixel density descriptor')
}

// https://html.spec.whatwg.org/multipage/images.html#select-an-image-source-from-a-source-set
pub fn (source_set &SourceSet) select_an_image_source() ImageSourceAndPixelDensity {
	mut unique_sources := []ImageSource{}
	for source in source_set.sources {
		density := image_source_pixel_density(source)
		mut already_present := false
		for existing in unique_sources {
			if image_source_pixel_density(existing) == density {
				already_present = true
				break
			}
		}
		if !already_present {
			unique_sources << source
		}
	}
	unique_sources.sort_with_compare(fn (a &ImageSource, b &ImageSource) int {
		a_density := image_source_pixel_density(*a)
		b_density := image_source_pixel_density(*b)
		return if a_density < b_density {
			-1
		} else if a_density > b_density {
			1
		} else {
			0
		}
	})
	for source in unique_sources {
		density := image_source_pixel_density(source)
		if density >= 1.0 {
			return ImageSourceAndPixelDensity{source, density}
		}
	}
	last_source := unique_sources.last()
	return ImageSourceAndPixelDensity{last_source, image_source_pixel_density(last_source)}
}

enum SourceSetTokenizerState {
	in_descriptor
	in_parens
	after_descriptor
}

fn collect_srcset_characters(input string, initial_position int, condition fn (u8) bool) (string, int) {
	mut position := initial_position
	for position < input.len && condition(input[position]) {
		position++
	}
	return input[initial_position..position], position
}

fn srcset_space_or_comma(character u8) bool {
	return is_number_ascii_whitespace(character) || character == `,`
}

fn srcset_not_whitespace(character u8) bool {
	return !is_number_ascii_whitespace(character)
}

fn srcset_whitespace(character u8) bool {
	return is_number_ascii_whitespace(character)
}

fn parse_srcset_descriptor(descriptor string) (bool, ?i32, ?f64, ?i32) {
	if descriptor.len == 0 {
		return true, none, none, none
	}
	last_character := descriptor[descriptor.len - 1]
	number := descriptor[..descriptor.len - 1]
	if last_character == `w` {
		value := strconv.parse_int(number, 10, 32) or { return false, none, none, none }
		return true, i32(value), none, none
	}
	if last_character == `x` {
		value := strconv.atof64(number) or { return false, none, none, none }
		return true, none, value, none
	}
	if last_character == `h` {
		value := strconv.parse_int(number, 10, 32) or { return false, none, none, none }
		return true, none, none, i32(value)
	}
	return false, none, none, none
}

// https://html.spec.whatwg.org/multipage/images.html#parse-a-srcset-attribute
pub fn parse_a_srcset_attribute(input string) SourceSet {
	mut position := 0
	mut candidates := SourceSet{}
	for {
		_, position = collect_srcset_characters(input, position, srcset_space_or_comma)
		if position >= input.len {
			return candidates
		}

		mut url := ''
		url, position = collect_srcset_characters(input, position, srcset_not_whitespace)
		mut descriptors := []string{}
		if url.ends_with(',') {
			for url.ends_with(',') {
				url = url[..url.len - 1]
			}
		} else {
			_, position = collect_srcset_characters(input, position, srcset_whitespace)
			mut current_descriptor := []u8{}
			mut state := SourceSetTokenizerState.in_descriptor
			mut descriptors_complete := false
			for !descriptors_complete {
				has_character := position < input.len
				character := if has_character { input[position] } else { u8(0) }
				match state {
					.in_descriptor {
						if has_character && is_number_ascii_whitespace(character) {
							if current_descriptor.len > 0 {
								descriptors << current_descriptor.bytestr()
								current_descriptor = []u8{}
							}
							state = .after_descriptor
						} else if has_character && character == `,` {
							position++
							if current_descriptor.len > 0 {
								descriptors << current_descriptor.bytestr()
							}
							descriptors_complete = true
							continue
						} else if has_character && character == `(` {
							current_descriptor << character
							state = .in_parens
						} else if !has_character {
							if current_descriptor.len > 0 {
								descriptors << current_descriptor.bytestr()
							}
							descriptors_complete = true
							continue
						} else {
							current_descriptor << character
						}
					}
					.in_parens {
						if has_character && character == `)` {
							current_descriptor << character
							state = .in_descriptor
						} else if !has_character {
							descriptors << current_descriptor.bytestr()
							descriptors_complete = true
							continue
						} else {
							current_descriptor << character
						}
					}
					.after_descriptor {
						if has_character && is_number_ascii_whitespace(character) {
						} else if !has_character {
							descriptors_complete = true
							continue
						} else {
							state = .in_descriptor
							position--
						}
					}
				}
				position++
			}
		}

		mut error := false
		mut width := ?i32(none)
		mut density := ?f64(none)
		mut future_compat_h := ?i32(none)
		for descriptor in descriptors {
			valid, parsed_width, parsed_density, parsed_h := parse_srcset_descriptor(descriptor)
			if !valid {
				error = true
				continue
			}
			if value := parsed_width {
				if width != none || density != none {
					error = true
				}
				width = value
			} else if value := parsed_density {
				if width != none || density != none || future_compat_h != none {
					error = true
				}
				density = value
			} else if value := parsed_h {
				if future_compat_h != none || density != none {
					error = true
				}
				future_compat_h = value
			}
		}
		if future_compat_h != none && width == none {
			error = true
		}
		if !error {
			mut source := ImageSource{
				url: url
			}
			if value := width {
				source.descriptor = WidthDescriptorValue{f64(value)}
			} else if value := density {
				source.descriptor = PixelDensityDescriptorValue{value}
			}
			candidates.sources << source
		}
	}
	return candidates
}

// https://html.spec.whatwg.org/multipage/images.html#normalise-the-source-densities
pub fn (mut source_set SourceSet) normalize_source_densities(source_size f64) {
	for mut source in source_set.sources {
		if source.descriptor is PixelDensityDescriptorValue {
			continue
		}
		mut descriptor_value_set := false
		mut normalized_width := ?f64(none)
		if source.descriptor is WidthDescriptorValue {
			descriptor := source.descriptor as WidthDescriptorValue
			if source_size != 0.0 {
				normalized_width = descriptor.value / source_size
			}
		}
		if value := normalized_width {
			source.descriptor = PixelDensityDescriptorValue{value}
			descriptor_value_set = true
		}
		if !descriptor_value_set {
			source.descriptor = PixelDensityDescriptorValue{1.0}
		}
	}
}

// https://html.spec.whatwg.org/multipage/images.html#create-a-source-set
pub fn create_source_set(default_source string, srcset string, source_size f64) SourceSet {
	mut source_set := if srcset == '' { SourceSet{} } else { parse_a_srcset_attribute(srcset) }
	source_set.source_size = source_size
	if default_source != '' {
		mut contains_one_x := false
		mut contains_width := false
		for source in source_set.sources {
			if source.descriptor is PixelDensityDescriptorValue {
				descriptor := source.descriptor as PixelDensityDescriptorValue
				if descriptor.value == 1.0 {
					contains_one_x = true
				}
			}
			if source.descriptor is WidthDescriptorValue {
				contains_width = true
			}
		}
		if !contains_one_x && !contains_width {
			source_set.sources << ImageSource{
				url: default_source
			}
		}
	}
	source_set.normalize_source_densities(source_size)
	return source_set
}
