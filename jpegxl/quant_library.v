// Copyright (c) the JPEG XL Project Authors. All rights reserved.
// SPDX-License-Identifier: BSD-3-Clause
// Calibration words translated from jxl 0.7.0 library encodings.
module jpegxl

import math

fn quant_library_values(words [3][]u32) [3][]f32 {
	return [words[0].map(math.f32_from_bits(it)), words[1].map(math.f32_from_bits(it)),
		words[2].map(math.f32_from_bits(it))]!
}

pub fn library_quant_encoding(table_index int) !NonRawQuantEncoding {
	match table_index {
		0 {
			return DctQuantEncoding{ parameters: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x4544e000), 0x00000000, 0xbecccccd, 0xbecccccd, 0xbecccccd, 0xc0000000],
				[u32(0x440c0000), 0x00000000, 0xbe99999a, 0xbe99999a, 0xbe99999a, 0xbe99999a],
				[u32(0x44000000), 0xc0000000, 0xbf800000, 0x00000000, 0xbf800000, 0xc0000000],
			]!) } }
		}
		1 {
			return IdentityQuantEncoding{ weights: quant_library_values([
				[u32(0x438c0000), 0x45458000, 0x45458000],
				[u32(0x42700000), 0x44580000, 0x44580000],
				[u32(0x41900000), 0x43480000, 0x43480000],
			]!) }
		}
		2 {
			return Dct2QuantEncoding{ weights: quant_library_values([
				[u32(0x45700000), 0x45200000, 0x44a00000, 0x44200000, 0x43f00000, 0x43960000],
				[u32(0x44700000), 0x44200000, 0x43a00000, 0x43340000, 0x430c0000, 0x42f00000],
				[u32(0x44200000), 0x43a00000, 0x43000000, 0x42800000, 0x42000000, 0x41800000],
			]!) }
		}
		3 {
			return Dct4QuantEncoding{ multipliers: quant_library_values([
				[u32(0x3f800000), 0x3f800000],
				[u32(0x3f800000), 0x3f800000],
				[u32(0x3f800000), 0x3f800000],
			]!), parameters: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x45098000), 0x00000000, 0x00000000, 0x00000000],
				[u32(0x43c40000), 0x00000000, 0x00000000, 0x00000000],
				[u32(0x42e00000), 0xbe800000, 0xbe800000, 0xbf000000],
			]!) } }
		}
		4 {
			return DctQuantEncoding{ parameters: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x460c937e), 0xbfa668f3, 0xbefd0db8, 0xbee0d0e6, 0xbf229007, 0xbf66da92,
					0xbfcedff7],
				[u32(0x454777bd), 0xbf2c9b60, 0xbf4eb594, 0xbee60532, 0xbeb7a18d, 0xbea05ee2,
					0xbec096c4],
				[u32(0x4490b021), 0xc00366af, 0xbfb33333, 0xbf01c251, 0xbedaab30, 0xbfbe2ae0,
					0xc09d7821],
			]!) } }
		}
		5 {
			return DctQuantEncoding{ parameters: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x467599a2), 0xbf833333, 0xbf7ae148, 0xbf66b50b, 0xbecccccd, 0xbef9f48f,
					0xbed795b3, 0xbe8a3d71],
				[u32(0x45e44e1c), 0xbf4ddfc7, 0xbf4367de, 0xbf0e7d96, 0xbefee698, 0xbedfbdee,
					0xbecdb9de, 0xbe8be314],
				[u32(0x456db882), 0xc043e30f, 0xc002a51a, 0xc0018217, 0xbf0cae96, 0xbecccccd,
					0xbecccccd, 0xbe99999a],
			]!) } }
		}
		6 {
			return DctQuantEncoding{ parameters: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x45e24630), 0xbf333333, 0xbf333333, 0xbe4ccccd, 0xbe4ccccd, 0xbe4ccccd,
					0xbf000000],
				[u32(0x44b504f3), 0xbf000000, 0xbf000000, 0xbf000000, 0xbe4ccccd, 0xbe4ccccd,
					0xbe4ccccd],
				[u32(0x43fd6d54), 0xbfb33333, 0xbe4ccccd, 0xbf000000, 0xbf000000, 0xbfc00000,
					0xc0666666],
			]!) } }
		}
		7 {
			return DctQuantEncoding{ parameters: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x467e6cff), 0xbfe40122, 0xbfd0c186, 0xbf84e453, 0xbf59999a, 0xbf333333,
					0xbf666666, 0xbf9e3757],
				[u32(0x459f0943), 0xbea3dd84, 0xbeb50ecb, 0xbe9b573f, 0xbf1c28f6, 0xbf000000,
					0xbf000000, 0xbf19999a],
				[u32(0x45545c6b), 0xbea48505, 0xbeb0add4, 0xbf341206, 0xbf666666, 0xbf800000,
					0xbf800000, 0xbf96757e],
			]!) } }
		}
		8 {
			return DctQuantEncoding{ parameters: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x465853e2), 0xbf789c80, 0xbf2872b0, 0xbed72c52, 0xbe689225, 0xbe61e4f7,
					0xbe676c8b, 0xbf19999a],
				[u32(0x4595f7b6), 0xbf1c7b15, 0xbf567406, 0xbf4a472e, 0xbe89de1e, 0xbec3f4e2,
					0xbe6abe79, 0xbe5429e0],
				[u32(0x44e1e795), 0xbf99999a, 0xbf99999a, 0xbf333333, 0xbf333333, 0xbf333333,
					0xbecccccd, 0xbf000000],
			]!) } }
		}
		9 {
			return Dct4x8QuantEncoding{ multipliers: quant_library_values([
				[u32(0x3f800000)],
				[u32(0x3f800000)],
				[u32(0x3f800000)],
			]!), parameters: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x450960cf), 0xbf767343, 0xbf430eaa, 0xbf27b58e],
				[u32(0x443f1765), 0xbf6d2221, 0xbf77af96, 0xbe8e9161],
				[u32(0x4403c6e2), 0xbfbacee2, 0xbfb99c4a, 0xbfcaccb6],
			]!) } }
		}
		10 {
			return AfvQuantEncoding{ weights: quant_library_values([
				[u32(0x45400000), 0x45400000, 0x43800000, 0x43800000, 0x43800000, 0x43cf0000,
					0x00000000, 0x00000000, 0x00000000],
				[u32(0x44800000), 0x44800000, 0x42480000, 0x42480000, 0x42480000, 0x42680000,
					0x00000000, 0x00000000, 0x00000000],
				[u32(0x43c00000), 0x43c00000, 0x41400000, 0x41400000, 0x41400000, 0x41b00000,
					0xbe800000, 0xbe800000, 0xbe800000],
			]!), parameters4x8: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x450960cf), 0xbf767343, 0xbf430eaa, 0xbf27b58e],
				[u32(0x443f1765), 0xbf6d2221, 0xbf77af96, 0xbe8e9161],
				[u32(0x4403c6e2), 0xbfbacee2, 0xbfb99c4a, 0xbfcaccb6],
			]!) }, parameters4x4: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x45098000), 0x00000000, 0x00000000, 0x00000000],
				[u32(0x43c40000), 0x00000000, 0x00000000, 0x00000000],
				[u32(0x42e00000), 0xbe800000, 0xbe800000, 0xbf000000],
			]!) } }
		}
		11 {
			return DctQuantEncoding{ parameters: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x46bb3c55), 0xbf833333, 0xbf47ae14, 0xbf266e44, 0xbe42fc58, 0xbe5530cc,
					0xbed795b3, 0xbea798e8],
				[u32(0x4602f0c4), 0xbe9bbf8e, 0xbeba02ef, 0xbeb694c6, 0xbeb04911, 0xbeac8abb,
					0xbe9a86aa, 0xbe8be314],
				[u32(0x458c6830), 0xbf99999a, 0xbf99999a, 0xbf4ccccd, 0xbf333333, 0xbf333333,
					0xbecccccd, 0xbf000000],
			]!) } }
		}
		12 {
			return DctQuantEncoding{ parameters: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x466ffb97), 0xbf833333, 0xbf47ae14, 0xbf266e44, 0xbe42fc58, 0xbe5530cc,
					0xbed795b3, 0xbea798e8],
				[u32(0x45aeeae2), 0xbe9bbf8e, 0xbeba02ef, 0xbeb694c6, 0xbeb04911, 0xbeac8abb,
					0xbe9a86aa, 0xbe8be314],
				[u32(0x45367f62), 0xbf99999a, 0xbf99999a, 0xbf4ccccd, 0xbf333333, 0xbf333333,
					0xbecccccd, 0xbf000000],
			]!) } }
		}
		13 {
			return DctQuantEncoding{ parameters: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x473b3c55), 0xbf833333, 0xbf47ae14, 0xbf266e44, 0xbe42fc58, 0xbe5530cc,
					0xbed795b3, 0xbea798e8],
				[u32(0x4682f0c4), 0xbe9bbf8e, 0xbeba02ef, 0xbeb694c6, 0xbeb04911, 0xbeac8abb,
					0xbe9a86aa, 0xbe8be314],
				[u32(0x460c6830), 0xbf99999a, 0xbf99999a, 0xbf4ccccd, 0xbf333333, 0xbf333333,
					0xbecccccd, 0xbf000000],
			]!) } }
		}
		14 {
			return DctQuantEncoding{ parameters: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x46effb97), 0xbf833333, 0xbf47ae14, 0xbf266e44, 0xbe42fc58, 0xbe5530cc,
					0xbed795b3, 0xbea798e8],
				[u32(0x462eeae2), 0xbe9bbf8e, 0xbeba02ef, 0xbeb694c6, 0xbeb04911, 0xbeac8abb,
					0xbe9a86aa, 0xbe8be314],
				[u32(0x45b67f62), 0xbf99999a, 0xbf99999a, 0xbf4ccccd, 0xbf333333, 0xbf333333,
					0xbecccccd, 0xbf000000],
			]!) } }
		}
		15 {
			return DctQuantEncoding{ parameters: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x47bb3c55), 0xbf833333, 0xbf47ae14, 0xbf266e44, 0xbe42fc58, 0xbe5530cc,
					0xbed795b3, 0xbea798e8],
				[u32(0x4702f0c4), 0xbe9bbf8e, 0xbeba02ef, 0xbeb694c6, 0xbeb04911, 0xbeac8abb,
					0xbe9a86aa, 0xbe8be314],
				[u32(0x468c6830), 0xbf99999a, 0xbf99999a, 0xbf4ccccd, 0xbf333333, 0xbf333333,
					0xbecccccd, 0xbf000000],
			]!) } }
		}
		16 {
			return DctQuantEncoding{ parameters: DctQuantWeightParams{ parameters: quant_library_values([
				[u32(0x476ffb97), 0xbf833333, 0xbf47ae14, 0xbf266e44, 0xbe42fc58, 0xbe5530cc,
					0xbed795b3, 0xbea798e8],
				[u32(0x46aeeae2), 0xbe9bbf8e, 0xbeba02ef, 0xbeb694c6, 0xbeb04911, 0xbeac8abb,
					0xbe9a86aa, 0xbe8be314],
				[u32(0x46367f62), 0xbf99999a, 0xbf99999a, 0xbf4ccccd, 0xbf333333, 0xbf333333,
					0xbecccccd, 0xbf000000],
			]!) } }
		}
		else { return error('Invalid JPEG XL library quantization index') }
	}
}
