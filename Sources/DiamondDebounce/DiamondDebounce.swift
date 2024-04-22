import Combine
import Foundation
import Locked

extension Publisher {
    /// Organise the publishing of values to eliminate erroneous multiplying of the number
    /// of values caused by a diamond-shaped graph of Publishers when using `CombineLatest`. Must be used in
    /// conjunction with `debouncedCombineLatest()`, or `diamondDebounce()` placed after each `combineLatest()`.
    public func diamondDebounceGate() -> Publishers.Share<Publishers.DiamondDebounceGate<Self>> {
        return Publishers.DiamondDebounceGate(upstream: self).share()
    }

    /// A version of `combineLatest()` that detects and debounces erroneously multiplied values caused by a diamond-shaped
    /// graph of Publishers. Must be used in conjunction with either `diamondDebounceGate()`,
    /// which should be placed upstream right after the `Publisher` that is actually producing the values,
    /// or `DiamondDebounceState.doUpdate`, which you can use to wrap the code that triggers publishing values.
    public func debouncedCombineLatest<P>(_ other: P) -> Publishers.DiamondDebounce<Publishers.CombineLatest<Self, P>> where P: Publisher, Self.Failure == P.Failure {
        return self.combineLatest(other).diamondDebounce()
    }

    /// A version of `combineLatest()` that detects and debounces erroneously multiplied values caused by a diamond-shaped
    /// graph of Publishers. Must be used in conjunction with either `diamondDebounceGate()`,
    /// which should be placed upstream right after the `Publisher` that is actually producing the values,
    /// or `DiamondDebounceState.doUpdate`, which you can use to wrap the code that triggers publishing values.
    public func debouncedCombineLatest<P, T>(_ other: P, _ transform: @escaping (Self.Output, P.Output) -> T) -> Publishers.Map<Publishers.DiamondDebounce<Publishers.CombineLatest<Self, P>>, T> where P: Publisher, Self.Failure == P.Failure {
        return self.combineLatest(other).diamondDebounce().map(transform)
    }

    /// A version of `combineLatest()` that detects and debounces erroneously multiplied values caused by a diamond-shaped
    /// graph of Publishers. Must be used in conjunction with either `diamondDebounceGate()`,
    /// which should be placed upstream right after the `Publisher` that is actually producing the values,
    /// or `DiamondDebounceState.doUpdate`, which you can use to wrap the code that triggers publishing values.
    public func debouncedCombineLatest<P, Q>(_ publisher1: P, _ publisher2: Q) -> Publishers.DiamondDebounce<Publishers.CombineLatest3<Self, P, Q>> where P: Publisher, Q: Publisher, Self.Failure == P.Failure, P.Failure == Q.Failure {
        return self.combineLatest(publisher1, publisher2).diamondDebounce()
    }

    /// A version of `combineLatest()` that detects and debounces erroneously multiplied values caused by a diamond-shaped
    /// graph of Publishers. Must be used in conjunction with either `diamondDebounceGate()`,
    /// which should be placed upstream right after the `Publisher` that is actually producing the values,
    /// or `DiamondDebounceState.doUpdate`, which you can use to wrap the code that triggers publishing values.
    public func debouncedCombineLatest<P, Q, T>(_ publisher1: P, _ publisher2: Q, _ transform: @escaping (Self.Output, P.Output, Q.Output) -> T) -> Publishers.Map<Publishers.DiamondDebounce<Publishers.CombineLatest3<Self, P, Q>>, T> where P: Publisher, Q: Publisher, Self.Failure == P.Failure, P.Failure == Q.Failure {
        return self.combineLatest(publisher1, publisher2).diamondDebounce().map(transform)
    }

    /// A version of `combineLatest()` that detects and debounces erroneously multiplied values caused by a diamond-shaped
    /// graph of Publishers. Must be used in conjunction with either `diamondDebounceGate()`,
    /// which should be placed upstream right after the `Publisher` that is actually producing the values,
    /// or `DiamondDebounceState.doUpdate`, which you can use to wrap the code that triggers publishing values.
    public func debouncedCombineLatest<P, Q, R>(_ publisher1: P, _ publisher2: Q, _ publisher3: R) -> Publishers.DiamondDebounce<Publishers.CombineLatest4<Self, P, Q, R>> where P: Publisher, Q: Publisher, R: Publisher, Self.Failure == P.Failure, P.Failure == Q.Failure, Q.Failure == R.Failure {
        return self.combineLatest(publisher1, publisher2, publisher3).diamondDebounce()
    }

