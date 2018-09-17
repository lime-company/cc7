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

#include <cc7tests/CC7Tests.h>
#include <cc7/CC7.h>

namespace cc7
{
namespace tests
{
	class cc7Base32Tests : public UnitTest
	{
	public:
		cc7Base32Tests()
		{
			CC7_REGISTER_TEST_METHOD(testEncodePadding);
			CC7_REGISTER_TEST_METHOD(testEncodeNoPadding);
			CC7_REGISTER_TEST_METHOD(testRandomEncodeDecode);
			CC7_REGISTER_TEST_METHOD(testDecodeWrongPadding);
			CC7_REGISTER_TEST_METHOD(testDecodeWrongNoPadding);
		}
		
		// UNIT TESTS
		
		// MARK: - Good data
		
		void testEncodePadding()
		{
			ccstAssertEqual("", ToBase32String(MakeRange(""), true));
			ccstAssertEqual("MY======", ToBase32String(MakeRange("f"), true));
			ccstAssertEqual("MZXQ====", ToBase32String(MakeRange("fo"), true));
			ccstAssertEqual("MZXW6===", ToBase32String(MakeRange("foo"), true));
			ccstAssertEqual("MZXW6YQ=", ToBase32String(MakeRange("foob"), true));
			ccstAssertEqual("MZXW6YTB", ToBase32String(MakeRange("fooba"), true));
			ccstAssertEqual("MZXW6YTBOI======", ToBase32String(MakeRange("foobar"), true));
			ccstAssertEqual("KRUGS4ZANFZSA5TFOJ4SA3DPNZTSA5DFPB2CAZLOMNXWIZLEEBUW4ICCMFZWKMZS", ToBase32String(MakeRange("This is very long text encoded in Base32"), true));
			ccstAssertEqual("KRUGS4ZANFZSA5TFOJ4SA3DPNZTSA5DFPB2CAZLOMNXWIZLEEBUW4ICCMFZWKMZSFY======", ToBase32String(MakeRange("This is very long text encoded in Base32."), true));
			auto lorem_ipsum = 	"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
								"Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure "
								"dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat "
								"non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
			auto base_32_lip = "JRXXEZLNEBUXA43VNUQGI33MN5ZCA43JOQQGC3LFOQWCAY3PNZZWKY3UMV2HK4RAMFSGS4DJONRWS3THEBSWY2LUFQQ"
								"HGZLEEBSG6IDFNF2XG3LPMQQHIZLNOBXXEIDJNZRWSZDJMR2W45BAOV2CA3DBMJXXEZJAMV2CAZDPNRXXEZJANVQWO"
								"3TBEBQWY2LROVQS4ICVOQQGK3TJNUQGCZBANVUW42LNEB3GK3TJMFWSYIDROVUXGIDON5ZXI4TVMQQGK6DFOJRWS5D"
								"BORUW63RAOVWGYYLNMNXSA3DBMJXXE2LTEBXGS43JEB2XIIDBNRUXC5LJOAQGK6BAMVQSAY3PNVWW6ZDPEBRW63TTM"
								"VYXKYLUFYQEI5LJOMQGC5LUMUQGS4TVOJSSAZDPNRXXEIDJNYQHEZLQOJSWQZLOMRSXE2LUEBUW4IDWN5WHK4DUMF2"
								"GKIDWMVWGS5BAMVZXGZJAMNUWY3DVNUQGI33MN5ZGKIDFOUQGM5LHNFQXIIDOOVWGYYJAOBQXE2LBOR2XELRAIV4GG"
								"ZLQORSXK4RAONUW45BAN5RWGYLFMNQXIIDDOVYGSZDBORQXIIDON5XCA4DSN5UWIZLOOQWCA43VNZ2CA2LOEBRXK3D"
								"QMEQHC5LJEBXWMZTJMNUWCIDEMVZWK4TVNZ2CA3LPNRWGS5BAMFXGS3JANFSCAZLTOQQGYYLCN5ZHK3JO";
			ccstAssertEqual(base_32_lip, ToBase32String(MakeRange(lorem_ipsum), true));
		}
		
