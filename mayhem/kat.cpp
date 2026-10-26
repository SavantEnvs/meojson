// Known-answer probe for mayhem/test.sh: parses fixed documents and prints computed values.
#include <iostream>

#include "json.hpp"

int main()
{
    auto ret = json::parse(R"({"a":[1,2,{"b":"cé"}],"d":true,"e":null,"f":-12.5})");
    if (!ret) {
        std::cout << "parse-failed\n";
        return 1;
    }
    auto& v = *ret;
    std::cout << "b=" << v["a"][2]["b"].as_string() << "\n";
    std::cout << "a1=" << v["a"][1].as_integer() << "\n";
    std::cout << "d=" << v["d"].as_boolean() << "\n";
    std::cout << "size=" << v["a"].as_array().size() << "\n";
    std::cout << "f=" << v["f"].as_double() << "\n";
    std::cout << "dump=" << v.to_string() << "\n";

    auto c = json::parsec("{/*x*/\"k\": [1, 2,], // y\n\"z\": \"s\"}");
    std::cout << "jsonc=" << (c ? c->to_string() : std::string("none")) << "\n";
    std::cout << "bad=" << (json::parse("{\"k\": [1, 2}") ? "accepted" : "rejected") << "\n";
    return 0;
}
