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
        
        func testArgs() throws {
            let args = try SysCall.args(getpid()).get()
            print(args.path)
            print(args.args)
            print(args.env)
        }
    }
