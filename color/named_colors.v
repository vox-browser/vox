// Copyright (c) 2018-2024, the SerenityOS developers.
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the CSS named-color table and lookup from LibGfx/Color.cpp (Color::from_named_css_color_
// string) — an ASCII case-insensitive match of a CSS named color keyword to its opaque RGB color. The
// table is generated verbatim from the upstream web_colors array.
// https://drafts.csswg.org/css-color/#named-colors
module color

// An opaque-by-default RGBA color.
pub struct Color {
pub:
	red   u8
	green u8
	blue  u8
	alpha u8 = 255
}

struct NamedColor {
	name string // lowercase
	rgb  u32    // 0xRRGGBB
}

const named_css_colors = [
	NamedColor{ name: 'black', rgb: 0x000000 },
	NamedColor{ name: 'silver', rgb: 0xc0c0c0 },
	NamedColor{ name: 'gray', rgb: 0x808080 },
	NamedColor{ name: 'white', rgb: 0xffffff },
	NamedColor{ name: 'maroon', rgb: 0x800000 },
	NamedColor{ name: 'red', rgb: 0xff0000 },
	NamedColor{ name: 'purple', rgb: 0x800080 },
	NamedColor{ name: 'fuchsia', rgb: 0xff00ff },
	NamedColor{ name: 'green', rgb: 0x008000 },
	NamedColor{ name: 'lime', rgb: 0x00ff00 },
	NamedColor{ name: 'olive', rgb: 0x808000 },
	NamedColor{ name: 'yellow', rgb: 0xffff00 },
	NamedColor{ name: 'navy', rgb: 0x000080 },
	NamedColor{ name: 'blue', rgb: 0x0000ff },
	NamedColor{ name: 'teal', rgb: 0x008080 },
	NamedColor{ name: 'aqua', rgb: 0x00ffff },
	NamedColor{ name: 'orange', rgb: 0xffa500 },
	NamedColor{ name: 'aliceblue', rgb: 0xf0f8ff },
	NamedColor{ name: 'antiquewhite', rgb: 0xfaebd7 },
	NamedColor{ name: 'aquamarine', rgb: 0x7fffd4 },
	NamedColor{ name: 'azure', rgb: 0xf0ffff },
	NamedColor{ name: 'beige', rgb: 0xf5f5dc },
	NamedColor{ name: 'bisque', rgb: 0xffe4c4 },
	NamedColor{ name: 'blanchedalmond', rgb: 0xffebcd },
	NamedColor{ name: 'blueviolet', rgb: 0x8a2be2 },
	NamedColor{ name: 'brown', rgb: 0xa52a2a },
	NamedColor{ name: 'burlywood', rgb: 0xdeb887 },
	NamedColor{ name: 'cadetblue', rgb: 0x5f9ea0 },
	NamedColor{ name: 'chartreuse', rgb: 0x7fff00 },
	NamedColor{ name: 'chocolate', rgb: 0xd2691e },
	NamedColor{ name: 'coral', rgb: 0xff7f50 },
	NamedColor{ name: 'cornflowerblue', rgb: 0x6495ed },
	NamedColor{ name: 'cornsilk', rgb: 0xfff8dc },
	NamedColor{ name: 'crimson', rgb: 0xdc143c },
	NamedColor{ name: 'cyan', rgb: 0x00ffff },
	NamedColor{ name: 'darkblue', rgb: 0x00008b },
	NamedColor{ name: 'darkcyan', rgb: 0x008b8b },
	NamedColor{ name: 'darkgoldenrod', rgb: 0xb8860b },
	NamedColor{ name: 'darkgray', rgb: 0xa9a9a9 },
	NamedColor{ name: 'darkgreen', rgb: 0x006400 },
	NamedColor{ name: 'darkgrey', rgb: 0xa9a9a9 },
	NamedColor{ name: 'darkkhaki', rgb: 0xbdb76b },
	NamedColor{ name: 'darkmagenta', rgb: 0x8b008b },
	NamedColor{ name: 'darkolivegreen', rgb: 0x556b2f },
	NamedColor{ name: 'darkorange', rgb: 0xff8c00 },
	NamedColor{ name: 'darkorchid', rgb: 0x9932cc },
	NamedColor{ name: 'darkred', rgb: 0x8b0000 },
	NamedColor{ name: 'darksalmon', rgb: 0xe9967a },
	NamedColor{ name: 'darkseagreen', rgb: 0x8fbc8f },
	NamedColor{ name: 'darkslateblue', rgb: 0x483d8b },
	NamedColor{ name: 'darkslategray', rgb: 0x2f4f4f },
	NamedColor{ name: 'darkslategrey', rgb: 0x2f4f4f },
	NamedColor{ name: 'darkturquoise', rgb: 0x00ced1 },
	NamedColor{ name: 'darkviolet', rgb: 0x9400d3 },
	NamedColor{ name: 'deeppink', rgb: 0xff1493 },
	NamedColor{ name: 'deepskyblue', rgb: 0x00bfff },
	NamedColor{ name: 'dimgray', rgb: 0x696969 },
	NamedColor{ name: 'dimgrey', rgb: 0x696969 },
	NamedColor{ name: 'dodgerblue', rgb: 0x1e90ff },
	NamedColor{ name: 'firebrick', rgb: 0xb22222 },
	NamedColor{ name: 'floralwhite', rgb: 0xfffaf0 },
	NamedColor{ name: 'forestgreen', rgb: 0x228b22 },
	NamedColor{ name: 'gainsboro', rgb: 0xdcdcdc },
	NamedColor{ name: 'ghostwhite', rgb: 0xf8f8ff },
	NamedColor{ name: 'gold', rgb: 0xffd700 },
	NamedColor{ name: 'goldenrod', rgb: 0xdaa520 },
	NamedColor{ name: 'greenyellow', rgb: 0xadff2f },
	NamedColor{ name: 'grey', rgb: 0x808080 },
	NamedColor{ name: 'honeydew', rgb: 0xf0fff0 },
	NamedColor{ name: 'hotpink', rgb: 0xff69b4 },
	NamedColor{ name: 'indianred', rgb: 0xcd5c5c },
	NamedColor{ name: 'indigo', rgb: 0x4b0082 },
	NamedColor{ name: 'ivory', rgb: 0xfffff0 },
	NamedColor{ name: 'khaki', rgb: 0xf0e68c },
	NamedColor{ name: 'lavender', rgb: 0xe6e6fa },
	NamedColor{ name: 'lavenderblush', rgb: 0xfff0f5 },
	NamedColor{ name: 'lawngreen', rgb: 0x7cfc00 },
	NamedColor{ name: 'lemonchiffon', rgb: 0xfffacd },
	NamedColor{ name: 'lightblue', rgb: 0xadd8e6 },
	NamedColor{ name: 'lightcoral', rgb: 0xf08080 },
	NamedColor{ name: 'lightcyan', rgb: 0xe0ffff },
	NamedColor{ name: 'lightgoldenrodyellow', rgb: 0xfafad2 },
	NamedColor{ name: 'lightgray', rgb: 0xd3d3d3 },
	NamedColor{ name: 'lightgreen', rgb: 0x90ee90 },
	NamedColor{ name: 'lightgrey', rgb: 0xd3d3d3 },
	NamedColor{ name: 'lightpink', rgb: 0xffb6c1 },
	NamedColor{ name: 'lightsalmon', rgb: 0xffa07a },
	NamedColor{ name: 'lightseagreen', rgb: 0x20b2aa },
	NamedColor{ name: 'lightskyblue', rgb: 0x87cefa },
	NamedColor{ name: 'lightslategray', rgb: 0x778899 },
	NamedColor{ name: 'lightslategrey', rgb: 0x778899 },
	NamedColor{ name: 'lightsteelblue', rgb: 0xb0c4de },
	NamedColor{ name: 'lightyellow', rgb: 0xffffe0 },
	NamedColor{ name: 'limegreen', rgb: 0x32cd32 },
	NamedColor{ name: 'linen', rgb: 0xfaf0e6 },
	NamedColor{ name: 'magenta', rgb: 0xff00ff },
	NamedColor{ name: 'mediumaquamarine', rgb: 0x66cdaa },
	NamedColor{ name: 'mediumblue', rgb: 0x0000cd },
	NamedColor{ name: 'mediumorchid', rgb: 0xba55d3 },
	NamedColor{ name: 'mediumpurple', rgb: 0x9370db },
	NamedColor{ name: 'mediumseagreen', rgb: 0x3cb371 },
	NamedColor{ name: 'mediumslateblue', rgb: 0x7b68ee },
	NamedColor{ name: 'mediumspringgreen', rgb: 0x00fa9a },
	NamedColor{ name: 'mediumturquoise', rgb: 0x48d1cc },
	NamedColor{ name: 'mediumvioletred', rgb: 0xc71585 },
	NamedColor{ name: 'midnightblue', rgb: 0x191970 },
	NamedColor{ name: 'mintcream', rgb: 0xf5fffa },
	NamedColor{ name: 'mistyrose', rgb: 0xffe4e1 },
	NamedColor{ name: 'moccasin', rgb: 0xffe4b5 },
	NamedColor{ name: 'navajowhite', rgb: 0xffdead },
	NamedColor{ name: 'oldlace', rgb: 0xfdf5e6 },
	NamedColor{ name: 'olivedrab', rgb: 0x6b8e23 },
	NamedColor{ name: 'orangered', rgb: 0xff4500 },
	NamedColor{ name: 'orchid', rgb: 0xda70d6 },
	NamedColor{ name: 'palegoldenrod', rgb: 0xeee8aa },
	NamedColor{ name: 'palegreen', rgb: 0x98fb98 },
	NamedColor{ name: 'paleturquoise', rgb: 0xafeeee },
	NamedColor{ name: 'palevioletred', rgb: 0xdb7093 },
	NamedColor{ name: 'papayawhip', rgb: 0xffefd5 },
	NamedColor{ name: 'peachpuff', rgb: 0xffdab9 },
	NamedColor{ name: 'peru', rgb: 0xcd853f },
	NamedColor{ name: 'pink', rgb: 0xffc0cb },
	NamedColor{ name: 'plum', rgb: 0xdda0dd },
	NamedColor{ name: 'powderblue', rgb: 0xb0e0e6 },
	NamedColor{ name: 'rosybrown', rgb: 0xbc8f8f },
	NamedColor{ name: 'royalblue', rgb: 0x4169e1 },
	NamedColor{ name: 'saddlebrown', rgb: 0x8b4513 },
	NamedColor{ name: 'salmon', rgb: 0xfa8072 },
	NamedColor{ name: 'sandybrown', rgb: 0xf4a460 },
	NamedColor{ name: 'seagreen', rgb: 0x2e8b57 },
	NamedColor{ name: 'seashell', rgb: 0xfff5ee },
	NamedColor{ name: 'sienna', rgb: 0xa0522d },
	NamedColor{ name: 'skyblue', rgb: 0x87ceeb },
	NamedColor{ name: 'slateblue', rgb: 0x6a5acd },
	NamedColor{ name: 'slategray', rgb: 0x708090 },
	NamedColor{ name: 'slategrey', rgb: 0x708090 },
	NamedColor{ name: 'snow', rgb: 0xfffafa },
	NamedColor{ name: 'springgreen', rgb: 0x00ff7f },
	NamedColor{ name: 'steelblue', rgb: 0x4682b4 },
	NamedColor{ name: 'tan', rgb: 0xd2b48c },
	NamedColor{ name: 'thistle', rgb: 0xd8bfd8 },
	NamedColor{ name: 'tomato', rgb: 0xff6347 },
	NamedColor{ name: 'turquoise', rgb: 0x40e0d0 },
	NamedColor{ name: 'violet', rgb: 0xee82ee },
	NamedColor{ name: 'wheat', rgb: 0xf5deb3 },
	NamedColor{ name: 'whitesmoke', rgb: 0xf5f5f5 },
	NamedColor{ name: 'yellowgreen', rgb: 0x9acd32 },
	NamedColor{ name: 'rebeccapurple', rgb: 0x663399 },
]

fn ascii_lowercase(input string) string {
	mut bytes := input.bytes()
	for i, ch in bytes {
		if ch >= `A` && ch <= `Z` {
			bytes[i] = ch + 0x20
		}
	}
	return bytes.bytestr()
}

// https://drafts.csswg.org/css-color/#named-colors — the color for a named-color keyword (matched ASCII
// case-insensitively), or none. "transparent" is not a named color here (it is handled separately).
pub fn from_named_css_color_string(input string) ?Color {
	if input == '' {
		return none
	}
	lowercased := ascii_lowercase(input)
	for named in named_css_colors {
		if named.name == lowercased {
			return Color{
				red:   u8((named.rgb >> 16) & 0xFF)
				green: u8((named.rgb >> 8) & 0xFF)
				blue:  u8(named.rgb & 0xFF)
				alpha: 255
			}
		}
	}
	return none
}
