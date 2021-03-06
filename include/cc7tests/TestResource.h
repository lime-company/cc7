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

#include <cc7/ByteRange.h>

namespace cc7
{
namespace tests
{
    class TestResource
    {
    public:
        TestResource(const cc7::byte * data, size_t size, const char * name);
        
        const cc7::byte *   data() const { return _data; }
        size_t              size() const { return _size; }
        const char *        name() const { return _name; }
        cc7::ByteRange      range() const { return cc7::ByteRange(_data, _size); }
        
    private:
        
        const cc7::byte *   _data;
        size_t              _size;
        const char *        _name;
    };
    
} // cc7::tests
} // cc7