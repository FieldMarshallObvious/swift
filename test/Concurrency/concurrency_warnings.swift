// RUN: %target-swift-frontend -strict-concurrency=complete -parse-as-library %s -emit-sil -o /dev/null -verify
// RUN: %target-swift-frontend -strict-concurrency=complete -parse-as-library %s -emit-sil -o /dev/null -verify -enable-upcoming-feature RegionBasedIsolation

// REQUIRES: concurrency
// REQUIRES: asserts

class GlobalCounter {
  var counter: Int = 0
}

let rs = GlobalCounter() // expected-warning {{let 'rs' is not concurrency-safe because it is not either conforming to 'Sendable' or isolated to a global actor; this is an error in the Swift 6 language mode}}

var globalInt = 17 // expected-warning {{var 'globalInt' is not concurrency-safe because it is non-isolated global shared mutable state; this is an error in the Swift 6 language mode}}
// expected-note@-1 {{isolate 'globalInt' to a global actor, or convert it to a 'let' constant and conform it to 'Sendable'}}
// expected-note@-2 2{{var declared here}}


class MyError: Error { // expected-warning{{non-final class 'MyError' cannot conform to 'Sendable'; use '@unchecked Sendable'}}
  var storage = 0 // expected-warning{{stored property 'storage' of 'Sendable'-conforming class 'MyError' is mutable}}
}

func testWarnings() {
  _ = rs
  _ = globalInt // expected-warning{{reference to var 'globalInt' is not concurrency-safe because it involves shared mutable state}}
  globalInt += 1 // expected-warning{{reference to var 'globalInt' is not concurrency-safe because it involves shared mutable state}}
}
