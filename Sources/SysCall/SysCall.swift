import Foundation
import Swift

public struct SysCall {
    
    public enum Error: Swift.Error {
        case rv(Int32)
        case error(Swift.Error)
        case args
    }
    
    public struct Args {
        let path: String
        let args: [String]
        let env:  [String: String]
    }
    
    public static func kinfo(_ pid: pid_t) -> Result<kinfo_proc, Error> {
        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout.size(ofValue: info)
        let rv = sysctl(&mib, u_int(mib.count), &info, &size, nil, 0)
        return rv == noErr ? .success(info) : .failure(.rv(rv))
    }
    
    public static func ppid(_ pid: pid_t) -> Result<pid_t, Error> {
        switch kinfo(pid) {
        case .success(let info):
            return .success(info.kp_eproc.e_ppid)
        case .failure(let err):
            return .failure(err)
        }
    }
    
    // https://developer.apple.com/forums/thread/681817
    public static func args(_ pid: pid_t) -> Result<Args, Error> {
        let data: Data
        do {
            data = try argsData(pid)
        } catch let err as Error {
            return .failure(err)
        } catch {
            return .failure(.error(error))
        }
        var remaining = data[...]
        guard remaining.count >= 6 else {
            return .failure(.args)
        }
        let count32 = remaining.prefix(4).reversed().reduce(
            0,
            { $0 << 8 | UInt32($1) }
        )
        remaining = remaining.dropFirst(4)
        let pathBytes = remaining.prefix(while: { $0 != 0 })
        guard let path = String(bytes: pathBytes, encoding: .utf8) else {
            return .failure(.args)
        }
        remaining = remaining.dropFirst(pathBytes.count)
        remaining = remaining.drop(while: { $0 == 0 })
        var arguments: [String] = []
        for _ in 0..<count32 {
            let argBytes = remaining.prefix(while: { $0 != 0 })
            guard let arg = String(bytes: argBytes, encoding: .utf8) else {
                return .failure(.args)
            }
            arguments.append(arg)
            remaining = remaining.dropFirst(argBytes.count)
            guard remaining.count != 0 else {
                return .failure(.args)
            }
            remaining = remaining.dropFirst()
        }
        var env: [String: String] = [:]
        for line in remaining.split(separator: 0) {
            if line.isEmpty {
                break
            }
            guard let line = String(bytes: line, encoding: .utf8) else {
                return .failure(.args)
            }
            let kv = line.split(
                separator: "=",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            guard kv.count == 2 else {
                return .failure(.args)
            }
            env[String(kv[0])] = String(kv[1])
        }
        return .success(Args(path: path, args: arguments, env: env))
    }
    
    static func argsData(_ pid: pid_t) throws -> Data {
        var argMax: CInt = 0
        var size = MemoryLayout.size(ofValue: argMax)
        let rv = sysctlbyname("kern.argmax", &argMax, &size, nil, 0)
        guard rv == noErr else {
            throw Error.rv(rv)
        }
        var buffer = Data(count: Int(argMax))
        size = try buffer.withUnsafeMutableBytes { buf -> Int in
            var mib = [CTL_KERN, KERN_PROCARGS2, pid]
            var bufSize = buf.count
            let rv = sysctl(
                &mib,
                u_int(mib.count),
                buf.baseAddress!,
                &bufSize,
                nil,
                0
            )
            guard rv == noErr else {
                throw Error.rv(rv)
            }
            return bufSize
        }
        buffer = buffer.prefix(size)
        return buffer
    }
}
