    import XCTest
    @testable import SysCall

    final class SysCallTests: XCTestCase {
        func testKinfo() throws {
            let kinfo = try SysCall.kinfo(getpid()).get()
            print(kinfo)
        }
        
        func testPpid() throws {
            let ppid = try SysCall.ppid(getpid()).get()
            assert(ppid == getppid())
        }
        
        func testArgs2() throws {
            let result = try SysCall.args2(getpid()).get()
            print(result.decodePath())
            print(result.decodeArgs())
            print(result.decodeEnv())
        }
    }
