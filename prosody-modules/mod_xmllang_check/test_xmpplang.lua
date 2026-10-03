#!/usr/bin/env lua
-- Test suite for xmpplang.lib.lua parser

local script_dir = arg and arg[0] and arg[0]:match("^(.*)/[^/]+$") or ".";
package.path = script_dir .. "/?.lib.lua;" .. package.path;

local match_xmpplang = require("xmpplang")

local passed = 0
local failed = 0

local function test(input, expected, description)
    local result = match_xmpplang(input)
    if result == expected then
        passed = passed + 1
        print(string.format("PASS: %s (%s) -> %s", description, input, tostring(result)))
    else
        failed = failed + 1
        print(string.format("FAIL: %s (%s) -> expected %s, got %s", description, input, tostring(expected), tostring(result)))
    end
end

print("=== Basic language tags ===")
test("en", true, "2-letter language")
test("eng", true, "3-letter language")
test("abcd", true, "4-letter language")
test("abcde", true, "5-letter language")
test("abcdefgh", true, "8-letter language")
test("abcdefghi", false, "9-letter language (invalid)")
test("e", false, "1-letter language (invalid)")

print("\n=== Language with script ===")
test("en-Latn", true, "language-script")
test("zh-Hans", true, "zh-Hans")
test("zh-Hant", true, "zh-Hant")
test("en-Latn-US", true, "language-script-region")

print("\n=== Language with region ===")
test("en-US", true, "language-region (2 alpha)")
test("en-GB", true, "en-GB")
test("en-123", true, "language-region (3 digit)")
-- Note: en-1234 is valid because 1234 matches variant (digit + 3 alphanum)
test("en-1234", true, "en-1234 (parsed as language + variant)")
-- Note: en-ABC is valid because ABC matches extlang (3 alpha)
test("en-ABC", true, "en-ABC (parsed as language + extlang)")
-- Actually invalid subtags
test("en-AB", true, "en-AB (language + region)")
test("en-A", false, "en-A (single alpha - invalid)")
test("en-12", false, "en-12 (2 digits - invalid)")
test("en-ABCDE", true, "en-ABCDE (language + 5 alpha variant)")

print("\n=== Language with extlang ===")
test("zh-cmn", true, "language-extlang")
test("zh-cmn-Hans", true, "language-extlang-script")
test("zh-cmn-Hant-HK", true, "language-extlang-script-region")
test("zh-yue", true, "zh-yue")
test("zh-cmn-yue", true, "language-extlang-extlang")
test("zh-cmn-yue-gan", true, "language-extlang-extlang-extlang (max)")
test("zh-cmn-yue-gan-hak", false, "4 extlangs (too many)")

print("\n=== Variants ===")
test("en-US-12345", true, "5-char variant")
test("en-US-12345678", true, "8-char variant")
test("en-US-1abc", true, "digit+3alphanum variant")
test("en-US-rozaj", true, "rozaj variant")
test("sl-IT-nedis", true, "sl-IT-nedis")
test("en-US-abcd", false, "4-char alpha variant (invalid)")
test("en-US-123456789", false, "9-char variant (invalid)")

print("\n=== Extensions ===")
test("en-a-bbb", true, "extension a")
test("en-a-bbb-ccc", true, "extension with multiple subtags")
test("en-US-a-bbb", true, "language-region-extension")
test("en-US-a-bbb-b-ccc", true, "multiple extensions")
test("en-u-co-phonebk", true, "unicode extension")
test("en-a-b", false, "extension subtag too short")
test("en-a-bbbbbbbbb", false, "extension subtag too long (9)")

print("\n=== Privateuse ===")
test("x-private", true, "privateuse standalone")
test("x-a", true, "privateuse single char subtag")
test("x-abcdefgh", true, "privateuse 8-char subtag")
test("x-abc-def", true, "privateuse multiple subtags")
test("en-x-private", true, "language-privateuse")
test("en-US-x-private", true, "language-region-privateuse")
test("X-private", true, "uppercase X privateuse")
test("x-abcdefghi", false, "privateuse subtag too long (9)")

