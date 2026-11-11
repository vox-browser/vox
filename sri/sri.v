// Copyright (c) 2022, Kenneth Myhra <kennethmyhra@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/SRI/SRI.cpp — the WHATWG/W3C Subresource Integrity
// algorithms: parse integrity metadata, pick the strongest hash, and verify bytes against a
// metadata list. LibCrypto's SHA-2 and AK's base64 map to V's crypto.sha256/sha512 and
// encoding.base64. ErrorOr<T> becomes `!T`.
// https://w3c.github.io/webappsec-subresource-integrity/
module sri

import crypto.sha256
import crypto.sha512
import encoding.base64

// https://w3c.github.io/webappsec-subresource-integrity/#integrity-metadata
pub struct Metadata {
pub:
	algorithm    string // "alg"
	base64_value string // "val"
	options      string // "opt"
}

// Sorted by strength, low to high. MD5 and SHA-1 are specifically refused.
// https://w3c.github.io/webappsec-subresource-integrity/#hash-functions
const supported_hash_functions = ['sha256', 'sha384', 'sha512']

fn ascii_lowercase(input string) string {
	mut bytes := input.bytes()
	for index, byte in bytes {
		if byte >= `A` && byte <= `Z` { bytes[index] = byte + 0x20 }
	}
	return bytes.bytestr()
}

pub fn is_supported_hash_function(algorithm string) bool {
	normalized := ascii_lowercase(algorithm)
	for supported_hash_function in supported_hash_functions {
		if normalized == supported_hash_function {
			return true
		}
	}
	return false
}

// https://w3c.github.io/webappsec-subresource-integrity/#getprioritizedhashfunction
fn get_prioritized_hash_function(a string, b string) string {
	if a == b {
		return ''
	}
	a_priority := supported_hash_functions.index(a)
	b_priority := supported_hash_functions.index(b)
	if a_priority > b_priority {
		return a
	}
	return b
}

// https://w3c.github.io/webappsec-subresource-integrity/#apply-algorithm-to-response
pub fn apply_algorithm_to_bytes(algorithm string, bytes []u8) !string {
	// 1. Let result be the result of applying algorithm to bytes.
	// 2. Return the result of base64 encoding result.
	if algorithm == 'sha256' {
		return base64.encode(sha256.sum(bytes))
	}
	if algorithm == 'sha384' {
		return base64.encode(sha512.sum384(bytes))
	}
	if algorithm == 'sha512' {
		return base64.encode(sha512.sum512(bytes))
	}
	return error('Unsupported hash algorithm: ${algorithm}')
}

// https://w3c.github.io/webappsec-subresource-integrity/#parse-metadata
pub fn parse_metadata(metadata string) []Metadata {
	// 1. Let result be the empty set.
	mut result := []Metadata{}
	// 2. For each item returned by splitting metadata on spaces:
	//    (Splitting on spaces does not keep empty items; such items are also filtered by step 7.)
	for item in metadata.split(' ') {
		// Options follow '?'. Split the expression only at its first '-',
		// because a base64url digest can contain further hyphens.
		expression := item.all_before('?')
		separator := expression.index('-') or { continue }
		algorithm := ascii_lowercase(expression[..separator])
		if !is_supported_hash_function(algorithm) {
			continue
		}
		base64_value := expression[separator + 1..]
		// CSP's base64-value grammar requires at least one alphabet byte and
		// permits at most two trailing padding characters.
		mut data_end := base64_value.len
		for _ in 0 .. 2 {
			if data_end == 0 || base64_value[data_end - 1] != `=` { break }
			data_end--
		}
		if data_end == 0 { continue }
		mut valid := true
		for byte in base64_value[..data_end].bytes() {
			if !(byte >= `A` && byte <= `Z`) && !(byte >= `a` && byte <= `z`)
				&& !(byte >= `0` && byte <= `9`) && byte !in [`+`, `/`, `-`, `_`] {
				valid = false
				break
			}
		}
		if !valid { continue }
		// 8-9. Append «["alg" → algorithm, "val" → base64-value]» to result.
		result << Metadata{
			algorithm: algorithm
			base64_value: base64_value
			options: ''
		}
	}
	// 3. Return result.
	return result
}

// https://w3c.github.io/webappsec-subresource-integrity/#get-the-strongest-metadata
pub fn get_strongest_metadata_from_set(set []Metadata) []Metadata {
	// 1. Let result be the empty set and strongest be the empty string.
	mut result := []Metadata{}
	mut strongest := Metadata{}
	// 2. For each item in set:
	for item in set {
		// 1. If result is empty, add item to result and set strongest to item; skip to next.
		if result.len == 0 {
			result << item
			strongest = item
			continue
		}
		// 2. Let currentAlgorithm be strongest's alg.
		current_algorithm := strongest.algorithm
		// 3. Let newAlgorithm be item's alg.
		new_algorithm := item.algorithm
		// 4. Compare via getPrioritizedHashFunction.
		prioritized_hash_function := get_prioritized_hash_function(current_algorithm, new_algorithm)
		if prioritized_hash_function == '' {
			// Empty string (equal strength): add item to result.
			result << item
		} else if prioritized_hash_function == new_algorithm {
			// newAlgorithm is stronger: reset result to just item.
			strongest = item
			result.clear()
			result << item
		}
	}
	// 3. Return result.
	return result
}

// Compare standard and URL-safe base64 with or without trailing padding.
fn normalize_base64_value(value string) string {
	return value.trim_right('=').replace('-', '+').replace('_', '/')
}

// https://w3c.github.io/webappsec-subresource-integrity/#does-response-match-metadatalist
pub fn do_bytes_match_metadata_list(bytes []u8, metadata_list string) !bool {
	// 1. Let parsedMetadata be the result of parsing metadataList.
	parsed_metadata := parse_metadata(metadata_list)
	// 2. If parsedMetadata is empty, return true.
	if parsed_metadata.len == 0 {
		return true
	}
	// 3. Let metadata be the strongest metadata from parsedMetadata.
	metadata := get_strongest_metadata_from_set(parsed_metadata)
	// 4. For each item in metadata:
	for item in metadata {
		// 1-3. actualValue = applying item's alg to bytes.
		actual_value := apply_algorithm_to_bytes(item.algorithm, bytes)!
		// 4. If actualValue is a case-sensitive match for expectedValue, return true.
		if normalize_base64_value(actual_value) == normalize_base64_value(item.base64_value) {
			return true
		}
	}
	// 5. Return false.
	return false
}
