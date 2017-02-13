/*
 * Copyright 2016 Juraj Durech <durech.juraj@gmail.com>
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

#include <cc7/detail/ExceptionsWrapper.h>

namespace cc7
{
	/**
	 The ByteRange class is keeping a pair of pointers defining a
	 continuous range of immutable bytes in the memory. You can modify
	 the range during the object lifetime, but you cannot modify 
	 the referenced data.
	 
	 Keep the referenced memory lifetime in mind when using this class.
	 The ByteRange doesn't manage the data it refers to, just like
	 an iterator wouldn't.
	 */
	class ByteRange
	{
	public:
		
		// STL compatibility
		
		// TODO: make tests for interoperability with STL algorithms.
		
		typedef cc7::byte			value_type;
		typedef cc7::byte*			pointer;
		typedef const cc7::byte*	const_pointer;
		typedef const cc7::byte&	reference;
		typedef const cc7::byte&	const_reference;
		typedef size_t				size_type;
		typedef ptrdiff_t			difference_type;
		typedef cc7::byte*			iterator;
		typedef const cc7::byte*	const_iterator;		
		typedef std::reverse_iterator<const_iterator>	const_reverse_iterator;
		typedef std::reverse_iterator<iterator>			reverse_iterator;
		
		static const size_type	npos = static_cast<size_type>(-1);
		
	private:
		
		// Helper types for exception handling
		typedef cc7::detail::ExceptionsWrapper<value_type> _ValueTypeExceptions;
		typedef cc7::detail::ExceptionsWrapper<ByteRange>  _ByteRangeExceptions;
		
		// Private members
		const_pointer _begin;
		const_pointer _end;
		
	public:
		
		//
		// Constructors
		//
		
		/**
		 Constructs an empty byte range.
		 */
		ByteRange() noexcept :
			_begin (nullptr),
			_end   (nullptr)
		{
		}
		
		/**
		 Constructs a byte range pointing to memory at |ptr| which is |size|
		 bytes long. If |ptr| is null then the empty range is constructed.
		 */
		explicit ByteRange(const_pointer ptr, size_type size) noexcept :
			_begin (ptr),
			_end   (ptr != nullptr ? ptr + size : 0)
		{
		}
		
		/**
		 Constructs a byte range pointing to memory located between the |begin| and |end|
		 pointers. If both pointers are null then the empty range is created. The constructor
		 throws an exception if an invalid range is provided (e.g. |begin| is greater than |end|
		 or if one of the pointers is null)
		 */
		explicit ByteRange(const_pointer begin, const_pointer end) :
			_begin (begin),
			_end   (end)
		{
			_validateBeginEnd(begin, end);
		}
		
		/**
		 Constructs a byte range pointing to memory located between the |begin| and |end|
		 iterators. The constructor throws an exception if an invalid range is provided 
		 (e.g. |begin| is greater than |end| or if one of the iterators is null)
		 */
		template <class _Iterator>
		ByteRange(_Iterator begin, _Iterator end) :
			_begin	(&(*begin)),
			_end	(&(*end))
		{
			static_assert(std::is_same<
							std::random_access_iterator_tag,
							typename std::iterator_traits<_Iterator>::iterator_category
						  >::value, "This constructor only accepts random access iterators or raw pointers.");
			_validateBeginEnd(_begin, _end);
		}
		
		/**
		 Constructs a byte range from another ByteRange object |r|.
		 */
		ByteRange(const ByteRange & r) noexcept :
			_begin (r.begin()),
			_end   (r.end())
		{
		}
		
		/**
		 Constructs a byte range pointing to memory at |ptr| which is |size|
		 bytes long. If |ptr| is null then the empty range is constructed.
		 */
		explicit ByteRange(const void * ptr, size_type size) noexcept :
			_begin (reinterpret_cast<const_pointer>(ptr)),
			_end   (_begin ? _begin + size : nullptr)
		{
		}
		
		/**
		 Constructs a byte range pointing to all characters stored in
		 the string |str|.
		 */
		explicit ByteRange(const std::string & str) noexcept :
			_begin (reinterpret_cast<const_pointer>(str.data())),
			_end   (reinterpret_cast<const_pointer>(str.data()) + str.length())
		{
		}
		
		/**
		 Constructs a byte range pointing to nul terminated string |c_str|.
		 If the |c_str| is null then the empty range is constructed.
		 */
		explicit ByteRange(const char * c_str) noexcept :
			_begin (reinterpret_cast<const_pointer>(c_str)),
			_end   (_begin ? _begin + strlen(c_str) : nullptr)
		{
		}
		
		//
		// assign methods
		//
		
		/**
		 Assigns a new byte range pointing to memory located between the |begin| and |end|
		 pointers. If both pointers are null then the empty range is assigned. The method
		 throws an exception if an invalid range is provided (e.g. |begin| is greater than |end|
		 or if one of the pointers is null)
		 */
		void assign(const_pointer begin, const_pointer end)
		{
			_validateBeginEnd(begin, end);
			_begin = begin;
			_end   = end;
		}
		
		/**
		 Assigns a new byte range pointing to memory at |ptr| which is |size|
		 bytes long. If |ptr| is null then the empty range is assigned.
		 */
		void assign(const_pointer ptr, size_type size) noexcept
		{
			_begin = ptr;
			_end   = _begin != nullptr ? (_begin + size) : nullptr;
		}
		
		/**
		 Assigns a new byte range from another ByteRange object |r|.
		 */
		void assign(const ByteRange & r) noexcept
		{
			_begin = r.begin();
			_end   = r.end();
		}
		
		/**
		 Assigns a new byte range pointing to memory at |ptr| which is |size|
		 bytes long. If |ptr| is null then the empty range is assigned.
		 */
		void assign(const void * ptr, size_type size) noexcept
		{
			_begin = reinterpret_cast<const_pointer>(ptr);
			_end   = _begin ? (_begin + size) : nullptr;
		}
		
		/**
		 Assigns a new byte range pointing to all characters stored in
		 the string |str|.
		 */
		void assign(const std::string & str) noexcept
		{
			_begin = reinterpret_cast<const_pointer>(str.data());
			_end   = _begin + str.size();
		}
		
		/**
		 Assigns a new byte range pointing to nul terminated string |c_str|.
		 If the |c_str| is null then the empty range is assigned.
		 */
		void assign(const char * c_str) noexcept
		{
			_begin = reinterpret_cast<const_pointer>(c_str);
			_end  = _begin ? (_begin + strlen(c_str)) : nullptr;
		}
		
		/**
		 Assigns a new byte range pointing to a string |c_str|
		 which is |size| characters long. If the |c_str| is null 
		 then the empty range is assigned.
		 */
		void assign(const char * c_str, size_type size) noexcept
		{
			_begin = reinterpret_cast<const_pointer>(c_str);
			_end   = _begin ? _begin + size : nullptr;
		}
		
		/**
		 Assigns a new byte range pointing to memory located between the |begin| and |end|
		 iterators. The constructor throws an exception if an invalid range is provided
		 (e.g. |begin| is greater than |end| or if one of the iterators is null)
		 */
		template <class _Iterator>
		void assign(_Iterator begin, _Iterator end)
		{
			static_assert(std::is_same<
							std::random_access_iterator_tag,
							typename std::iterator_traits<_Iterator>::iterator_category
						  >::value, "This assign() only accepts random access iterators or raw pointers.");
			_begin = &(*begin);
			_end   = &(*end);
			_validateBeginEnd(_begin, _end);
		}
		
		//
		// other methods
		//
		
		/**
		 Clears the begin and end internal pointers to null, leaving the byte range with a size of 0.
		 */
		void clear() noexcept
		{
			_begin = nullptr;
			_end   = nullptr;
		}
		
		/**
		 Returns a direct pointer to the first byte of the byte range. Note that the pointer
		 may be null if the range is empty.
		 */
		const_pointer data() const noexcept
		{
			return _begin;
		}
		
		/**
		 Returns the number of bytes in the range.
		 */
		size_type length() const noexcept
		{
			return _end - _begin;
		}

		/**
		 Returns the number of bytes in the range.
		 */
		size_type size() const noexcept
		{
			return _end - _begin;
		}

		/**
		 The method has equal function than size() and is declared
		 only to provide interface similar to std::vector<T>
		 */
		size_type capacity() const noexcept
		{
			return size();
		}
		
		/**
		 The method has equal function than size() and is declared
		 only to provide interface similar to std::vector<T>.
		 */
		size_type max_size() const noexcept
		{
			return size();
		}
		
		/**
		 Returns true whether the byte range is zero bytes long.
		 */
		bool empty() const noexcept
		{
			return _begin == _end;
		}
		
		//
		// Getting elements
		//
		
		/**
		 Returns a const reference to the byte at position |n| in the byte range.
		 The operator performs a boundary check and return reference to the safe 
		 byte if |n| is out of range. The safe byte may contain a garbage value.
		 */
		const_reference operator[](size_type n) const noexcept
		{
			if (n < size()) {
				return _begin[n];
			}
			// Accessing element which is out of range has undefined behavior in STL.
			// We can return reference to some static buffer.
			return _ValueTypeExceptions::forbidden_value();
		}
			
		/**
		 Returns a const reference to the byte at position |n| in the byte range.
		 If the |n| is out of bounds then throws an out of range exception.
		 */
		const_reference at(size_type n) const
		{
			if (n < size()) {
				return _begin[n];
			} else {
				return _ValueTypeExceptions::out_of_range();
			}
		}
		
		//
		// STL iterators
		//
		
		/**
		 Returns an const iterator pointing to the first byte in the byte range.
		 If the byte range is empty, the returned iterator value shall not be dereferenced.
		 */
		const_iterator begin() const
		{
			return cbegin();
		}

		/**
		 Returns an const iterator referring to the past-the-end byte in the byte range.
		 If the byte range is empty, the returned iterator value shall not be dereferenced.
		 */
		const_iterator end() const
		{
			return cend();
		}
		
		/**
		 Returns an const iterator pointing to the first byte in the byte range.
		 If the byte range is empty, the returned iterator value shall not be dereferenced.
		 */
		const_iterator cbegin() const
		{
			return _begin;
		}
		
		/**
		 Returns an const iterator referring to the past-the-end byte in the byte range.
		 If the byte range is empty, the returned iterator value shall not be dereferenced.
		 */
		const_iterator cend() const
		{
			return _end;
		}
		
		/**
		 Returns a const reverse iterator pointing to the last byte in the range (i.e., its
		 reverse beginning). If the byte range is empty, the returned iterator value 
		 shall not be dereferenced.
		 */
		const_reverse_iterator rbegin() const
		{
			return crbegin();
		}
		
		/**
		 Returns a const reverse iterator pointing to the theoretical byte preceding the first
		 byte in the range (which is considered its reverse end). If the byte range is empty, 
		 the returned iterator value shall not be dereferenced.
		 */
		const_reverse_iterator rend() const
		{
			return crend();
		}
		
		/**
		 Returns a const reverse iterator pointing to the last byte in the range (i.e., its
		 reverse beginning). If the byte range is empty, the returned iterator value
		 shall not be dereferenced.
		 */
		const_reverse_iterator crbegin() const
		{
			return const_reverse_iterator(_end);
		}
		
		/**
		 Returns a const reverse iterator pointing to the theoretical byte preceding the first
		 byte in the range (which is considered its reverse end). If the byte range is empty,
		 the returned iterator value shall not be dereferenced.
		 */
		const_reverse_iterator crend() const
		{
			return const_reverse_iterator(_end);
		}
		
		//
		// Conversions to string representation
		//
		
		/**
		 Returns a Base64 encoded string created from all bytes captured in the byte range.
		 If |wrap_size| is greater than 0, then the multiline string is returned (check 
		 Base64_Encode() for more details).
		 */
		std::string base64String(size_t wrap_size = 0) const;
		
		/**
		 Returns a hexadecimal string created from all bytes captured in the byte range.
		 If |lower_case| parameter is true then the produced string will contain lower
		 case letters only.
		 */
		std::string hexString(bool lower_case = false) const;
		
		//
		// Prefix / Suffix remove, SubRange
		//
		
		/**
		 Removes |count| bytes from the beginning of the range. If |count| is greater
		 than the size of the range, then throws an out of range exception.
		 */
		void removePrefix(size_t count)
		{
			if (count <= length()) {
				_begin += count;
			} else {
				_ValueTypeExceptions::out_of_range();
			}
		}

		/**
		 Removes |count| bytes from the end of the range. If |count| is greater
		 than the size of the range, then throws an out of range exception.
		 */
		void removeSuffix(size_t count)
		{
			if (count <= length()) {
				_end -= count;
			} else {
				_ValueTypeExceptions::out_of_range();
			}
		}
		
		/**
		 Returns a new sub-range started at |from| byte and continues to the end
		 of current range. If the requested sub-range doesn't fit to an actual
		 range, then the out_of_range exception is thrown.
		 */
		ByteRange subRangeFrom(size_type from) const
		{
			if (from <= size()) {
				return ByteRange(begin() + from, end());
			}
			return _ByteRangeExceptions::out_of_range();
		}
		
		/**
		 Returns a new sub-range started from the beginning of the current range
		 and is |to| bytes long. If the requested sub-range doesn't fit to an actual
		 range, then the out_of_range exception is thrown.
		 */
		ByteRange subRangeTo(size_type to) const
		{
			if (to <= size()) {
				return ByteRange(begin(), begin() + to);
			}
			return _ByteRangeExceptions::out_of_range();
		}
		
		/**
		 Returns a new sub-range started at |from| byte which is |count| bytes long.
		 If the requested sub-range doesn't fit to an actual range, then the out_of_range
		 exception is thrown.
		 */
		ByteRange subRange(size_type from, size_type count)
		{
			if ((from <= size()) && (from + count <= size())) {
				return ByteRange(begin() + from, count);
			}
			return _ByteRangeExceptions::out_of_range();
		}
		
		/**
		 Compares this byte array to |other|. First, calculates the number of bytes 
		 to compare, as min_size = std::min(size(), other.size()). Then compares bytes by calling
		 memcmp(data(), other.data(), min_size). If the result is zero (the memory regions are equal
		 so far), then the longer byte range is considered as greater. If the memcmp() result is
		 non-zero, then the returned value is normalized to 1 or -1.
		 
		 Returns:
			 0 - if both memory regions are equal
			 1 - if |other| is smaller
			-1 - if |other| is greater
		 */
		int compare(const ByteRange & other) const noexcept
		{
			const size_type ts = size();
			const size_type os = other.size();
			const size_type ms = std::min(ts, os);
			int res = memcmp(data(), other.data(), ms);
			if ((res == 0) && (os != ts)) {
				// Converts difference between other and this size to -1 or 1.
				res = (static_cast<int>(
						(os - ts) >> (8 * sizeof(size_type) - 1)) << 1	// 0 or 2, based on signed bit
					   ) - 1;											// -1 or 1
			}
			return res;
		}
		
	protected:
		
		/**
		 Validates provided pointers and throws invalid_argument exception, if
			- begin is greater than end, or if
			- begin is null and end is not null
		 This simple validation covers all possible invalid situations which may occur
		 during the ByteRange object usage. So, we basically have just several possible
		 combinations of the pointers:
		
		  -------------------------------------------------------------------
		 | begin     | end              | meaning                            |
		  ----------- ------------------ ------------------------------------
		 | null      | null             | range is valid, empty              |
		 | null      | not-null         | range is invalid                   |
		 | not-null  | equal to begin   | range is valid, empty              |
		 | not-null  | great than begin | range is valid, non empty          |
		 | not-null  | less. than begin | range is invalid                   |
		  ----------- ------------------ ------------------------------------
		 
		 ...everybody loves the tables :)
		 */
		void _validateBeginEnd(const_pointer begin, const_pointer end)
		{
			if ((begin > end) || (!begin && end)) {
				_ValueTypeExceptions::invalid_argument();
			}
		}
			
	};
	
	//
	// ByteRange comparation operators
	//
	// Compares the contents of a ByteRange with another ByteRange.
	// All comparisons are done via the compare() member function.
	//
	
	inline bool operator==(const ByteRange & x, const ByteRange & y)
	{
		return x.compare(y) == 0;
	}
	inline bool operator!=(const ByteRange & x, const ByteRange & y)
	{
		return x.compare(y) != 0;
	}
	inline bool operator< (const ByteRange & x, const ByteRange & y)
	{
		return x.compare(y) < 0;
	}
	inline bool operator> (const ByteRange & x, const ByteRange & y)
	{
		return x.compare(y) > 0;
	}
	inline bool operator>=(const ByteRange & x, const ByteRange & y)
	{
		return x.compare(y) >= 0;
	}
	inline bool operator<=(const ByteRange & x, const ByteRange & y)
	{
		return x.compare(y) <= 0;
	}
		
	/**
	 Copy conversion from ByteRange to the std::string object.
	 
	 This inline function returns a new instance of std::string object
	 which will be initialized with all bytes from the provided |range|
	 of bytes. The range of bytes are reinterpreted to characters, with
	 no additional conversion.
	 
	 This kind of function is typically useful in situations, when your 
	 code is interacting with an another library (or some vintage code) 
	 which is using std::string as a general data container. For example,
	 some protobuf implementations is doing this...
	 */
	inline std::string CopyToString(const ByteRange & range)
	{
		return std::string(reinterpret_cast<const char*>(range.data()), range.size());
	}
	
	/**
	 Creates a new ByteRange object from given string. All characters
	 from the string object excepts the NUL terminator, are reinterpreted as
	 bytes and captured in the returned range.
	 */
	inline ByteRange MakeRange(const std::string & str)
	{
		return ByteRange(str);
	}

	/**
	 Creates a new ByteRange object from given string. All characters
	 from the string pointer up to first NUL terminator, are captured
	 in the returned range.
	 */
	inline ByteRange MakeRange(const char * str)
	{
		return ByteRange(str);
	}
		
	/**
	 The template function captures any fundamental data type, or POD 
	 structure in the returned ByteRange object. The operation is
	 equal to constructing range as ByteRange(&value, sizeof(value)).
	 */
	template <typename POD>
	ByteRange MakeRange(const POD & value)
	{
		static_assert(std::is_pod<POD>::value, "POD or fundamental type is expected");
		return ByteRange(&value, sizeof(value));
	}
	
} // cc7
