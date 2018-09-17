/**
 * Copyright 2018 Wultra s.r.o.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#pragma once

#include <cc7/ByteArray.h>

namespace cc7
{
	/**
	 Converts input byte range ino Base32 encoded string. The |use_padding| parameter
	 determines whether the output string will contain padding characted '='.
	 The function always returns true.
	 */
	bool Base32_Encode(const ByteRange & bytes, bool use_padding, std::string & out_string);

	/**
	 Converts Base32 encoded string into ByteArray. If the |require_padding| parameter is true,
	 then the padding '=' characters must be present at the end of string (if size doesn't fit the base32
	 encoded string block).
	 
	 Returns false if the string is not a valid Base32 string.
	 
	 Note that unlike the other Base32 implementations, this decoder threats invalid characters in the string
	 as an error.
	 */
	bool Base32_Decode(const std::string & in_string, bool require_padding, ByteArray & out_bytes);
	
	/**
	 Converts input byte range into Base32 encoded string. This is just the convenient function to Base32_Encode().
	 */
	inline std::string ToBase32String(const ByteRange & data, bool use_padding)
	{
		std::string result;
		Base32_Encode(data, use_padding, result);
		return result;
	}
	
	/**
	 Converts Base32 encoded string into ByteArray. This variant of decoding function may be
	 easier to use, but unlike the Base32_Decode(), you are not able to determine whether
	 the error occured or not.
	 */
	inline ByteArray FromBase32String(const std::string & string, bool require_padding)
	{
		ByteArray result;
		Base32_Decode(string, require_padding, result);
		return result;
	}
	
} // cc7