print("\n=== Grandfathered irregular ===")
test("en-GB-oed", true, "en-GB-oed")
test("i-ami", true, "i-ami")
test("i-bnn", true, "i-bnn")
test("i-default", true, "i-default")
test("i-enochian", true, "i-enochian")
test("i-hak", true, "i-hak")
test("i-klingon", true, "i-klingon")
test("i-lux", true, "i-lux")
test("i-mingo", true, "i-mingo")
test("i-navajo", true, "i-navajo")
test("i-pwn", true, "i-pwn")
test("i-tao", true, "i-tao")
test("i-tay", true, "i-tay")
test("i-tsu", true, "i-tsu")
test("sgn-BE-FR", true, "sgn-BE-FR")
test("sgn-BE-NL", true, "sgn-BE-NL")
test("sgn-CH-DE", true, "sgn-CH-DE")
-- Case insensitive
test("I-AMI", true, "I-AMI (uppercase)")
test("En-Gb-Oed", true, "En-Gb-Oed (mixed case)")

print("\n=== Grandfathered regular ===")
test("art-lojban", true, "art-lojban")
test("cel-gaulish", true, "cel-gaulish")
test("no-bok", true, "no-bok")
test("no-nyn", true, "no-nyn")
test("zh-guoyu", true, "zh-guoyu")
test("zh-hakka", true, "zh-hakka")
test("zh-min", true, "zh-min")
test("zh-min-nan", true, "zh-min-nan")
test("zh-xiang", true, "zh-xiang")
-- Case insensitive
test("ZH-MIN", true, "ZH-MIN (uppercase)")
test("Art-Lojban", true, "Art-Lojban (mixed case)")

print("\n=== Encoding ===")
test("en.UTF-8", true, "language with encoding")
test("en-US.UTF-8", true, "language-region with encoding")
test("en-Latn-US.UTF-8", true, "language-script-region with encoding")
test("en.utf-8", true, "encoding lowercase")
test("en.Utf-8", true, "encoding mixed case")
test("en.UTF-16", false, "invalid encoding")

print("\n=== Complex valid tags ===")
test("zh-cmn-Hans-CN", true, "zh-cmn-Hans-CN")
test("sr-Latn-RS", true, "sr-Latn-RS")
test("sl-rozaj-biske", true, "sl-rozaj-biske (multiple variants)")
test("de-CH-1901", true, "de-CH-1901")
test("en-US-u-islamcal", true, "en-US-u-islamcal")
test("zh-Hans-CN-u-nu-hanidec", true, "complex with extension")

print("\n=== Invalid cases ===")
test("", false, "empty string")
test("-en", false, "leading hyphen")
test("en-", false, "trailing hyphen")
test("en--US", false, "double hyphen")
test("123", false, "numeric only")
test("en_US", false, "underscore separator")
test("en US", false, "space separator")
test("toolonglanguage", false, "language too long")

print("\n=== Edge cases ===")
test("qaa", true, "qaa (reserved)")
test("qaa-Qaaa-QM-x-southern", true, "all private use subtags")
test("en-Latn-GB-boont-r-extended-sequence-x-private", true, "complex tag")

print("\n=== Additional edge cases ===")
-- Encoding edge cases
test("en.UTF-8extra", false, "encoding with extra chars")
test("en.UTF", false, "partial encoding")
test("en.", false, "dot with nothing after")
test("en-US.UTF-8.extra", false, "double dot")

-- Extension boundary cases
test("en-0-abc", true, "extension with digit singleton")
test("en-9-abc", true, "extension with digit 9 singleton")
test("en-a-12", true, "extension with 2 char subtag")
test("en-a-12345678", true, "extension with 8 char subtag")
test("en-a-ab-cd-ef", true, "extension with multiple short subtags")

-- Privateuse boundary cases
test("x-1", true, "privateuse with single digit")
test("x-12345678", true, "privateuse with 8 chars")
test("x-a-b-c-d-e", true, "privateuse with many 1-char subtags")

-- Language boundary cases (no extlang possible after 4+ alpha language)
-- These are invalid because 3-alpha "ext" doesn't match script/region/variant/etc.
test("abcd-ext", false, "4-letter language with 3-char subtag (invalid)")
test("abcde-ext", false, "5-letter language with 3-char subtag (invalid)")

-- Grandfathered should not be prefix-matched
test("i-ami-extra", false, "grandfathered with extra (invalid)")
-- Note: zh-min-foo is valid as langtag (foo is second extlang in zh-min-foo)
test("zh-min-foo", true, "zh-min-foo (valid: language + extlang + extlang)")

-- Variants cannot repeat in a way that produces invalid structure
test("en-rozaj-rozaj", true, "repeated variant (syntactically valid)")

-- Script + region + variant combinations
test("en-Latn-US-rozaj", true, "all optional components")
test("en-US-Latn", false, "region before script (invalid order)")

print(string.format("\n=== Results: %d passed, %d failed ===", passed, failed))
if failed > 0 then
    os.exit(1)
end