    /// A version of `combineLatest()` that detects and debounces erroneously multiplied values caused by a diamond-shaped
    /// graph of Publishers. Must be used in conjunction with either `diamondDebounceGate()`,
    /// which should be placed upstream right after the `Publisher` that is actually producing the values,
    /// or `DiamondDebounceState.doUpdate`, which you can use to wrap the code that triggers publishing values.
    public func debouncedCombineLatest<P, Q, R, T>(_ publisher1: P, _ publisher2: Q, _ publisher3: R, _ transform: @escaping (Self.Output, P.Output, Q.Output, R.Output) -> T) -> Publishers.Map<Publishers.DiamondDebounce<Publishers.CombineLatest4<Self, P, Q, R>>, T> where P: Publisher, Q: Publisher, R: Publisher, Self.Failure == P.Failure, P.Failure == Q.Failure, Q.Failure == R.Failure {
        return self.combineLatest(publisher1, publisher2, publisher3).diamondDebounce().map(transform)
    }

    /// Detect and debounce erroneously multiplied values caused by a diamond-shaped
    /// graph of Publishers when using `combineLatest()`. This publisher should be placed immediately after
    /// the `combineLatest()` publisher. Must be used in conjunction with either `diamondDebounceGate()`,
    /// which should be placed upstream right after the `Publisher` that is actually producing the values,
    /// or `DiamondDebounceState.doUpdate`, which you can use to wrap the code that triggers publishing values.
    public func diamondDebounce() -> Publishers.DiamondDebounce<Self> {
        return Publishers.DiamondDebounce(upstream: self)
    }
}

public enum DiamondDebounceState {
    fileprivate static let updateQueue: ThreadLocal<[(generation: UInt64, update: () -> Void)]?> = .init(nil)

    /// Enable the diamond graph debouncing implemented in `DiamondDebounce` for the duration of
    /// this block. This is a thread-local state, so will apply to all stages of the `Publisher`
    /// graph that execute immediately on the same thread. Use this around any code that causes
    /// values to be published to the `Publisher` graph that uses `DiamondDebounce`.
    public static func doUpdate<Result>(_ block: () -> Result) -> Result {
        guard updateQueue.value == nil else {
            return block()
        }

        updateQueue.value = []

        let result = block()

        while true {
            guard let queue = updateQueue.value, let index = queue.enumerated().min(by: { $0.element.generation < $1.element.generation })?.offset else { break }
            let (_, updateHandler) = queue[index]
            self.updateQueue.value?.remove(at: index)
            updateHandler()
        }

        updateQueue.value = nil
        return result
    }

    static let currentGeneration: Locked<UInt64> = .init(0)

    fileprivate static func nextGeneration() -> UInt64 {
        return currentGeneration.withValue { value in
            value += 1
            return value
        }
    }
}

extension Publishers {
    /// A publisher that organises the publishing of values to eliminate erroneous multiplying of the number
    /// of values caused by a diamond-shaped graph of Publishers when using `CombineLatest`. Must be used in
    /// conjunction with `DiamondDebounce` publishers placed after each `CombineLatest`, and must also be
    /// shared using `.share()` to work correctly!
    public struct DiamondDebounceGate<Upstream>: Publisher where Upstream: Publisher {
        /// The kind of values published by this publisher.
        ///
        /// This publisher uses its upstream publisher's output type.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publisher's failure type.
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        /// Creates a publisher that ... to avoid diamond graphs causing multipled updates.
        /// - Parameters:
        ///   - upstream: The publisher from which this publisher receives elements.
        public init(upstream: Upstream) {
            self.upstream = upstream
        }

        public func receive<S>(subscriber: S) where S: Subscriber, Upstream.Failure == S.Failure, Upstream.Output == S.Input {
            upstream.subscribe(UpstreamSubscriber(downstream: subscriber))
        }

        private class UpstreamSubscriber<Downstream: Subscriber>: Subscriber where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure {
            typealias Input = Upstream.Output
            typealias Failure = Upstream.Failure

            let downstream: Downstream

            init(downstream: Downstream) {
                self.downstream = downstream
            }

            func receive(subscription: Subscription) {
                downstream.receive(subscription: subscription)
            }

            func receive(_ input: Output) -> Subscribers.Demand {
                return DiamondDebounceState.doUpdate { downstream.receive(input) }
            }

            func receive(completion: Subscribers.Completion<Failure>) {
                downstream.receive(completion: completion)
            }
        }
    }

    /// A publisher that detects and debounces erroneously multiplied values caused by a diamond-shaped
    /// graph of Publishers when using `CombineLatest`. This publisher should be placed immediately after
    /// the `CombineLatest` publisher. Must be used in conjunction with either `DiamondDebounceGate`,
    /// which should be placed upstream right after the `Publisher` that is actually producing the values,
    /// or `DiamondDebounceState.doUpdate`, which you can use to wrap the code that triggers publishing values.
    public struct DiamondDebounce<Upstream>: Publisher where Upstream: Publisher {
        /// The kind of values published by this publisher.
        ///
        /// This publisher uses its upstream publisher's output type.
        public typealias Output = Upstream.Output

