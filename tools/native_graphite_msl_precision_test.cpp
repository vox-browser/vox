#include "vox_msl_precision_under_test.h"
#include <cassert>
#include <cstdint>
#include <iostream>
#include <random>
#include <regex>
#include <vector>

static std::string previous(std::string const& source)
{
    static std::regex const type(R"(\bhalf([234](x[234])?)?\b)");
    static std::regex const literal(R"(([0-9])h\b)");
    return std::regex_replace(std::regex_replace(source, type, "float$1"), literal, "$1f");
}

int main()
{
    size_t cases = 0;
    auto check = [&](std::string const& source) {
        assert(vox_promote_msl_precision(source) == previous(source));
        ++cases;
    };
    assert(vox_promote_msl_precision("half half2 half3x4 half4x2(1.25h)") ==
           "float float2 float3x4 float4x2(1.25f)");
    assert(vox_promote_msl_precision("half1 half5 half2x5 half_ ahalf half2x") ==
           "half1 half5 half2x5 half_ ahalf half2x");
    std::vector<std::string> tokens {
        "", "half", "half2", "half3", "half4", "half2x2", "half3x4", "half4x3",
        "half1", "half5", "half2x", "half2x5", "half2x22", "halff", "hhalf",
        "1h", "123h", "1.25h", "1h2", "1h_", "1half", "1hhalf", "half2x4h",
    };
    // Exhaust all byte boundaries, including embedded NUL and UTF-8 bytes.
    for (auto const& token : tokens) {
        check(token);
        for (unsigned byte = 0; byte < 256; ++byte) {
            check(std::string(1, static_cast<char>(byte)) + token);
            check(token + static_cast<char>(byte));
            check(std::string(1, static_cast<char>(byte)) + token + static_cast<char>(byte));
        }
    }
    for (char rows = '2'; rows <= '4'; ++rows) for (char columns = '2'; columns <= '4'; ++columns)
        check(std::string("half") + rows + 'x' + columns);
    check("// half and 1h\nconstant half4 value = half4(1h, -2.0h, .3h, 4e-2h);\n");
    check("\"half half3x4 0h\" /* half2 */ ");
    std::mt19937 random(50231722);
    std::string alphabet = "half234x019_ .;()\n+-";
    for (unsigned trial = 0; trial < 6000; ++trial) {
        std::string source;
        for (unsigned i = 0, count = random() % 160; i < count; ++i) {
            if ((random() % 5) == 0) source += tokens[random() % tokens.size()];
            else source += alphabet[random() % alphabet.size()];
        }
        check(source);
    }
    // A large generated shader exercises repeated types and literal suffixes.
    std::string shader;
    for (unsigned i = 0; i < 10000; ++i)
        shader += "half4 color = half4(0.125h) + half3x4(2h)[0];\n";
    check(shader);
    std::cout << "MSL precision: " << cases << " differential cases passed\n";
}
