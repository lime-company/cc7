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

#include <cc7/Base32.h>

namespace cc7
{
	// MARK: - Encode
	
	/*
	 Sequence of 5 bytes mapped to 8 characters:
	 
	  01234567 01234567 01234567 01234567 01234567
	 +--------+--------+--------+--------+--------+
	 |< 0 >< 1| >< 2 ><|.3 >< 4.|>< 5 ><.|6 >< 7 >|
	 +--------+--------+--------+--------+--------+
	 */
	
	/**
	 The encoding table, which maps digit to the character.
	 */
	static char s_encoding_table[32] =
	{
		'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
		'Q','R','S','T','U','V','W','X','Y','Z','2','3','4','5','6','7'
	};
	
	/// Constant for padding character.
	static const char s_padding = '=';
	
	/*
	 The main encode function.
	 */
	bool Base32_Encode(const ByteRange & bytes, bool use_padding, std::string & out_string)
	{
		out_string.clear();
		out_string.reserve((bytes.length() * 8 + 4) / 5);
		
		size_t index = 0, append = 0;
		U16 curr_byte, digit;
		char buffer[8];
		
		while (index < bytes.size()) {
			// insert 5 new bits, leave 3 bits
			curr_byte = bytes[index++];
			buffer[0] = s_encoding_table[curr_byte >> 3];
			digit = (curr_byte & 7) << 2;
			if (index >= bytes.size()) {
				buffer[1] = s_encoding_table[digit];
				append = 2;
				break;
			}
			// Insert 2 new bits, then 5 bits, leave 1 bit
			curr_byte = bytes[index++];
			buffer[1] = s_encoding_table[digit | (curr_byte >> 6)];
			buffer[2] = s_encoding_table[(curr_byte >> 1) & 31];
			digit = (curr_byte & 1) << 4;
			if (index >= bytes.size()) {
				buffer[3] = s_encoding_table[digit];
				append = 4;
				break;
			}
			// Insert 4 new bits, leave 4 bits
			curr_byte = bytes[index++];
			buffer[3] = s_encoding_table[digit | (curr_byte >> 4)];
			digit = (curr_byte & 15) << 1;
			if (index >= bytes.size()) {
				buffer[4] = s_encoding_table[digit];
				append = 5;
				break;
			}
			// Inser 1 new bit, then 5 bits, leave 2 bits
			curr_byte = bytes[index++];
			buffer[4] = s_encoding_table[digit | (curr_byte >> 7)];
			buffer[5] = s_encoding_table[(curr_byte >> 2) & 31];
			digit = (curr_byte & 3) << 3;
			if (index >= bytes.size()) {
				buffer[6] = s_encoding_table[digit];
				append = 7;
				break;
			}
			// Last, insert 3 new bits, then 5 bits, leave nothing.
			curr_byte = bytes[index++];
			buffer[6] = s_encoding_table[digit | (curr_byte >> 5)];
			buffer[7] = s_encoding_table[curr_byte & 31];
			// Now append the whole buffer and reset "append" marker
			out_string.append(buffer, 8);
			append = 0;
		}
		
		// If append is greater than 0, then there's remaining string in buffer
		// which has to be appended to the output. That also means that padding
		// is required.
		if (append > 0) {
			out_string.append(buffer, append);
			if (use_padding) {
				out_string.append(8 - append, s_padding);
			}
		}
		return true;
	}
	
	// MARK: - Decode
	
	/// Constnat returned from `_CharToDigit()` in case of invalid character.
	static const U8 s_invalid = 0xFF;
	
	/*
	 The private function converts input character into 5 bit digit (0..31). If the character
	 is not from Base32 characters, then returns |s_invalid| constant.
	 */
	static U8 _CharToDigit(char c)
	{
		if (c >= 'A' && c <= 'Z') {
			return c - 'A';			// 0 .. 25
		}
		if (c >= '2' && c <= '7') {
			return c - '2' + 26;	// 26 .. 31
		}
		return s_invalid;
	}
	