		void testEncodeNoPadding()
		{
			ccstAssertEqual("", ToBase32String(MakeRange(""), false));
			ccstAssertEqual("MY", ToBase32String(MakeRange("f"), false));
			ccstAssertEqual("MZXQ", ToBase32String(MakeRange("fo"), false));
			ccstAssertEqual("MZXW6", ToBase32String(MakeRange("foo"), false));
			ccstAssertEqual("MZXW6YQ", ToBase32String(MakeRange("foob"), false));
			ccstAssertEqual("MZXW6YTB", ToBase32String(MakeRange("fooba"), false));
			ccstAssertEqual("MZXW6YTBOI", ToBase32String(MakeRange("foobar"), false));
			ccstAssertEqual("KRUGS4ZANFZSA5TFOJ4SA3DPNZTSA5DFPB2CAZLOMNXWIZLEEBUW4ICCMFZWKMZS", ToBase32String(MakeRange("This is very long text encoded in Base32"), false));
			ccstAssertEqual("KRUGS4ZANFZSA5TFOJ4SA3DPNZTSA5DFPB2CAZLOMNXWIZLEEBUW4ICCMFZWKMZSFY", ToBase32String(MakeRange("This is very long text encoded in Base32."), false));
			auto lorem_ipsum = 	"Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. "
								"Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure "
								"dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat "
								"non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
			auto base_32_lip = "JRXXEZLNEBUXA43VNUQGI33MN5ZCA43JOQQGC3LFOQWCAY3PNZZWKY3UMV2HK4RAMFSGS4DJONRWS3THEBSWY2LUFQQ"
								"HGZLEEBSG6IDFNF2XG3LPMQQHIZLNOBXXEIDJNZRWSZDJMR2W45BAOV2CA3DBMJXXEZJAMV2CAZDPNRXXEZJANVQWO"
								"3TBEBQWY2LROVQS4ICVOQQGK3TJNUQGCZBANVUW42LNEB3GK3TJMFWSYIDROVUXGIDON5ZXI4TVMQQGK6DFOJRWS5D"
								"BORUW63RAOVWGYYLNMNXSA3DBMJXXE2LTEBXGS43JEB2XIIDBNRUXC5LJOAQGK6BAMVQSAY3PNVWW6ZDPEBRW63TTM"
								"VYXKYLUFYQEI5LJOMQGC5LUMUQGS4TVOJSSAZDPNRXXEIDJNYQHEZLQOJSWQZLOMRSXE2LUEBUW4IDWN5WHK4DUMF2"
								"GKIDWMVWGS5BAMVZXGZJAMNUWY3DVNUQGI33MN5ZGKIDFOUQGM5LHNFQXIIDOOVWGYYJAOBQXE2LBOR2XELRAIV4GG"
								"ZLQORSXK4RAONUW45BAN5RWGYLFMNQXIIDDOVYGSZDBORQXIIDON5XCA4DSN5UWIZLOOQWCA43VNZ2CA2LOEBRXK3D"
								"QMEQHC5LJEBXWMZTJMNUWCIDEMVZWK4TVNZ2CA3LPNRWGS5BAMFXGS3JANFSCAZLTOQQGYYLCN5ZHK3JO";
			ccstAssertEqual(base_32_lip, ToBase32String(MakeRange(lorem_ipsum), false));
		}
		
		void testRandomEncodeDecode()
		{
			// Good scenarios
			ByteArray max_data = getTestRandomData(1025);
			bool result;
			for (size_t test_size = 0; test_size < max_data.size(); test_size++) {
				
				ByteRange source_data = max_data.byteRange().subRangeTo(test_size);
				std::string plain, padded;
				result = Base32_Encode(source_data, false, plain);
				ccstAssertTrue(result);
				result = Base32_Encode(source_data, true, padded);
				ccstAssertTrue(result);

				ByteArray plain_dec, padded_dec;
				result = Base32_Decode(plain, false, plain_dec);
				ccstAssertTrue(result);
				ccstAssertEqual(source_data, plain_dec);
				result = Base32_Decode(padded, true, padded_dec);
				ccstAssertTrue(result);
				ccstAssertEqual(source_data, padded_dec);
			}
		}

		
		// MARK: - Wrong data
		
		void testDecodeWrongPadding()
		{
			const char* wrong_data[] = {
				"=ZXW6YTB",		// wrong char
				"M=XW6YTB",		// wrong char
				"MZ=W6YTB",		// wrong char
				"MZX=6YTB",		// wrong char
				"MZXW=YTB",		// wrong char
				"MZXW6=TB",		// wrong char
				"MZXW6Y=B",		// wrong char
				"MZXW6YTB========",		// wrong padding
				"MZXW6YTB=======",		// wrong padding
				"MZXW6YTB======",		// wrong padding
				"MZXW6YTB=====",		// wrong padding
				"MZXW6YTB====",		// wrong padding
				"MZXW6YTB===",		// wrong padding
				"MZXW6YTB==",		// wrong padding
				"MZXW6YTB=",		// wrong padding
				"========",		// wrong padding
				"=======",		// wrong padding
				"======",		// wrong padding
				"=====",		// wrong padding
				"====",		// wrong padding
				"===",		// wrong padding
				"==",		// wrong padding
				"=",		// wrong padding
				"M1======", // remaining bits
				"MZX1====", // remaining bits
				"MZXW7===", // remaining bits
				"MZXW6Y1=", // remaining bits
				"MZXW6YT1", // remaining bits
				"M=======",  // wrong size
				"MZX=====",  // wrong size
				"MZXW6Y==",  // wrong size
				
				nullptr		// end of table
			};
			
			const char ** ptr = wrong_data;
			while (*ptr) {
				auto wrong_b32 = std::string(*ptr++);
				ByteArray foo;
				bool result = Base32_Decode(wrong_b32, true, foo);
				ccstAssertFalse(result, "String '%s' should not pass.", wrong_b32.c_str());
			}
		}
		
		void testDecodeWrongNoPadding()
		{
			const char* wrong_data[] = {
				"=ZXW6YTB",		// wrong char
				"M=XW6YTB",		// wrong char
				"MZ=W6YTB",		// wrong char
				"MZX=6YTB",		// wrong char
				"MZXW=YTB",		// wrong char
				"MZXW6=TB",		// wrong char
				"MZXW6Y=B",		// wrong char
				"M1", 		// remaining bits
				"MZX1", 	// remaining bits
				"MZXW7", 	// remaining bits
				"MZXW6Y1", 	// remaining bits
				"MZXW6YT1", // remaining bits
				"M", 		// wrong size
				"MZX",  	// wrong size
				"MZXW6Y",  	// wrong size
				
				nullptr		// end of table
			};
			
			const char ** ptr = wrong_data;
			while (*ptr) {
				auto wrong_b32 = std::string(*ptr++);
				ByteArray foo;
				bool result = Base32_Decode(wrong_b32, false, foo);
				ccstAssertFalse(result, "String '%s' should not pass.", wrong_b32.c_str());
			}
		}
		
	};
	
	CC7_CREATE_UNIT_TEST(cc7Base32Tests, "cc7")
	
} // cc7::tests
} // cc7
