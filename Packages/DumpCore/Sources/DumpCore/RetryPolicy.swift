/// How long the outbox waits before sending again after a failure: one second,
/// doubling with each failure in a row up to five minutes, plus up to half a
/// second of jitter so retries don't all fire the moment the network returns.
public struct RetryPolicy: Sendable {
    public var initialDelay: Duration
    public var maxDelay: Duration
    public var maxJitterMilliseconds: Int

    public init(
        initialDelay: Duration = .seconds(1),
        maxDelay: Duration = .seconds(300),
        maxJitterMilliseconds: Int = 500
    ) {
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.maxJitterMilliseconds = maxJitterMilliseconds
    }

    /// The wait after `failures` failures in a row (one or more), before
    /// jitter.
    public func baseDelay(afterFailures failures: Int) -> Duration {
        var delay = initialDelay
        for _ in 1..<max(failures, 1) where delay < maxDelay {
            delay *= 2
        }
        return min(delay, maxDelay)
    }

    public func delay(afterFailures failures: Int) -> Duration {
        baseDelay(afterFailures: failures) + .milliseconds(Int.random(in: 0...maxJitterMilliseconds))
    }
}