	/*
	 The private helper function validates whether the length of the string & padding meets criteria
	 for the Base32 string. Returns pair of bool & size_t parameters, where the |bool| means that
	 input string is valid and |size_t| is the the new, reduced size of input string,
	 without the padding characters.
	 */
	static std::tuple<bool, size_t> _ValidatePadding(const std::string & string, bool required)
	{
		size_t new_size = string.size();
		size_t remainder = new_size % 8;
		if (required) {
			if (remainder != 0) {
				// Invalid lenght of input string. Must be: (lenght mod 8) == 0
				return std::make_tuple(false, 0);
			}
			// Count number of padding characters at the end of the string.
			auto it = string.rbegin();
			size_t padding_count = 0;
			while (it != string.rend()) {
				if (*it != s_padding || padding_count > 7) {
					break;
				}
				++it;
				++padding_count;
			}
			if (padding_count > 7) {
				return std::make_tuple(false, 0);
			}
			// Adjust size & remainder
			new_size -= padding_count;
			remainder = new_size % 8;
		}
		
		// The (length mod 8) must not be 1, 3 or 6
		if (remainder == 1 || remainder == 3 || remainder == 6) {
			return std::make_tuple(false, 0);
		}
		
		return std::make_tuple(true, new_size);
	}
	
	/*
	 The main decode function.
	 */
	bool Base32_Decode(const std::string & in_string, bool require_padding, ByteArray & out_bytes)
	{
		bool valid;
		size_t count;
		std::tie(valid, count) = _ValidatePadding(in_string, require_padding);
		if (!valid) {
			return false;
		}
		
		// Prepare output byte array.
		out_bytes.clear();
		out_bytes.reserve(count * 5 / 8);
		
		U8 next_byte, digit;
		size_t index = 0, append = 0;
		U8 buffer[8];
		
		while (index < count) {
			// Read 1st character
			if ((digit = _CharToDigit(in_string[index++])) == s_invalid) {
				return false;
			}
			next_byte = digit << 3;
			// Read 2nd character
			if ((digit = _CharToDigit(in_string[index++])) == s_invalid) {
				return false;
			}
			//  store 1st byte, keep 2 bits
			buffer[0] = next_byte | (digit >> 2);
			next_byte = digit << 6;
			// Check end of string
			if (index >= count) {
				if (next_byte == 0) {
					append = 1;	// ignore remaining zero bits, append 1 byte
					break;
				}
				return false;	// non-cannonical end
			}
			// Read 3rd character, keep 7 bits
			if ((digit = _CharToDigit(in_string[index++])) == s_invalid) {
				return false;
			}
			next_byte |= digit << 1;	// keep all 5 bits from digit
			// Read 4th character
			if ((digit = _CharToDigit(in_string[index++])) == s_invalid) {
				return false;
			}
			// store 2nd byte, keep 4 bits
			buffer[1] = next_byte | digit >> 4;
			next_byte = (digit & 15) << 4;
			// Check end of string
			if (index >= count) {
				if (next_byte == 0) {
					append = 2;	// ignore remaining zero bits, append 2 bytes
					break;
				}
				return false;	// non-cannonical end
			}
			// Read 5th character
			if ((digit = _CharToDigit(in_string[index++])) == s_invalid) {
				return false;
			}
			// Store 3rd byte, keep 1 bit
			buffer[2] = next_byte | (digit >> 1);
			next_byte = (digit & 1) << 7;
			// Check end of string
			if (index >= count) {
				if (next_byte == 0) {
					append = 3;	// ignore remaining zero bits, append 3 bytes
					break;
				}
				return false;	// non-cannonical end
			}
			// Read 6th character
			if ((digit = _CharToDigit(in_string[index++])) == s_invalid) {
				return false;
			}
			next_byte |= digit << 2;
			// Read 7th character
			if ((digit = _CharToDigit(in_string[index++])) == s_invalid) {
				return false;
			}
			buffer[3] = next_byte | (digit >> 3);
			next_byte = digit << 5;
			if (index >= count) {
				if (next_byte == 0) {
					append = 4;	// ignore remaining zero bits, append 4 bytes
					break;
				}
				return false;	// non-cannonical end
			}
			// Read 8th character
			if ((digit = _CharToDigit(in_string[index++])) == s_invalid) {
				return false;
			}
			buffer[4] = next_byte | digit;
			// Now append the whole buffer & reset the append marker.
			out_bytes.append(buffer, 5);
			append = 0;
		}
		// Everything looks OK.
		// Append remained bytes & return true.
		if (append > 0) {
			out_bytes.append(buffer, append);
		}
		return true;
	}
	
} // cc7