        /// The kind of errors this publisher might publish.
        ///
        /// This publisher uses its upstream publisher's failure type.
        public typealias Failure = Upstream.Failure

        /// The publisher from which this publisher receives elements.
        public let upstream: Upstream

        private let generation: UInt64

        /// Creates a publisher that debounces updates to avoid diamond graphs causing multipled updates.
        /// - Parameters:
        ///   - upstream: The publisher from which this publisher receives elements.
        public init(upstream: Upstream) {
            self.upstream = upstream
            self.generation = DiamondDebounceState.nextGeneration()
        }

        public func receive<S>(subscriber: S) where S: Subscriber, S.Input == Output, S.Failure == Failure {
            upstream.subscribe(UpstreamSubscriber(downstream: subscriber, generation: generation))
        }

        private class UpstreamSubscriber<Downstream: Subscriber>: Subscriber, Subscription where Downstream.Input == Upstream.Output, Downstream.Failure == Upstream.Failure {
            typealias Input = Upstream.Output
            typealias Failure = Upstream.Failure

            let downstream: Downstream
            let generation: UInt64
            var subscription: Subscription?
            var latestInput: Output?
            var upstreamDemand: Subscribers.Demand = .none
            var downstreamDemand: Subscribers.Demand = .none
            var delayedOutput: Output?

            init(downstream: Downstream, generation: UInt64) {
                self.downstream = downstream
                self.generation = generation
            }

            func receive(subscription: Subscription) {
                self.subscription = subscription
                downstream.receive(subscription: self)
            }

            func receive(_ input: Output) -> Subscribers.Demand {
                // When we receive an input, we will either pass it straight through to downstream if we are in the normal
                // state, or we will store it if we are debouncing.
                // We also track the demand that downstream has given us, and the demand we have sent to upstream, and
                // how it changes as values are sent. We try to keep upstream and downstream demand in sync by always
                // sending the difference between the two. While debouncing, the demands will go out of sync by 1, as
                // we want to keep accepting values until debouncing ends. At that point, we send the debounced value
                // out of order, and we have to handle the case where downstream may have run out of demand.
                if upstreamDemand > 0 { upstreamDemand -= 1 }

                if DiamondDebounceState.updateQueue.value != nil {
                    if latestInput == nil {
                        // If this is the first debounced value, register a callback in the queue of updates needed.
                        // This will be called back later when it is safe to propagate the value.
                        DiamondDebounceState.updateQueue.value?.append((generation: generation, update: { [weak self] in
                            guard let self, let latestInput = self.latestInput else { return }
                            self.latestInput = nil
                            send(output: latestInput)
                        }))
                    }
                    latestInput = input

                    // Since we dropped this value for now, we are happy to receive at least one more, so update the demand.
                    upstreamDemand += 1
                    return .max(1)
                } else {
                    send(output: input)
                    defer { upstreamDemand = downstreamDemand }
                    return downstreamDemand - upstreamDemand
                }
            }

            func send(output: Output) {
                // Check if there is enough demand to send this output.
                if downstreamDemand > 0 {
                    // If there is, account for the demand going down and send the output.
                    downstreamDemand -= 1
                    let demand = downstream.receive(output)
                    downstreamDemand += demand
                } else {
                    // If there is not, store this output to be sent once we get more demand.
                    assert(delayedOutput == nil)
                    delayedOutput = output
                }
            }

            func request(_ demand: Subscribers.Demand) {
                downstreamDemand += demand
                if let delayedOutput, downstreamDemand > 0 {
                    // If there was an output delayed because of lack of demand, and we now have enough demand, send it.
                    send(output: delayedOutput)
                    self.delayedOutput = nil
                }
                subscription?.request(downstreamDemand - upstreamDemand)
                upstreamDemand = downstreamDemand
            }

            func cancel() {
                subscription?.cancel()
            }

            func receive(completion: Subscribers.Completion<Failure>) {
                downstream.receive(completion: completion)
            }
        }
    }
}

/// A thread-local static value. This value will look the same to code running within a given
/// thread, but other threads have their own version of it. Should only be used on static vars.
public struct ThreadLocal<Value>: @unchecked Sendable {
    private let defaultValue: () -> Value
    private let name: String

    public init(_ value: @autoclosure @escaping () -> Value) {
        self.defaultValue = value
        self.name = UUID().uuidString
    }

    public var value: Value {
        get {
            if let value = Thread.current.threadDictionary[name] as? Value {
                return value
            } else {
                let value = defaultValue()
                Thread.current.threadDictionary[name] = value
                return value
            }
        }

        nonmutating set {
            Thread.current.threadDictionary[name] = newValue
        }
    }
}
