#include <cstddef>
#include <cstdint>
#include <string_view>

#include "json.hpp"

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size)
{
    std::string_view content(reinterpret_cast<const char*>(data), size);

    auto strict = json::parse(content);
    auto jsonc = json::parsec(content);
    if (!strict && !jsonc) {
        return -1;
    }

    if (strict) {
        (void)strict->to_string();
        (void)strict->format();
    }
    if (jsonc) {
        (void)jsonc->to_string();
    }
    return 0;
}
