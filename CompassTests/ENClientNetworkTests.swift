//
//  ENClientNetworkTests.swift
//  CompassTests
//
//  How ENClient copes with a flaky connection. No real network: a stand-in answers
//  every request (StubProtocol), with a fake token.
//

import Foundation
import Testing
@testable import Compass

/// One at a time: the tests share the stand-in's script.
@Suite(.serialized)
struct ENClientNetworkTests {
    private static let supporterCountJSON = #"{"rows":[{"columns":[{"name":"supporterCount","value":"321"}]}]}"#

    private func makeClient() -> ENClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        return ENClient(credentials: ENCredentials(region: .test, token: "fake-token"),
                        session: URLSession(configuration: configuration),
                        retryDelays: [.milliseconds(10), .milliseconds(10)])
    }

    @Test func triesAgainAfterAConnectionFailure() async throws {
        StubProtocol.script.set([.offline, .status(503), .body(Self.supporterCountJSON)])
        #expect(try await makeClient().supporterCount() == 321)
        #expect(StubProtocol.script.requestCount == 3)
    }

    @Test func givesUpAfterThreeTries() async {
        StubProtocol.script.set([.offline, .offline, .offline, .body(Self.supporterCountJSON)])
        await #expect(throws: ENError.network) { try await makeClient().supporterCount() }
        #expect(StubProtocol.script.requestCount == 3)
    }

    @Test func doesNotRetryAnErrorENSentOnPurpose() async {
        StubProtocol.script.set([.body(#"{"error":"Service disabled"}"#), .body(Self.supporterCountJSON)])
        await #expect(throws: ENError.self) { try await makeClient().supporterCount() }
        #expect(StubProtocol.script.requestCount == 1)
    }

    @Test func sameRequestAtTheSameTimeIsSentOnce() async throws {
        StubProtocol.script.set([.body(Self.supporterCountJSON, delay: 0.2), .body(Self.supporterCountJSON)])
        let client = makeClient()
        async let first = client.supporterCount()
        async let second = client.supporterCount()
        #expect(try await first == 321)
        #expect(try await second == 321)
        #expect(StubProtocol.script.requestCount == 1)
    }
}

/// Answers requests from a script instead of the network.
private final class StubProtocol: URLProtocol, @unchecked Sendable {
    enum Step {
        case offline
        case status(Int)
        case body(String, delay: TimeInterval = 0)
    }

    final class Script: @unchecked Sendable {
        private let lock = NSLock()
        private var steps: [Step] = []
        private var count = 0

        func set(_ newSteps: [Step]) {
            lock.withLock { steps = newSteps; count = 0 }
        }

        var requestCount: Int { lock.withLock { count } }

        func next() -> Step {
            lock.withLock {
                count += 1
                return steps.isEmpty ? .offline : steps.removeFirst()
            }
        }
    }

    static let script = Script()

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        func respond(status: Int, body: String) {
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
        switch Self.script.next() {
        case .offline:
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
        case .status(let status):
            respond(status: status, body: "")
        case .body(let body, let delay):
            if delay > 0 { Thread.sleep(forTimeInterval: delay) }
            respond(status: 200, body: body)
        }
    }
}
