// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// Originally written for jxl-oxide.
module jpegxl

import math

const ans_sum_probs = 4096

struct AnsBucket {
	distance           u16
	alias_symbol       u8
	alias_cutoff       u8
	alias_offset       u16
	alias_distance_xor u16
}

struct AnsWorkingBucket {
	distance int
mut:
	alias_symbol int
	alias_offset int
	alias_cutoff int
}

struct AnsRepeatRange {
	start int
	end   int
}

struct AnsHistogram {
	buckets         []AnsBucket
	log_bucket_size int
	bucket_mask     u32
	single_symbol   ?u32
	alphabet_size   int
}

fn (mut reader BitReader) read_ans_u8() !int {
	if reader.read(1)! == 0 { return 0 }
	bits := int(reader.read(3)!)
	return (1 << bits) + int(reader.read(bits)!)
}

fn (mut reader BitReader) read_ans_distribution(mut distances []int) !int {
	if reader.read(1)! != 0 {
		if reader.read(1)! != 0 {
			first := reader.read_ans_u8()!
			second := reader.read_ans_u8()!
			if first == second || math.max(first, second) >= distances.len {
				return error('Invalid JPEG XL two-symbol ANS histogram')
			}
			probability := int(reader.read(12)!)
			distances[first] = probability
			distances[second] = ans_sum_probs - probability
			return math.max(first, second) + 1
		}
		symbol := reader.read_ans_u8()!
		if symbol >= distances.len { return error('Invalid JPEG XL single-symbol ANS histogram') }
		distances[symbol] = ans_sum_probs
		return symbol + 1
	}
	if reader.read(1)! != 0 {
		size := reader.read_ans_u8()! + 1
		if size > distances.len { return error('Invalid JPEG XL uniform ANS histogram') }
		for i in 0 .. size {
			distances[i] = ans_sum_probs / size + if i < ans_sum_probs % size { 1 } else { 0 }
		}
		return size
	}
	return reader.read_complex_ans_distribution(mut distances)
}

fn (mut reader BitReader) read_complex_ans_distribution(mut distances []int) !int {
	mut bits := 0
	for bits < 3 {
		if reader.read(1)! == 0 { break }
		bits++
	}
	shift := int(reader.read(bits)!) + (1 << bits) - 1
	if shift > 13 { return error('Invalid JPEG XL ANS precision shift') }
	size := reader.read_ans_u8()! + 3
	if size > distances.len { return error('Invalid JPEG XL ANS alphabet') }
	mut repeats := []AnsRepeatRange{}
	mut omit_position := -1
	mut omit_log := -1
	mut index := 0
	for index < size {
		value := reader.read_ans_prefix()!
		distances[index] = value
		if value == 13 {
			count := reader.read_ans_u8()! + 4
			if count > size - index { return error('Invalid JPEG XL ANS repetition') }
			repeats << AnsRepeatRange{ start: index, end: index + count }
			index += count
			continue
		}
		if value > omit_log {
			omit_log = value
			omit_position = index
		}
		index++
	}
	if omit_position < 0 || (omit_position + 1 < distances.len && distances[omit_position + 1] == 13) {
		return error('Invalid JPEG XL omitted ANS probability')
	}
	mut repeat_index := 0
	mut sum := 0
	mut previous := 0
	for i in 0 .. distances.len {
		if repeat_index < repeats.len && repeats[repeat_index].start <= i {
			if repeats[repeat_index].end == i {
				repeat_index++
			} else {
				distances[i] = previous
				sum += previous
				if sum >= ans_sum_probs { return error('Invalid JPEG XL ANS probability sum') }
				continue
			}
		}
		if distances[i] == 0 || i == omit_position {
			previous = 0
			continue
		}
		if distances[i] > 1 {
			zeros := distances[i] - 1
			count := math.max(0, math.min(zeros, shift - ((12 - zeros) >> 1)))
			distances[i] = (1 << zeros) + (int(reader.read(count)!) << (zeros - count))
		}
		previous = distances[i]
		sum += previous
		if sum >= ans_sum_probs { return error('Invalid JPEG XL ANS probability sum') }
	}
	distances[omit_position] = ans_sum_probs - sum
	return size
}

fn ans_alias_map(alphabet_size int, log_bucket_size int, distances []int) ![]AnsBucket {
	bucket_size := 1 << log_bucket_size
	mut working := []AnsWorkingBucket{cap: distances.len}
	mut underfull := []int{}
	mut overfull := []int{}
	mut sum := 0
	for i, distance in distances {
		sum += distance
		working << AnsWorkingBucket{
			distance:     distance
			alias_symbol: if i < alphabet_size {
				i
			} else {
				0
			}
			alias_cutoff: distance
		}
		if distance < bucket_size {
			underfull << i
		} else if distance > bucket_size {
			overfull << i
		}
	}
	if sum != ans_sum_probs { return error('Invalid JPEG XL ANS probability sum') }
	for overfull.len > 0 && underfull.len > 0 {
		over := overfull.pop()
		under := underfull.pop()
		amount := bucket_size - working[under].alias_cutoff
		working[over].alias_cutoff -= amount
		working[under].alias_symbol = over
		working[under].alias_offset = working[over].alias_cutoff
		if working[over].alias_cutoff < bucket_size {
			underfull << over
		} else if working[over].alias_cutoff > bucket_size {
			overfull << over
		}
	}
	if overfull.len != 0 || underfull.len != 0 { return error('Invalid JPEG XL ANS alias map') }
	mut buckets := []AnsBucket{cap: working.len}
	for i, bucket in working {
		if bucket.alias_cutoff == bucket_size {
			buckets << AnsBucket{ distance: u16(bucket.distance), alias_symbol: u8(i) }
		} else {
			buckets << AnsBucket{
				distance:           u16(bucket.distance)
				alias_symbol:       u8(bucket.alias_symbol)
				alias_offset:       u16(bucket.alias_offset - bucket.alias_cutoff)
				alias_cutoff:       u8(bucket.alias_cutoff)
				alias_distance_xor: u16(bucket.distance ^ working[bucket.alias_symbol].distance)
			}
		}
	}
	return buckets
}

fn (mut reader BitReader) read_ans_histogram(log_alphabet_size int) !AnsHistogram {
	if log_alphabet_size < 5 || log_alphabet_size > 8 {
		return error('Invalid JPEG XL ANS alphabet size')
	}
	log_bucket_size := 12 - log_alphabet_size
	bucket_size := 1 << log_bucket_size
	mut distances := []int{len: 1 << log_alphabet_size}
	size := reader.read_ans_distribution(mut distances)!
	mut single := ?u32(none)
	for i, distance in distances {
		if distance == ans_sum_probs {
			single = u32(i)
			break
		}
	}
	mut buckets := []AnsBucket{}
	if symbol := single {
		for i, distance in distances {
			buckets << AnsBucket{ distance: u16(distance), alias_symbol: u8(symbol), alias_offset: u16(bucket_size * i), alias_distance_xor: u16(distance ^ ans_sum_probs) }
		}
	} else {
		buckets = ans_alias_map(size, log_bucket_size, distances)!
	}
	return AnsHistogram{ buckets: buckets, log_bucket_size: log_bucket_size, bucket_mask: u32(bucket_size - 1), single_symbol: single, alphabet_size: size }
}
