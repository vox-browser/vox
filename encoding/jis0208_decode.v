// Copyright Mozilla Foundation. See the COPYRIGHT
// file at the top-level directory of this distribution.
//
// Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
// https://www.apache.org/licenses/LICENSE-2.0> or the MIT license
// <LICENSE-MIT or https://opensource.org/licenses/MIT>, at your
// option. This file may not be copied, modified, or distributed
// except according to those terms.

// The above license applies to code in this file. The data in this
// file is generated from WHATWG's indexes.json, which came under
// the following license:

// Copyright © WHATWG (Apple, Google, Mozilla, Microsoft).
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
//    contributors may be used to endorse or promote products derived from
//    this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// Source encoding_rs data.rs ordered JIS0208 symbol/range decode helpers.
module encoding

fn source_jis0208_symbol_decode(pointer u64) ?u16 {
	mut index := 0
	for index < source_jis0208_symbol_triples.len {
		start := u64(source_jis0208_symbol_triples[index])
		length := u64(source_jis0208_symbol_triples[index + 1])
		// Source wrapping_sub then <length is equivalent to this closed range
		// for these small actual ranges on the pinned unsigned 64-bit ABI.
		if pointer >= start && pointer - start < length {
			offset := u64(source_jis0208_symbol_triples[index + 2])
			return source_jis0208_symbols[int(pointer - start + offset)]
		}
		index += 3
	}
	return none
}

fn source_jis0208_range_decode(pointer u64) ?u16 {
	mut index := 0
	for index < source_jis0208_range_triples.len {
		start := u64(source_jis0208_range_triples[index])
		length := u64(source_jis0208_range_triples[index + 1])
		if pointer >= start && pointer - start < length {
			offset := u64(source_jis0208_range_triples[index + 2])
			return u16(pointer - start + offset)
		}
		index += 3
	}
	return none
}
