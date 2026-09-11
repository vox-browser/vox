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

pub fn is_supported_hash_function(algorithm string) bool {
	for supported_hash_function in supported_hash_functions {
		if algorithm == supported_hash_function {
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
		// 1. Let hash-with-opt-token-list be item split on U+003F (?).
		hash_with_opt_token_list := item.split('?')
		// 2. Let hash-expression be hash-with-opt-token-list[0].
		hash_expression := hash_with_opt_token_list[0]
		// 3. Let base64-value be the empty string.
		mut base64_value := ''
		// 4. Let hash-expr-token-list be hash-expression split on U+002D (-).
		hash_expr_token_list := hash_expression.split('-')
		// 5. Let algorithm be hash-expr-token-list[0].
		algorithm := hash_expr_token_list[0]
		// 6. If hash-expr-token-list[1] exists, set base64-value to it.
		if hash_expr_token_list.len > 1 {
			base64_value = hash_expr_token_list[1]
		}
		// 7. If algorithm is not a recognized hash function, continue.
		if !is_supported_hash_function(algorithm) {
			continue
		}
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
		if actual_value == item.base64_value {
			return true
		}
	}
	// 5. Return false.
	return false
}
