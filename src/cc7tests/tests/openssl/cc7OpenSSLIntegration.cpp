/*
 * Copyright 2020 Wultra s.r.o.
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

#include <cc7tests/CC7Tests.h>
#include <cc7/CC7.h>

#include <openssl/aes.h>
#include <openssl/rand.h>

namespace cc7
{
namespace tests
{
	class cc7OpenSSLIntegration : public UnitTest
	{
	public:
		cc7OpenSSLIntegration()
		{
			CC7_REGISTER_TEST_METHOD(testLinking)
		}
		
		/// This test only validates whether we have OpenSSL properly integrated into the project.
		void testLinking()
		{
			AES_KEY key;
			const unsigned char key_bytes[16] = { 0 };
			auto result = AES_set_decrypt_key(key_bytes, 128, &key);
			ccstAssertTrue(result == 0);
		}
	};
	
	CC7_CREATE_UNIT_TEST(cc7OpenSSLIntegration, "cc7")
	
} // cc7::tests
} // cc7
