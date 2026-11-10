// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
module jpegxl

import math

// The source SIMD kernels operate independently on every lane. These scalar
// translations keep their operation order and explicit fused rounding.
pub fn inverse_dct_vector(input []f32) ![]f32 {
	for value in input {
		if !math.is_finite(value) { return error('Nonfinite JPEG XL DCT input') }
	}
	return inverse_dct_values(input)
}

// Transform the first `n` values of `vector` in place, with the same kernels
// as inverse_dct_values. Lengths up to 32 use no allocation.
fn inverse_dct_in_place(mut vector []f32, n int) ! {
	if n > vector.len { return error('Invalid JPEG XL DCT vector length') }
	data := unsafe { &f32(vector.data) }
	match n {
		2 { inverse_dct_2_in_place(data) }
		4 { inverse_dct_4_in_place(data) }
		8 { inverse_dct_8_in_place(data) }
		16 { inverse_dct_16_in_place(data) }
		32 { inverse_dct_32_in_place(data) }
		64, 128, 256 {
			values := inverse_dct_large_owned(vector[..n])
			for i in 0 .. n { vector[i] = values[i] }
		}
		else { return error('Unsupported JPEG XL DCT vector length') }
	}
}

fn inverse_dct_values(input []f32) ![]f32 {
	return match input.len {
		2 { inverse_dct_2(input) }
		4 { inverse_dct_4(input) }
		8 { inverse_dct_8(input) }
		16 { inverse_dct_16(input) }
		32 { inverse_dct_32(input) }
		64, 128, 256 { inverse_dct_large_owned(input) }
		else { return error('Unsupported JPEG XL DCT vector length') }
	}
}


fn inverse_dct_2(input []f32) []f32 {
	mut output := []f32{len: 2}
	for i in 0 .. 2 { output[i] = input[i] }
	inverse_dct_2_in_place(unsafe { &f32(output.data) })
	return output
}

// In place over 2 contiguous values; every input is read before any write.
@[direct_array_access]
fn inverse_dct_2_in_place(data &f32) {
	v0 := unsafe { data[0] }
	v1 := unsafe { data[1] }
	v2 := v0 + v1
	v3 := v0 - v1
	unsafe {
		data[0] = v2
		data[1] = v3
	}
}


fn inverse_dct_4(input []f32) []f32 {
	mut output := []f32{len: 4}
	for i in 0 .. 4 { output[i] = input[i] }
	inverse_dct_4_in_place(unsafe { &f32(output.data) })
	return output
}

// In place over 4 contiguous values; every input is read before any write.
@[direct_array_access]
fn inverse_dct_4_in_place(data &f32) {
	v0 := unsafe { data[0] }
	v1 := unsafe { data[1] }
	v2 := unsafe { data[2] }
	v3 := unsafe { data[3] }
	v4 := v0 + v2
	v5 := v0 - v2
	v6 := v1 + v3
	v7 := v1 * f32(1.4142135623730950488)
	v8 := v7 + v6
	v9 := v7 - v6
	mul_0 := f32(0.5411961001461970)
	v10 := fused_f32(v8, mul_0, v4)
	v11 := fused_f32(-v8, mul_0, v4)
	mul_1 := f32(1.3065629648763764)
	v12 := fused_f32(v9, mul_1, v5)
	v13 := fused_f32(-v9, mul_1, v5)
	unsafe {
		data[0] = v10
		data[1] = v12
		data[2] = v13
		data[3] = v11
	}
}


fn inverse_dct_8(input []f32) []f32 {
	mut output := []f32{len: 8}
	for i in 0 .. 8 { output[i] = input[i] }
	inverse_dct_8_in_place(unsafe { &f32(output.data) })
	return output
}

