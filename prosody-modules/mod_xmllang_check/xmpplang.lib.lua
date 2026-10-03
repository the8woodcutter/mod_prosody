

local irregular = {
  "en-GB-oed", "i-ami", "i-bnn", "i-default", "i-enochian", "i-hak", "i-klingon", "i-lux", "i-mingo", "i-navajo", "i-pwn", "i-tao", "i-tay", "i-tsu", "sgn-BE-FR", "sgn-BE-NL", "sgn-CH-DE"
};
local regular = {
  "art-lojban", "cel-gaulish", "no-bok", "no-nyn", "zh-guoyu", "zh-hakka", "zh-min", "zh-min-nan", "zh-xiang"
};
local grandfathered = {};
for _, tag in ipairs(irregular) do
  grandfathered[tag:lower()] = true;
end
for _, tag in ipairs(regular) do
  grandfathered[tag:lower()] = true;
end

local function split_subtags(lower_s)
  local subtags = {};
  for subtag in lower_s:gmatch("[^%-]+") do -- split on hyphens
    table.insert(subtags, subtag);
  end
  return subtags;
end

local function is_privateuse(lower_s)
  if lower_s:sub(1, 2) ~= "x-" then
    -- print("privateuse: " .. lower_s .. " does not start with x-");
    return false;
  end

  -- only allow alphanum and hyphens from here on out
  if lower_s:match("[^a-z0-9%-]") then
    -- print("privateuse: " .. lower_s .. " contains non-alphanum or hyphen");
    return false;
  end
  -- lets not allow any zero-len subtags
  if lower_s:match("^%-") or lower_s:match("%-$") or lower_s:match("%-%-") then
    -- print("privateuse: " .. lower_s .. " contains zero-len subtags");
    return false;
  end

  local subtags = split_subtags(lower_s);
  -- print("privateuse subtags: " .. table.concat(subtags, "|"));
  if #subtags < 2 then return false; end
  for i = 1, #subtags do
    if #subtags[i] < 1 or #subtags[i] > 8 or not subtags[i]:match("^[a-z0-9]+$") then return false; end
  end
  -- print("privateuse: " .. lower_s .. " is valid");
  return true;
end

local function is_langtag(lower_s)
  -- print("is_langtag: " .. lower_s);
  -- print(" lower_s:sub(-5): ".. lower_s:sub(-5))
  -- Remove the optional .utf8 suffix if it exists
  if lower_s:sub(-6) == ".utf-8" then
    -- print("removing .utf-8 suffix");
    lower_s = lower_s:sub(1, -7);
  end

  -- at this point we have a hyphen-separated string of subtags, where subtags are alphanumeric

  -- only allow alphanum and hyphens from here on out
  if lower_s:match("[^a-z0-9%-]") then
    return false;
  end
  -- lets not allow any zero-len subtags
  if lower_s:match("^%-") or lower_s:match("%-$") or lower_s:match("%-%-") then
    return false;
  end

  -- let's split on hyphens
  local subtags = split_subtags(lower_s);

  -- we are now dealing with this pattern: language ( "-" script )? ( "-" region )? ( "-" variant )* ( "-" extension )*
  -- we'll now process in order

  -- Let's process "language"
  -- print("processing language: " .. table.concat(subtags, "|"));
  local subtag = table.remove(subtags, 1);
  if not subtag or not subtag:match("^[a-z]+$") then
    return false;
  end
  if #subtag == 2 or #subtag == 3 then
    -- we want to check for 0-3 instances of three-letter tags
    for i = 1, 3 do
      local subtag = subtags[1];
      if subtag and #subtag == 3 and subtag:match("^[a-z]+$") then
        table.remove(subtags, 1);
      end
    end
  elseif #subtag >= 4 and #subtag <= 8 then
    -- passthrough
  else
    return false;
  end

  -- Let's process optional: script = ALPHA{4};
  -- print("processing script: " .. table.concat(subtags, "|"));
  subtag = subtags[1];
  if subtag and #subtag == 4 and subtag:match("^[a-z]+$") then
    table.remove(subtags, 1);
  end

  -- Let's process optional: region = ALPHA{2} | DIGIT{3};
  -- print("processing region: " .. table.concat(subtags, "|"));
  subtag = subtags[1];
  if subtag and ((#subtag == 2 and subtag:match("^[a-z][a-z]$")) or (#subtag == 3 and subtag:match("^[0-9][0-9][0-9]$"))) then
    table.remove(subtags, 1);
  end

  -- Let's process zero or more: variant = alphanum{5,8} | ( DIGIT alphanum{3} );
  while true do
    local variant = subtags[1];
    if not variant or (#variant < 4 or #variant > 8) then
      break;
    end
    if #variant == 4 and not variant:match("^[0-9]") then return false; end
    table.remove(subtags, 1);
  end

  -- print("processing extensions: " .. table.concat(subtags, "|"));
  -- Let's process zero or more: extension = singleton ( "-" alphanum{2,8} )+;
  while true do
    local extension = subtags[1];
    if not extension or extension == "x" then break; end
    if #extension ~= 1 then return false; end
    table.remove(subtags, 1);

    local part = subtags[1];
    if not part or (#part < 2 or #part > 8) then return false; end
    table.remove(subtags, 1);

    while true do
      part = subtags[1];
      if not part or (#part < 2 or #part > 8) then break; end
      table.remove(subtags, 1);
    end
  end

  -- print("processing privateuse: " .. table.concat(subtags, "|"));
  -- Let's process optional: privateuse = "x"i ( "-" alphanum{1,8} )+;
  local privateuse = table.remove(subtags, 1);
  -- print("privateuse: " .. privateuse);
  if privateuse then
    if privateuse ~= "x" or #subtags < 1 then return false; end
    for i = 1, #subtags do
      local part = subtags[i];
      if #part < 1 or #part > 8 then return false; end
    end
  end

  return true;
end

local function is_xmpplang(s)
  local lower_s = s:lower();
  if grandfathered[lower_s] then
    return true;
  end
  -- print("checking privateuse: " .. lower_s);
  if is_privateuse(lower_s) then
    -- print("privateuse: " .. lower_s .. " is valid");
    return true;
  end
  -- print("checking langtag: " .. lower_s);
  if is_langtag(lower_s) then
    return true;
  end
  return false;
end

-- print("=== x-abc-def")
-- print(is_xmpplang("x-abc-def"));
-- print("=== x-a-b-c-d-e")
-- print(is_xmpplang("x-a-b-c-d-e"));

return is_xmpplang;
