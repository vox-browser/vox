// LibUnicode/CaseMapping.cpp. Native Unicode service; layout and slicing are in V.
#include "unicode_case_mapping.h"
#include <cstdlib>
#include <unicode/casemap.h>
#include <unicode/edits.h>
#include <unicode/stringoptions.h>

extern "C" bool libweb_v_case_mapping(uint16_t const* input, int length, char const* locale, int mapping, LibWebVCaseMapping* output)
{
    char16_t const empty_source = 0;
    auto const* source = length == 0 ? &empty_source : reinterpret_cast<char16_t const*>(input);
    auto map = [&](char16_t* destination, int capacity, icu::Edits* edits, UErrorCode& status) {
        switch (mapping) {
        case 0: return icu::CaseMap::toLower(locale, 0, source, length, destination, capacity, edits, status);
        case 1: return icu::CaseMap::toUpper(locale, 0, source, length, destination, capacity, edits, status);
        case 2: return icu::CaseMap::toTitle(locale, U_TITLECASE_NO_LOWERCASE, nullptr, source, length, destination, capacity, edits, status);
        default: status = U_ILLEGAL_ARGUMENT_ERROR; return 0;
        }
    };
    UErrorCode status = U_ZERO_ERROR;
    int destination_length = map(nullptr, 0, nullptr, status);
    if (status != U_BUFFER_OVERFLOW_ERROR && U_FAILURE(status)) return false;
    output->text = static_cast<uint16_t*>(std::malloc((destination_length + 1) * sizeof(uint16_t)));
    output->edits = static_cast<LibWebVCaseEdit*>(std::malloc((length + 1) * sizeof(LibWebVCaseEdit)));
    if (!output->text || !output->edits) { libweb_v_case_mapping_free(output); return false; }
    status = U_ZERO_ERROR;
    icu::Edits edits;
    output->text_length = map(reinterpret_cast<char16_t*>(output->text), destination_length, &edits, status);
    if (U_FAILURE(status) || output->text_length != destination_length) { libweb_v_case_mapping_free(output); return false; }
    output->edit_count = 0;
    auto iterator = edits.getFineChangesIterator();
    while (iterator.next(status)) {
        if (iterator.oldLength() == iterator.newLength()) continue;
        output->edits[output->edit_count++] = { iterator.sourceIndex(), iterator.oldLength(), iterator.destinationIndex(), iterator.newLength() };
    }
    if (U_FAILURE(status)) { libweb_v_case_mapping_free(output); return false; }
    return true;
}
extern "C" void libweb_v_case_mapping_free(LibWebVCaseMapping* output)
{
    std::free(output->text);
    std::free(output->edits);
    output->text = nullptr;
    output->edits = nullptr;
}
