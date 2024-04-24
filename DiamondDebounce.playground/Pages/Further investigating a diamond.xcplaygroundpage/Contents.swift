import Combine

let a = PassthroughSubject<Int, Never>()
let b = a.map { print("b is \($0 * 2)"); return $0 * 2 }
let c = a.map { print("b is \($0 * -2)"); return $0 * -2 }
let d = b.combineLatest(c)
let cancellable = d.sink {
    print("d is \($0) + \($1) = \($0 + $1)")
}

print("Send 1 through a")
a.send(1)
print("Send 2 through a")
a.send(2)
print("Send 3 through a")
a.send(3)
