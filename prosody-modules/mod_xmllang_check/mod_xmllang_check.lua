-- Strip invalid xml:lang values from outgoing s2s stanzas.
--
-- xmpplang.lib.lua must return a function that validates xml:lang strings.
local is_valid_xml_lang = module:require "xmpplang";

local function strip_invalid_xml_lang(element)
	local xml_lang = element.attr["xml:lang"];
	if xml_lang ~= nil and not is_valid_xml_lang(xml_lang, element) then
		element.attr["xml:lang"] = nil;
	end

	for child in element:childtags() do
		strip_invalid_xml_lang(child);
	end
end

module:hook("route/remote", function (event)
	-- FIXME should we clone the stanza vs modifying in place?
	-- FIXME should we replace recursively vs checking a specific subset of elements?
	-- FIXME instead of outgoing, should we clean incoming stanzas from everywhere, so invalid xml:lang stanzas are never sent or stored?
	strip_invalid_xml_lang(event.stanza);
end, 500);
