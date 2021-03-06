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

#include <cc7/DebugFeatures.h>

#if !defined(CC7_APPLE)
#error "This file is for Apple platforms only"
#endif

#pragma mark - Assertion log

#if defined(ENABLE_CC7_ASSERT)
namespace cc7
{
namespace debug
{
    static void private_DumpAssertToLog(void * foo, const char * file, int line, const char * message)
    {
        NSLog(@"%@", [NSString stringWithUTF8String:message]);
        //
        // Break execution with using software breakpoint.
        //
        CC7_BREAKPOINT();
    }
    
    AssertionHandlerSetup Platform_GetDefaultAssertionHandler()
    {
        static AssertionHandlerSetup s_default_setup = { private_DumpAssertToLog, nullptr };
        return s_default_setup;
    }
} // cc7::debug
} // cc7
#endif

#pragma mark - Debug log

#if defined(ENABLE_CC7_LOG)
namespace cc7
{
namespace debug
{
    static void private_LogImpl(void * foo, const char * message)
    {
        NSLog(@"CC7: %@", [NSString stringWithUTF8String:message]);
    }
    
    LogHandlerSetup Platform_GetDefaultLogHandler()
    {
        static LogHandlerSetup s_default_setup = { private_LogImpl, nullptr };
        return s_default_setup;
    }
    
    bool Platform_IsDefaultLogEnabled()
    {
        return false;
    }
} // cc7::debug
} // cc7
#endif //ENABLE_CC7_LOG

/*
 This is a dummy global variable that workarounds a bug in the latest "strip" tool,
 that treats empty object as already stripped. The PlatformApple.o object is empty
 due to a conditional compilation. The problem happen only during "Archive" phase
 of Xcode build, and leads to mysterious warning:
 
 .../usr/bin/strip: warning: input object file already stripped: .../usr/local/lib/libcc7-ios.a(PlatformApple.o)
 
 What is interesting is that such warning happens only for x86_64 architecture
 (e.g. for Catalyst and all simulators)
 */
int cc7_input_object_already_stripped_warning_workaround = 0;
