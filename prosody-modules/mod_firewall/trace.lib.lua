local async = require "prosody.util.async";

local tracers = {};

local trace_mt = {
	__close = function (t)
		for session, options in pairs(tracers) do
			if not options.tag or options.tag == (t.tag or "untagged") then
				session.print(("\n## Evaluating [%s::%s] (%s)"):format(t.filename, t.chain, t.tag or "untagged"));
				local stanza_log = options.stanzas;
				if stanza_log == "full" then
					session.print(t.stanza);
				elseif not stanza_log or stanza_log == "header" then
					session.print(t.stanza:top_tag());
				end

				for rule_n, rule_trace in ipairs(t.rules) do
					local source = t.source[rule_n].source;
					for cond_n, matched in ipairs(rule_trace) do
						session.print(
							("%s %s"):format(
								matched and "✔" or "✖",
								source.conditions[cond_n] or ("Rule %d condition %d"):format(rule_n, cond_n)
							)
						);
					end
					if rule_trace.matched then
						for _, action in ipairs(source.actions) do
							session.print("➜ "..action);
						end
					end
				end
			end
		end
	end;
};

local function init(filename, chain_name, stanza, tag, source_rules)
	local rule_trace = {};
	local trace = setmetatable({
		filename = filename;
		chain = chain_name;
		rules = rule_trace;
		stanza = stanza;
		tag = tag;
		source = source_rules;
	}, trace_mt);
	return trace, function (rule_n, cond_n, result)
		local rule = rule_trace[rule_n];
		if not rule then
			rule = {};
			rule_trace[rule_n] = rule;
		end

		if cond_n then
			rule[cond_n] = result;
			return result;
		else
			-- Rule finished
			rule.matched = result;
		end
	end;
end


module:add_item("shell-command", {
	section = "firewall";
	section_desc = "mod_firewall commands";
	name = "trace";
	desc = "Trace executions";
	args = {
		{ name = "host", type = "string" };
	};
	host_selector = "host";
	flags = {
		short_params = { t = "tag" };
		value_params = { tag = true, stanzas = true };
	};
	handler = function(self, host, opts) --luacheck: ignore 212/self 212/host
		self.session.print("# Tracing mod_firewall on "..host);
		tracers[self.session] = opts or {};

		while self.session.is_connected() do
			async.sleep(3);
		end

		tracers[self.session] = nil;
		return true;
	end;
});


return { init = init };
