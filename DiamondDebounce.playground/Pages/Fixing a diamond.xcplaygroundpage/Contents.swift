import Combine
import DiamondDebounce

let a = PassthroughSubject<Int, Never>()
let a2 = a.diamondDebounceGate()
let b = a2.map { print("b is \($0 * 2)"); return $0 * 2 }
let c = a2.map { print("b is \($0 * -2)"); return $0 * -2 }
let d = b.combineLatest(c).diamondDebounce()
let cancellable = d.sink {
    print("d is \($0) + \($1) = \($0 + $1)")
}

print("Send 1 through a")
a.send(1)
print("Send 2 through a")
a.send(2)
print("Send 3 through a")
a.send(3)
