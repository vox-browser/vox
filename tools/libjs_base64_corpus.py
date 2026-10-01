#!/usr/bin/env python3
"""Refresh exact codec fixtures from Ladybird's pinned simdutf 7.4.0 backend."""
import argparse
import base64
import os
from pathlib import Path
import random
import subprocess
import tempfile

ORACLE = r'''
#include <simdutf.h>
#include <simdutf/simdutf_version.h>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>
int main() {
    static_assert(simdutf::SIMDUTF_VERSION_MAJOR == 7 && simdutf::SIMDUTF_VERSION_MINOR == 4
                  && simdutf::SIMDUTF_VERSION_REVISION == 0);
    std::string line;
    while (std::getline(std::cin, line)) {
        std::istringstream fields(line);
        int alphabet, handling;
        size_t capacity;
        std::string hex;
        fields >> alphabet >> handling >> capacity >> hex;
        std::u16string input;
        if (hex != "-")
            for (size_t i = 0; i < hex.size(); i += 4)
                input += char16_t(std::stoul(hex.substr(i, 4), nullptr, 16));
        std::vector<char> output(capacity);
        auto length = capacity;
        auto result = simdutf::base64_to_binary_safe(input.data(), input.size(), output.data(), length,
            alphabet ? simdutf::base64_url : simdutf::base64_default,
            handling == 0 ? simdutf::last_chunk_handling_options::loose
                : handling == 1 ? simdutf::last_chunk_handling_options::strict
                : simdutf::last_chunk_handling_options::stop_before_partial, true);
        std::string error;
        switch (result.error) {
        case simdutf::SUCCESS: error = "success"; break;
        case simdutf::OUTPUT_BUFFER_TOO_SMALL: error = "output_buffer_too_small"; break;
        case simdutf::BASE64_EXTRA_BITS: error = "extra_bits"; break;
        case simdutf::BASE64_INPUT_REMAINDER: error = "input_remainder"; break;
        case simdutf::INVALID_BASE64_CHARACTER: error = "invalid_character"; break;
        default: return 2;
        }
        std::cout << error << '|' << result.count << '|';
        for (size_t i = 0; i < length; ++i)
            std::cout << std::hex << std::setw(2) << std::setfill('0') << unsigned(uint8_t(output[i]));
        std::cout << std::dec << '\n';
    }
}
'''


def cases():
    inputs = ["", " ", "\t\n\r\f", "A", "AA", "AAA", "AAAA", "A==", "=", "==", "===",
              "====", "Zg", "Zg=", "Zg==", "Zh==", "Zm8", "Zm8=", "Zm9=", "Zm9v", "Zm9v=",
              "Zm9va", "Zm9vaa", "Zm9vaa=", "Zm9vaa=a", "Zm9vYg==", "Zm9vYmE=", "Zm9vYmFy",
              "8J+kkw==", "8J-kkw==", "8J+kk2Zvb/CflpY=", "8J-kk2Zvb_CflpY=", "b2g_",
              "AAA?AAAA", "AAAA?AAAA", "AAAAAA?A", "A=AA", "AA=A", " A A = = \n", "AA \t== \n",
              "Zm9v  Y g = = \t", "AAAA \t A", "  A", " AAAAAA ", "AA\vAA", "AA\u00a0AA",
              "AA\ud800AA", "AA\udc00AA", "AA\u0100AA", "AA\uff21AA", "-_+/", "////", "____"]
    rng = random.Random(0x564f5832)
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/-_= \t\n\r\f?\v\u00a0\u0100\ud800"
    for _ in range(150):
        inputs.append("".join(rng.choice(alphabet) for _ in range(rng.randrange(1, 41))))
    for size in [1, 2, 3, 4, 17, 47, 48, 49, 63, 64, 65, 127, 128, 129]:
        raw = bytes(rng.randrange(256) for _ in range(size))
        for encode in [base64.b64encode, base64.urlsafe_b64encode]:
            text = encode(raw).decode("ascii")
            inputs.extend([text, " \t" + text + "\n", text.rstrip("="), text[:-1] + "?"])
    block = "AAAA" * 144
    inputs.extend([block, " \t" + block + "\n", block + "AA==", block + "AAAA?",
                   block + "AA\ud800A", " A " * 210 + "AA", block + "Zh=="])
    for text in inputs:
        raw = text.encode("utf-16-le", "surrogatepass")
        units = [int.from_bytes(raw[i:i + 2], "little") for i in range(0, len(raw), 2)]
        hex_units = "".join(f"{unit:04x}" for unit in units)
        for alphabet in range(2):
            for handling in range(3):
                capacities = ({0, 3, 47, 48, 431, 432, 433, 700} if len(units) > 200 else
                              {0, 1, 2, 3, 4, 5, 6, max(0, len(units) * 3 // 4), len(units) + 3})
                for capacity in sorted(capacities):
                    yield hex_units, alphabet, handling, capacity


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simdutf-prefix", type=Path, default=Path.home() /
                        "code/3rd/ladybird/Build/release/vcpkg_installed/arm64-osx-dynamic")
    parser.add_argument("--output", type=Path, default=Path(__file__).resolve().parents[1] /
                        "libjs/testdata/base64-codec.tsv")
    args = parser.parse_args()
    records = list(cases())
    with tempfile.TemporaryDirectory(prefix="vox2-base64-") as directory:
        source = Path(directory) / "oracle.cpp"
        binary = Path(directory) / "oracle"
        source.write_text(ORACLE)
        prefix = args.simdutf_prefix.resolve()
        subprocess.run([os.environ.get("CXX", "c++"), "-std=c++17", str(source),
                        "-I" + str(prefix / "include"), "-L" + str(prefix / "lib"),
                        "-Wl,-rpath," + str(prefix / "lib"), "-lsimdutf", "-o", str(binary)], check=True)
        request = "".join(f"{alphabet} {handling} {capacity} {units or '-'}\n"
                          for units, alphabet, handling, capacity in records)
        result = subprocess.run([str(binary)], input=request, text=True, capture_output=True, check=True)
    answers = result.stdout.splitlines()
    assert len(answers) == len(records)
    fixture = ["# simdutf 7.4.0 base64_to_binary_safe UTF-16, decode_up_to_bad_char=true",
               "# UTF16 hex|alphabet|last chunk mode|capacity|status|read|output hex"]
    fixture.extend(f"{units}|{alphabet}|{handling}|{capacity}|{answer}"
                   for (units, alphabet, handling, capacity), answer in zip(records, answers))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(fixture) + "\n")
    print(f"Wrote {len(records)} exact comparisons to {args.output}")


if __name__ == "__main__":
    main()
