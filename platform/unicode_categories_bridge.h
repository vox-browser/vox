#pragma once
#include <stdint.h>
#include <unicode/uchar.h>

// LayoutRustBridge.cpp::ladybird_layout_code_point_category_facts and
// LibUnicode/CharacterTypes.cpp use these same ICU general-category masks.
static uint32_t libweb_v_code_point_category_facts(uint32_t code_point)
{
    uint32_t category = U_GET_GC_MASK((UChar32)code_point);
    return ((category & U_GC_ZS_MASK) != 0 ? 1u : 0u)
        | ((category & U_GC_P_MASK) != 0 ? 2u : 0u)
        | ((category & U_GC_L_MASK) != 0 ? 4u : 0u)
        | ((category & U_GC_N_MASK) != 0 ? 8u : 0u)
        | ((category & U_GC_S_MASK) != 0 ? 16u : 0u)
        | ((category & U_GC_PS_MASK) != 0 ? 32u : 0u)
        | ((category & U_GC_PD_MASK) != 0 ? 64u : 0u);
}