// In place over 8 contiguous values; every input is read before any write.
@[direct_array_access]
fn inverse_dct_8_in_place(data &f32) {
	v0 := unsafe { data[0] }
	v1 := unsafe { data[1] }
	v2 := unsafe { data[2] }
	v3 := unsafe { data[3] }
	v4 := unsafe { data[4] }
	v5 := unsafe { data[5] }
	v6 := unsafe { data[6] }
	v7 := unsafe { data[7] }
	v8 := v0 + v4
	v9 := v0 - v4
	v10 := v2 + v6
	v11 := v2 * f32(1.4142135623730950488)
	v12 := v11 + v10
	v13 := v11 - v10
	mul_0 := f32(0.5411961001461970)
	v14 := fused_f32(v12, mul_0, v8)
	v15 := fused_f32(-v12, mul_0, v8)
	mul_1 := f32(1.3065629648763764)
	v16 := fused_f32(v13, mul_1, v9)
	v17 := fused_f32(-v13, mul_1, v9)
	v18 := v1 + v3
	v19 := v3 + v5
	v20 := v5 + v7
	v21 := v1 * f32(1.4142135623730950488)
	v22 := v21 + v19
	v23 := v21 - v19
	v24 := v18 + v20
	v25 := v18 * f32(1.4142135623730950488)
	v26 := v25 + v24
	v27 := v25 - v24
	mul_2 := f32(0.5411961001461970)
	v28 := fused_f32(v26, mul_2, v22)
	v29 := fused_f32(-v26, mul_2, v22)
	mul_3 := f32(1.3065629648763764)
	v30 := fused_f32(v27, mul_3, v23)
	v31 := fused_f32(-v27, mul_3, v23)
	mul_4 := f32(0.5097955791041592)
	v32 := fused_f32(v28, mul_4, v14)
	v33 := fused_f32(-v28, mul_4, v14)
	mul_5 := f32(0.6013448869350453)
	v34 := fused_f32(v30, mul_5, v16)
	v35 := fused_f32(-v30, mul_5, v16)
	mul_6 := f32(0.8999762231364156)
	v36 := fused_f32(v31, mul_6, v17)
	v37 := fused_f32(-v31, mul_6, v17)
	mul_7 := f32(2.5629154477415055)
	v38 := fused_f32(v29, mul_7, v15)
	v39 := fused_f32(-v29, mul_7, v15)
	unsafe {
		data[0] = v32
		data[1] = v34
		data[2] = v36
		data[3] = v38
		data[4] = v39
		data[5] = v37
		data[6] = v35
		data[7] = v33
	}
}


fn inverse_dct_16(input []f32) []f32 {
	mut output := []f32{len: 16}
	for i in 0 .. 16 { output[i] = input[i] }
	inverse_dct_16_in_place(unsafe { &f32(output.data) })
	return output
}

