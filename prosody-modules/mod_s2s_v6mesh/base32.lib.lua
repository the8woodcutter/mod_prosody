--[[
 borrowed from basexx library for Lua, under MIT License (MIT)
 Copyright (c) 2013 aiq
The MIT License (MIT)

Copyright (c) 2013 aiq

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
----------------------------------------------------------------------------]]

local function ignore_set( str, set )
   if set then
      str = str:gsub( "["..set.."]", "" )
   end
   return str
end

local function divide_string( str, max )
   local result = {}

   local start = 1
   for i = 1, #str do
      if i % max == 0 then
         table.insert( result, str:sub( start, i ) )
         start = i + 1
      elseif i == #str then
         table.insert( result, str:sub( start, i ) )
      end
   end

   return result
end

function to_bit( str )
   return ( str:gsub( '.', function ( c )
               local byte = string.byte( c )
               local bits = {}
               for _ = 1,8 do
                  table.insert( bits, byte % 2 )
                  byte = math.floor( byte / 2 )
               end
               return table.concat( bits ):reverse()
            end ) )
end

local function number_to_bit( num, length )
   local bits = {}

   while num > 0 do
      local rest = math.floor( math.fmod( num, 2 ) )
      table.insert( bits, rest )
      num = ( num - rest ) / 2
   end

   while #bits < length do
      table.insert( bits, "0" )
   end

   return string.reverse( table.concat( bits ) )
end

local function pure_from_bit( str )
   return ( str:gsub( '........', function ( cc )
               return string.char( tonumber( cc, 2 ) )
            end ) )
end

local function unexpected_char_error( str, pos )
   local c = string.sub( str, pos, pos )
   return string.format( "unexpected character at position %d: '%s'", pos, c )
end

local function from_basexx( str, alphabet, bits )
   local result = {}
   for i = 1, #str do
      local c = string.sub( str, i, i )
      if c ~= '=' then
         local index = string.find( alphabet, c, 1, true )
         if not index then
            return nil, unexpected_char_error( str, i )
         end
         table.insert( result, number_to_bit( index - 1, bits ) )
      end
   end

   local value = table.concat( result )
   local pad = #value % 8
   return pure_from_bit( string.sub( value, 1, #value - pad ) )
end

local function to_basexx( str, alphabet, bits, pad )
   local bitString = to_bit( str )

   local chunks = divide_string( bitString, bits )
   local result = {}
   for _,value in ipairs( chunks ) do
      if ( #value < bits ) then
         value = value .. string.rep( '0', bits - #value )
      end
      local pos = tonumber( value, 2 ) + 1
      table.insert( result, alphabet:sub( pos, pos ) )
   end

   table.insert( result, pad )
   return table.concat( result )
end

local base32Alphabet = "abcdefghijklmnopqrstuvwxyz234567"
local base32PadMap = { "", "======", "====", "===", "=" }

local function from_base32( str, ignore )
   str = ignore_set( str, ignore )
   return from_basexx( string.lower( str ), base32Alphabet, 5 )
end

function to_base32( str )
   return to_basexx( str, base32Alphabet, 5, base32PadMap[ #str % 5 + 1 ] )
end

return {
	decode = from_base32;
	encode = to_base32;
};
