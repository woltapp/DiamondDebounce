import Foundation
import XCTest
import Combine
@testable import DiamondDebounce

final class PropertyTests: XCTestCase {
    func testSimpleDiamond() {
        let a = PassthroughSubject<Int, Never>().diamondDebounceGate()
        let b1 = a.map { $0 * 2 }
        let b2 = a.map { -$0 * 2 }
        let c = b1.debouncedCombineLatest(b2) { $0 + $1 }

        var numberOfUpdates = 0
        let cancellable = c.sink { value in
            XCTAssertEqual(value, 0)
            numberOfUpdates += 1
        }

        a.upstream.upstream.send(2)
        a.upstream.upstream.send(3)
        a.upstream.upstream.send(4)

        XCTAssertEqual(numberOfUpdates, 3)

        _ = cancellable
    }

    func testLongPathDiamond() {
        let a = PassthroughSubject<Int, Never>().diamondDebounceGate()
        let b1 = a.map { $0 * 2 }
        let b2 = a.map { -$0 * 2 }
        let c = b1.map { -$0 }
        let d = c.map { -$0 }
        let e = d.debouncedCombineLatest(b2) { $0 + $1 }

        var numberOfUpdates = 0
        let cancellable = e.sink { value in
            XCTAssertEqual(value, 0)
            numberOfUpdates += 1
        }

        a.upstream.upstream.send(2)
        a.upstream.upstream.send(3)
        a.upstream.upstream.send(4)

        XCTAssertEqual(numberOfUpdates, 3)

        _ = cancellable
    }

    func testComplexDiamond() {
        let a = PassthroughSubject<Int, Never>().diamondDebounceGate()
        let b1 = a.map { $0 * 2 }
        let b2 = a.map { -$0 * 2 }
        let c = b1.debouncedCombineLatest(b2) { $0 + $1 }
        let d1 = b1.debouncedCombineLatest(c) { $0 + $1 }
        let d2 = b2.debouncedCombineLatest(c) { $0 + $1 }
        let e = d1.debouncedCombineLatest(d2) { $0 + $1 }

        var numberOfUpdates = 0
        let cancellable = e.sink { value in
            XCTAssertEqual(value, 0)
            numberOfUpdates += 1
        }

        a.upstream.upstream.send(2)
        a.upstream.upstream.send(3)
        a.upstream.upstream.send(4)

        XCTAssertEqual(numberOfUpdates, 3)

        _ = cancellable
    }

    func testDoUpdate() {
        let a = PassthroughSubject<Int, Never>()
        let b1 = a.map { $0 * 2 }
        let b2 = a.map { -$0 * 2 }
        let c = b1.debouncedCombineLatest(b2) { $0 + $1 }

        var numberOfUpdates = 0
        let cancellable = c.sink { value in
            XCTAssertEqual(value, 0)
            numberOfUpdates += 1
        }

        DiamondDebounceState.doUpdate { a.send(2) }
        DiamondDebounceState.doUpdate { a.send(3) }
        DiamondDebounceState.doUpdate { a.send(4) }

        XCTAssertEqual(numberOfUpdates, 3)

        _ = cancellable
    }

    @Published var testPublishedValue: Int = 1

    func testPublished() {
        let b1 = $testPublishedValue.map { $0 * 2 }
        let b2 = $testPublishedValue.map { -$0 * 2 }
        let c = b1.debouncedCombineLatest(b2) { $0 + $1 }

        var numberOfUpdates = 0
        let cancellable = c.sink { value in
            XCTAssertEqual(value, 0)
            numberOfUpdates += 1
        }

        DiamondDebounceState.doUpdate { testPublishedValue = 2 }
        DiamondDebounceState.doUpdate { testPublishedValue = 3 }
        DiamondDebounceState.doUpdate { testPublishedValue = 4 }

        XCTAssertEqual(numberOfUpdates, 4)

        _ = cancellable
    }

    @Published var testDemandValue: Int = 1

    func testDemand() async {
        // Note: I can't seem to get backpressure working very well with either .share() which is used by
        // .diamondUpdateGate(), nor with .combineLatest which is what you would usually use .diamondDebounce()
        // with. So this test is not very conclusive, it only tests a very basic backpressure case, but
        // in real code backpressure will most likely not work at all due to the other Publishers involved.

        let a = $testDemandValue
        let b = a.buffer(size: 4, prefetch: .keepFull, whenFull: .dropOldest)
        let c = b.diamondDebounce()

        let expectation = expectation(description: "Received final value")
        expectation.expectedFulfillmentCount = 4

        var numberOfUpdates = 0
        let sink = SlowSink(delay: 0.1, handler: { value in
            XCTAssertEqual(value, numberOfUpdates + 1)
            numberOfUpdates += 1
            expectation.fulfill()
        })
        c.subscribe(sink)

        DiamondDebounceState.doUpdate { testDemandValue = 2 }
        DiamondDebounceState.doUpdate { testDemandValue = 3 }
        DiamondDebounceState.doUpdate { testDemandValue = 4 }

        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertEqual(numberOfUpdates, 4)

        _ = sink
    }

    func testNestedUpdates() {
        let a = PassthroughSubject<Int, Never>()
        let b1 = PassthroughSubject<Int, Never>()
        let cancellable1 = a.map { $0 * 2 }.sink { value in
            DiamondDebounceState.doUpdate { b1.send(value) }
        }
        let b2 = a.map { -$0 * 2 }

        let c = b1.debouncedCombineLatest(b2) { $0 + $1 }
        let d1 = b1.debouncedCombineLatest(c) { $0 + $1 }
        let d2 = PassthroughSubject<Int, Never>()
        let cancellable2 = b2.debouncedCombineLatest(c) { $0 + $1 }.sink { value in
            DiamondDebounceState.doUpdate { d2.send(value) }
        }
        let e = d1.debouncedCombineLatest(d2) { $0 + $1 }

        var numberOfUpdates = 0
        let cancellable3 = e.sink { value in
            XCTAssertEqual(value, 0)
            numberOfUpdates += 1
        }

        DiamondDebounceState.doUpdate { a.send(2) }
        DiamondDebounceState.doUpdate { a.send(3) }
        DiamondDebounceState.doUpdate { a.send(4) }

        XCTAssertEqual(numberOfUpdates, 3)

        _ = (cancellable1, cancellable2, cancellable3)
    }
}

class SlowSink<Input>: Subscriber, Cancellable {
    typealias Failure = Never

    private let handler: (Input) -> Void
    private let delay: TimeInterval
    private var subscription: Subscription?
    private var ready = true

    init(delay: TimeInterval, handler: @escaping (Input) -> Void) {
        self.delay = delay
        self.handler = handler
    }

    func receive(subscription: Subscription) {
        self.subscription = subscription
        subscription.request(.max(1))
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        handler(input)
        assert(ready)
        ready = false
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            self.ready = true
            self.subscription?.request(.max(1))
        }
        return .none
    }

    func receive(completion: Subscribers.Completion<Never>) {}

    func cancel() {}
}
