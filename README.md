# syscall-swift

Swift wrapper on some syscalls

- KERN_PROC_PID
- KERN_PROCARGS2

## Example

To get pid args:
```swift
import Darwin
import SysCall

func main() throws {
    let result = try SysCall.args2(getpid()).get()
    print(result.decodePath())
    print(result.decodeArgs())
    print(result.decodeEnv())
}

main()
```