// In place over 16 contiguous values; every input is read before any write.
@[direct_array_access]
fn inverse_dct_16_in_place(data &f32) {
	v0 := unsafe { data[0] }
	v1 := unsafe { data[1] }
	v2 := unsafe { data[2] }
	v3 := unsafe { data[3] }
	v4 := unsafe { data[4] }
	v5 := unsafe { data[5] }
	v6 := unsafe { data[6] }
	v7 := unsafe { data[7] }
	v8 := unsafe { data[8] }
	v9 := unsafe { data[9] }
	v10 := unsafe { data[10] }
	v11 := unsafe { data[11] }
	v12 := unsafe { data[12] }
	v13 := unsafe { data[13] }
	v14 := unsafe { data[14] }
	v15 := unsafe { data[15] }
	v16 := v0 + v8
	v17 := v0 - v8
	v18 := v4 + v12
	v19 := v4 * f32(1.4142135623730950488)
	v20 := v19 + v18
	v21 := v19 - v18
	mul_0 := f32(0.5411961001461970)
	v22 := fused_f32(v20, mul_0, v16)
	v23 := fused_f32(-v20, mul_0, v16)
	mul_1 := f32(1.3065629648763764)
	v24 := fused_f32(v21, mul_1, v17)
	v25 := fused_f32(-v21, mul_1, v17)
	v26 := v2 + v6
	v27 := v6 + v10
	v28 := v10 + v14
	v29 := v2 * f32(1.4142135623730950488)
	v30 := v29 + v27
	v31 := v29 - v27
	v32 := v26 + v28
	v33 := v26 * f32(1.4142135623730950488)
	v34 := v33 + v32
	v35 := v33 - v32
	mul_2 := f32(0.5411961001461970)
	v36 := fused_f32(v34, mul_2, v30)
	v37 := fused_f32(-v34, mul_2, v30)
	mul_3 := f32(1.3065629648763764)
	v38 := fused_f32(v35, mul_3, v31)
	v39 := fused_f32(-v35, mul_3, v31)
	mul_4 := f32(0.5097955791041592)
	v40 := fused_f32(v36, mul_4, v22)
	v41 := fused_f32(-v36, mul_4, v22)
	mul_5 := f32(0.6013448869350453)
	v42 := fused_f32(v38, mul_5, v24)
	v43 := fused_f32(-v38, mul_5, v24)
	mul_6 := f32(0.8999762231364156)
	v44 := fused_f32(v39, mul_6, v25)
	v45 := fused_f32(-v39, mul_6, v25)
	mul_7 := f32(2.5629154477415055)
	v46 := fused_f32(v37, mul_7, v23)
	v47 := fused_f32(-v37, mul_7, v23)
	v48 := v1 + v3
	v49 := v3 + v5
	v50 := v5 + v7
	v51 := v7 + v9
	v52 := v9 + v11
	v53 := v11 + v13
	v54 := v13 + v15
	v55 := v1 * f32(1.4142135623730950488)
	v56 := v55 + v51
	v57 := v55 - v51
	v58 := v49 + v53
	v59 := v49 * f32(1.4142135623730950488)
	v60 := v59 + v58
	v61 := v59 - v58
	mul_8 := f32(0.5411961001461970)
	v62 := fused_f32(v60, mul_8, v56)
	v63 := fused_f32(-v60, mul_8, v56)
	mul_9 := f32(1.3065629648763764)
	v64 := fused_f32(v61, mul_9, v57)
	v65 := fused_f32(-v61, mul_9, v57)
	v66 := v48 + v50
	v67 := v50 + v52
	v68 := v52 + v54
	v69 := v48 * f32(1.4142135623730950488)
	v70 := v69 + v67
	v71 := v69 - v67
	v72 := v66 + v68
	v73 := v66 * f32(1.4142135623730950488)
	v74 := v73 + v72
	v75 := v73 - v72
	mul_10 := f32(0.5411961001461970)
	v76 := fused_f32(v74, mul_10, v70)
	v77 := fused_f32(-v74, mul_10, v70)
	mul_11 := f32(1.3065629648763764)
	v78 := fused_f32(v75, mul_11, v71)
	v79 := fused_f32(-v75, mul_11, v71)
	mul_12 := f32(0.5097955791041592)
	v80 := fused_f32(v76, mul_12, v62)
	v81 := fused_f32(-v76, mul_12, v62)
	mul_13 := f32(0.6013448869350453)
	v82 := fused_f32(v78, mul_13, v64)
	v83 := fused_f32(-v78, mul_13, v64)
	mul_14 := f32(0.8999762231364156)
	v84 := fused_f32(v79, mul_14, v65)
	v85 := fused_f32(-v79, mul_14, v65)
	mul_15 := f32(2.5629154477415055)
	v86 := fused_f32(v77, mul_15, v63)
	v87 := fused_f32(-v77, mul_15, v63)
	mul_16 := f32(0.5024192861881557)
	v88 := fused_f32(v80, mul_16, v40)
	v89 := fused_f32(-v80, mul_16, v40)
	mul_17 := f32(0.5224986149396889)
	v90 := fused_f32(v82, mul_17, v42)
	v91 := fused_f32(-v82, mul_17, v42)
	mul_18 := f32(0.5669440348163577)
	v92 := fused_f32(v84, mul_18, v44)
	v93 := fused_f32(-v84, mul_18, v44)
	mul_19 := f32(0.6468217833599901)
	v94 := fused_f32(v86, mul_19, v46)
	v95 := fused_f32(-v86, mul_19, v46)
	mul_20 := f32(0.7881546234512502)
	v96 := fused_f32(v87, mul_20, v47)
	v97 := fused_f32(-v87, mul_20, v47)
	mul_21 := f32(1.0606776859903471)
	v98 := fused_f32(v85, mul_21, v45)
	v99 := fused_f32(-v85, mul_21, v45)
	mul_22 := f32(1.7224470982383342)
	v100 := fused_f32(v83, mul_22, v43)
	v101 := fused_f32(-v83, mul_22, v43)
	mul_23 := f32(5.1011486186891553)
	v102 := fused_f32(v81, mul_23, v41)
	v103 := fused_f32(-v81, mul_23, v41)
	unsafe {
		data[0] = v88
		data[1] = v90
		data[2] = v92
		data[3] = v94
		data[4] = v96
		data[5] = v98
		data[6] = v100
		data[7] = v102
		data[8] = v103
		data[9] = v101
		data[10] = v99
		data[11] = v97
		data[12] = v95
		data[13] = v93
		data[14] = v91
		data[15] = v89
	}
}


