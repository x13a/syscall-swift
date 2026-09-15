import Foundation
import Swift

public struct SysCall {
    public static let envSeparator = UInt8(ascii: "=")
    
    public enum Error: Swift.Error {
        case rv(Int32)
        case args
        case error(Swift.Error)
    }
    
    public struct RawEnvValue {
        public let name:  Data
        public let value: Data?
    }
    
    public struct EnvValue {
        public let name:  String?
        public let value: String?
    }
    
    public struct Args {
        public let path: Data
        public let args: [Data]
        public let env:  [RawEnvValue]
        
        public func decodePath() -> String? {
            String(data: self.path, encoding: .utf8)
        }
        
        public func decodeArgs() -> [String?] {
            self.args.map { String(data: $0, encoding: .utf8) }
        }
        
        public func decodeEnv() -> [EnvValue] {
            self.env.map { EnvValue(
                name: String(data: $0.name, encoding: .utf8),
                value: $0.value.flatMap { String(data: $0, encoding: .utf8) }
            ) }
        }
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
    public static func args2(_ pid: pid_t) -> Result<Args, Error> {
        let data: Data
        do {
            data = try args2Data(pid)
        } catch let err as Error {
            return .failure(err)
        } catch {
            return .failure(.error(error))
        }
        var remaining = data[...]
        guard remaining.count >= 6 else { return .failure(.args) }
        let count32 = remaining.prefix(4).reversed().reduce(
            0,
            { $0 << 8 | UInt32($1) }
        )
        remaining = remaining.dropFirst(4)
        let path = remaining.prefix(while: { $0 != 0 })
        remaining = remaining.dropFirst(path.count)
        remaining = remaining.drop(while: { $0 == 0 })
        var args: [Data] = []
        for _ in 0..<count32 {
            let arg = remaining.prefix(while: { $0 != 0 })
            args.append(arg)
            remaining = remaining.dropFirst(arg.count)
            guard remaining.count != 0 else { return .failure(.args) }
            remaining = remaining.dropFirst()
        }
        var env: [RawEnvValue] = []
        for line in remaining.split(separator: 0) {
            if line.isEmpty { break }
            let kv = line.split(
                separator: Self.envSeparator,
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            guard kv.count != 0 else { continue }
            env.append(RawEnvValue(
                name: kv[0], value: kv.count != 1 ? kv[1] : nil
            ))
        }
        return .success(Args(path: path, args: args, env: env))
    }
}

func args2Data(_ pid: pid_t) throws -> Data {
    var argMax: CInt = 0
    var size = MemoryLayout.size(ofValue: argMax)
    let rv = sysctlbyname("kern.argmax", &argMax, &size, nil, 0)
    guard rv == noErr else { throw SysCall.Error.rv(rv) }
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
        guard rv == noErr else { throw SysCall.Error.rv(rv) }
        return bufSize
    }
    buffer = buffer.prefix(size)
    return buffer
}
