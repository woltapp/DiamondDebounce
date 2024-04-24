import Combine
import DiamondDebounce

let a = PassthroughSubject<Int, Never>() //.diamondDebounceGate()
let b = a.map { $0 * 2 }
let c = a.map { $0 * -2 }
let d = b.combineLatest(c).sink {
    print("\($0) + \($1) = \($0 + $1)")
}

print("Send 1 through a")
a.send(1)
print("Send 2 through a")
a.send(2)
print("Send 3 through a")
a.send(3)