fn inverse_dct_32(input []f32) []f32 {
	mut output := []f32{len: 32}
	for i in 0 .. 32 { output[i] = input[i] }
	inverse_dct_32_in_place(unsafe { &f32(output.data) })
	return output
}

// In place over 32 contiguous values; every input is read before any write.
@[direct_array_access]
fn inverse_dct_32_in_place(data &f32) {
	v0 := unsafe { data[0] }
	v1 := unsafe { data[1] }
	v2 := unsafe { data[2] }
	v3 := unsafe { data[3] }
	v4 := unsafe { data[4] }
	v5 := unsafe { data[5] }
	v6 := unsafe { data[6] }
	v7 := unsafe { data[7] }
	v8 := unsafe { data[8] }
	v9 := unsafe { data[9] }
	v10 := unsafe { data[10] }
	v11 := unsafe { data[11] }
	v12 := unsafe { data[12] }
	v13 := unsafe { data[13] }
	v14 := unsafe { data[14] }
	v15 := unsafe { data[15] }
	v16 := unsafe { data[16] }
	v17 := unsafe { data[17] }
	v18 := unsafe { data[18] }
	v19 := unsafe { data[19] }
	v20 := unsafe { data[20] }
	v21 := unsafe { data[21] }
	v22 := unsafe { data[22] }
	v23 := unsafe { data[23] }
	v24 := unsafe { data[24] }
	v25 := unsafe { data[25] }
	v26 := unsafe { data[26] }
	v27 := unsafe { data[27] }
	v28 := unsafe { data[28] }
	v29 := unsafe { data[29] }
	v30 := unsafe { data[30] }
	v31 := unsafe { data[31] }
	v32 := v0 + v16
	v33 := v0 - v16
	v34 := v8 + v24
	v35 := v8 * f32(1.4142135623730950488)
	v36 := v35 + v34
	v37 := v35 - v34
	mul_0 := f32(0.5411961001461970)
	v38 := fused_f32(v36, mul_0, v32)
	v39 := fused_f32(-v36, mul_0, v32)
	mul_1 := f32(1.3065629648763764)
	v40 := fused_f32(v37, mul_1, v33)
	v41 := fused_f32(-v37, mul_1, v33)
	v42 := v4 + v12
	v43 := v12 + v20
	v44 := v20 + v28
	v45 := v4 * f32(1.4142135623730950488)
	v46 := v45 + v43
	v47 := v45 - v43
	v48 := v42 + v44
	v49 := v42 * f32(1.4142135623730950488)
	v50 := v49 + v48
	v51 := v49 - v48
	mul_2 := f32(0.5411961001461970)
	v52 := fused_f32(v50, mul_2, v46)
	v53 := fused_f32(-v50, mul_2, v46)
	mul_3 := f32(1.3065629648763764)
	v54 := fused_f32(v51, mul_3, v47)
	v55 := fused_f32(-v51, mul_3, v47)
	mul_4 := f32(0.5097955791041592)
	v56 := fused_f32(v52, mul_4, v38)
	v57 := fused_f32(-v52, mul_4, v38)
	mul_5 := f32(0.6013448869350453)
	v58 := fused_f32(v54, mul_5, v40)
	v59 := fused_f32(-v54, mul_5, v40)
	mul_6 := f32(0.8999762231364156)
	v60 := fused_f32(v55, mul_6, v41)
	v61 := fused_f32(-v55, mul_6, v41)
	mul_7 := f32(2.5629154477415055)
	v62 := fused_f32(v53, mul_7, v39)
	v63 := fused_f32(-v53, mul_7, v39)
	v64 := v2 + v6
	v65 := v6 + v10
	v66 := v10 + v14
	v67 := v14 + v18
	v68 := v18 + v22
	v69 := v22 + v26
	v70 := v26 + v30
	v71 := v2 * f32(1.4142135623730950488)
	v72 := v71 + v67
	v73 := v71 - v67
	v74 := v65 + v69
	v75 := v65 * f32(1.4142135623730950488)
	v76 := v75 + v74
	v77 := v75 - v74
	mul_8 := f32(0.5411961001461970)
	v78 := fused_f32(v76, mul_8, v72)
	v79 := fused_f32(-v76, mul_8, v72)
	mul_9 := f32(1.3065629648763764)
	v80 := fused_f32(v77, mul_9, v73)
	v81 := fused_f32(-v77, mul_9, v73)
	v82 := v64 + v66
	v83 := v66 + v68
	v84 := v68 + v70
	v85 := v64 * f32(1.4142135623730950488)
	v86 := v85 + v83
	v87 := v85 - v83
	v88 := v82 + v84
	v89 := v82 * f32(1.4142135623730950488)
	v90 := v89 + v88
	v91 := v89 - v88
	mul_10 := f32(0.5411961001461970)
	v92 := fused_f32(v90, mul_10, v86)
	v93 := fused_f32(-v90, mul_10, v86)
	mul_11 := f32(1.3065629648763764)
	v94 := fused_f32(v91, mul_11, v87)
	v95 := fused_f32(-v91, mul_11, v87)
	mul_12 := f32(0.5097955791041592)
	v96 := fused_f32(v92, mul_12, v78)
	v97 := fused_f32(-v92, mul_12, v78)
	mul_13 := f32(0.6013448869350453)
	v98 := fused_f32(v94, mul_13, v80)
	v99 := fused_f32(-v94, mul_13, v80)
	mul_14 := f32(0.8999762231364156)
	v100 := fused_f32(v95, mul_14, v81)
	v101 := fused_f32(-v95, mul_14, v81)
	mul_15 := f32(2.5629154477415055)
	v102 := fused_f32(v93, mul_15, v79)
	v103 := fused_f32(-v93, mul_15, v79)
	mul_16 := f32(0.5024192861881557)
	v104 := fused_f32(v96, mul_16, v56)
	v105 := fused_f32(-v96, mul_16, v56)
	mul_17 := f32(0.5224986149396889)
	v106 := fused_f32(v98, mul_17, v58)
	v107 := fused_f32(-v98, mul_17, v58)
	mul_18 := f32(0.5669440348163577)
	v108 := fused_f32(v100, mul_18, v60)
	v109 := fused_f32(-v100, mul_18, v60)
	mul_19 := f32(0.6468217833599901)
	v110 := fused_f32(v102, mul_19, v62)
	v111 := fused_f32(-v102, mul_19, v62)
	mul_20 := f32(0.7881546234512502)
	v112 := fused_f32(v103, mul_20, v63)
	v113 := fused_f32(-v103, mul_20, v63)
	mul_21 := f32(1.0606776859903471)
	v114 := fused_f32(v101, mul_21, v61)
	v115 := fused_f32(-v101, mul_21, v61)
	mul_22 := f32(1.7224470982383342)
	v116 := fused_f32(v99, mul_22, v59)
	v117 := fused_f32(-v99, mul_22, v59)
	mul_23 := f32(5.1011486186891553)
	v118 := fused_f32(v97, mul_23, v57)
	v119 := fused_f32(-v97, mul_23, v57)
	v120 := v1 + v3
	v121 := v3 + v5
	v122 := v5 + v7
	v123 := v7 + v9
	v124 := v9 + v11
	v125 := v11 + v13
	v126 := v13 + v15
	v127 := v15 + v17
	v128 := v17 + v19
	v129 := v19 + v21
	v130 := v21 + v23
	v131 := v23 + v25
	v132 := v25 + v27
	v133 := v27 + v29
	v134 := v29 + v31
	v135 := v1 * f32(1.4142135623730950488)
	v136 := v135 + v127
	v137 := v135 - v127
	v138 := v123 + v131
	v139 := v123 * f32(1.4142135623730950488)
	v140 := v139 + v138
	v141 := v139 - v138
	mul_24 := f32(0.5411961001461970)
	v142 := fused_f32(v140, mul_24, v136)
	v143 := fused_f32(-v140, mul_24, v136)
	mul_25 := f32(1.3065629648763764)
	v144 := fused_f32(v141, mul_25, v137)
	v145 := fused_f32(-v141, mul_25, v137)
	v146 := v121 + v125
	v147 := v125 + v129
	v148 := v129 + v133
	v149 := v121 * f32(1.4142135623730950488)
	v150 := v149 + v147
	v151 := v149 - v147
	v152 := v146 + v148
	v153 := v146 * f32(1.4142135623730950488)
	v154 := v153 + v152
	v155 := v153 - v152
	mul_26 := f32(0.5411961001461970)
	v156 := fused_f32(v154, mul_26, v150)
	v157 := fused_f32(-v154, mul_26, v150)
	mul_27 := f32(1.3065629648763764)
	v158 := fused_f32(v155, mul_27, v151)
	v159 := fused_f32(-v155, mul_27, v151)
	mul_28 := f32(0.5097955791041592)
	v160 := fused_f32(v156, mul_28, v142)
	v161 := fused_f32(-v156, mul_28, v142)
	mul_29 := f32(0.6013448869350453)
	v162 := fused_f32(v158, mul_29, v144)
	v163 := fused_f32(-v158, mul_29, v144)
	mul_30 := f32(0.8999762231364156)
	v164 := fused_f32(v159, mul_30, v145)
	v165 := fused_f32(-v159, mul_30, v145)
	mul_31 := f32(2.5629154477415055)
	v166 := fused_f32(v157, mul_31, v143)
	v167 := fused_f32(-v157, mul_31, v143)
	v168 := v120 + v122
	v169 := v122 + v124
	v170 := v124 + v126
	v171 := v126 + v128
	v172 := v128 + v130
	v173 := v130 + v132
	v174 := v132 + v134
	v175 := v120 * f32(1.4142135623730950488)
	v176 := v175 + v171
	v177 := v175 - v171
	v178 := v169 + v173
	v179 := v169 * f32(1.4142135623730950488)
	v180 := v179 + v178
	v181 := v179 - v178
	mul_32 := f32(0.5411961001461970)
	v182 := fused_f32(v180, mul_32, v176)
	v183 := fused_f32(-v180, mul_32, v176)
	mul_33 := f32(1.3065629648763764)
	v184 := fused_f32(v181, mul_33, v177)
	v185 := fused_f32(-v181, mul_33, v177)
	v186 := v168 + v170
	v187 := v170 + v172
	v188 := v172 + v174
	v189 := v168 * f32(1.4142135623730950488)
	v190 := v189 + v187
	v191 := v189 - v187
	v192 := v186 + v188
	v193 := v186 * f32(1.4142135623730950488)
	v194 := v193 + v192
	v195 := v193 - v192
	mul_34 := f32(0.5411961001461970)
	v196 := fused_f32(v194, mul_34, v190)
	v197 := fused_f32(-v194, mul_34, v190)
	mul_35 := f32(1.3065629648763764)
	v198 := fused_f32(v195, mul_35, v191)
	v199 := fused_f32(-v195, mul_35, v191)
	mul_36 := f32(0.5097955791041592)
	v200 := fused_f32(v196, mul_36, v182)
	v201 := fused_f32(-v196, mul_36, v182)
	mul_37 := f32(0.6013448869350453)
	v202 := fused_f32(v198, mul_37, v184)
	v203 := fused_f32(-v198, mul_37, v184)
	mul_38 := f32(0.8999762231364156)
	v204 := fused_f32(v199, mul_38, v185)
	v205 := fused_f32(-v199, mul_38, v185)
	mul_39 := f32(2.5629154477415055)
	v206 := fused_f32(v197, mul_39, v183)
	v207 := fused_f32(-v197, mul_39, v183)
	mul_40 := f32(0.5024192861881557)
	v208 := fused_f32(v200, mul_40, v160)
	v209 := fused_f32(-v200, mul_40, v160)
	mul_41 := f32(0.5224986149396889)
	v210 := fused_f32(v202, mul_41, v162)
	v211 := fused_f32(-v202, mul_41, v162)
	mul_42 := f32(0.5669440348163577)
	v212 := fused_f32(v204, mul_42, v164)
	v213 := fused_f32(-v204, mul_42, v164)
	mul_43 := f32(0.6468217833599901)
	v214 := fused_f32(v206, mul_43, v166)
	v215 := fused_f32(-v206, mul_43, v166)
	mul_44 := f32(0.7881546234512502)
	v216 := fused_f32(v207, mul_44, v167)
	v217 := fused_f32(-v207, mul_44, v167)
	mul_45 := f32(1.0606776859903471)
	v218 := fused_f32(v205, mul_45, v165)
	v219 := fused_f32(-v205, mul_45, v165)
	mul_46 := f32(1.7224470982383342)
	v220 := fused_f32(v203, mul_46, v163)
	v221 := fused_f32(-v203, mul_46, v163)
	mul_47 := f32(5.1011486186891553)
	v222 := fused_f32(v201, mul_47, v161)
	v223 := fused_f32(-v201, mul_47, v161)
	mul_48 := f32(0.5006029982351963)
	v224 := fused_f32(v208, mul_48, v104)
	v225 := fused_f32(-v208, mul_48, v104)
	mul_49 := f32(0.5054709598975436)
	v226 := fused_f32(v210, mul_49, v106)
	v227 := fused_f32(-v210, mul_49, v106)
	mul_50 := f32(0.5154473099226246)
	v228 := fused_f32(v212, mul_50, v108)
	v229 := fused_f32(-v212, mul_50, v108)
	mul_51 := f32(0.5310425910897841)
	v230 := fused_f32(v214, mul_51, v110)
	v231 := fused_f32(-v214, mul_51, v110)
	mul_52 := f32(0.5531038960344445)
	v232 := fused_f32(v216, mul_52, v112)
	v233 := fused_f32(-v216, mul_52, v112)
	mul_53 := f32(0.5829349682061339)
	v234 := fused_f32(v218, mul_53, v114)
	v235 := fused_f32(-v218, mul_53, v114)
	mul_54 := f32(0.6225041230356648)
	v236 := fused_f32(v220, mul_54, v116)
	v237 := fused_f32(-v220, mul_54, v116)
	mul_55 := f32(0.6748083414550057)
	v238 := fused_f32(v222, mul_55, v118)
	v239 := fused_f32(-v222, mul_55, v118)
	mul_56 := f32(0.7445362710022986)
	v240 := fused_f32(v223, mul_56, v119)
	v241 := fused_f32(-v223, mul_56, v119)
	mul_57 := f32(0.8393496454155268)
	v242 := fused_f32(v221, mul_57, v117)
	v243 := fused_f32(-v221, mul_57, v117)
	mul_58 := f32(0.9725682378619608)
	v244 := fused_f32(v219, mul_58, v115)
	v245 := fused_f32(-v219, mul_58, v115)
	mul_59 := f32(1.1694399334328847)
	v246 := fused_f32(v217, mul_59, v113)
	v247 := fused_f32(-v217, mul_59, v113)
	mul_60 := f32(1.4841646163141662)
	v248 := fused_f32(v215, mul_60, v111)
	v249 := fused_f32(-v215, mul_60, v111)
	mul_61 := f32(2.0577810099534108)
	v250 := fused_f32(v213, mul_61, v109)
	v251 := fused_f32(-v213, mul_61, v109)
	mul_62 := f32(3.4076084184687190)
	v252 := fused_f32(v211, mul_62, v107)
	v253 := fused_f32(-v211, mul_62, v107)
	mul_63 := f32(10.1900081235480329)
	v254 := fused_f32(v209, mul_63, v105)
	v255 := fused_f32(-v209, mul_63, v105)
	unsafe {
		data[0] = v224
		data[1] = v226
		data[2] = v228
		data[3] = v230
		data[4] = v232
		data[5] = v234
		data[6] = v236
		data[7] = v238
		data[8] = v240
		data[9] = v242
		data[10] = v244
		data[11] = v246
		data[12] = v248
		data[13] = v250
		data[14] = v252
		data[15] = v254
		data[16] = v255
		data[17] = v253
		data[18] = v251
		data[19] = v249
		data[20] = v247
		data[21] = v245
		data[22] = v243
		data[23] = v241
		data[24] = v239
		data[25] = v237
		data[26] = v235
		data[27] = v233
		data[28] = v231
		data[29] = v229
		data[30] = v227
		data[31] = v225
	}
}
