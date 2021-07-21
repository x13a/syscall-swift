# syscall-swift

Swift wrapper on some syscalls.

- KERN_PROC_PID
- KERN_PROCARGS2

## Example

To get pid args:
```swift
import Darwin
import SysCall

func main() throws {
    let args = try SysCall.args(getpid()).get()
    print(args.path)
    print(args.args)
    print(args.env)
}

main()
```
