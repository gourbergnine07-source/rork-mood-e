//
//  MoodETests.swift
//  MoodETests
//
//  Created by Rork on July 17, 2026.
//

import Testing
@testable import MoodE

struct MoodETests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

/// The remote update gate compares dotted version strings: getting this
/// wrong would either nag up-to-date users or, worse, block them.
struct AppVersionTests {

    @Test func olderVersionIsAscending() {
        #expect(AppVersion.compare("1.3", "1.4") == .orderedAscending)
        #expect(AppVersion.compare("1.4", "1.4.1") == .orderedAscending)
        #expect(AppVersion.compare("1.9", "1.10") == .orderedAscending)
        #expect(AppVersion.compare("1.9", "2.0") == .orderedAscending)
    }

    @Test func newerOrEqualVersionIsNotAscending() {
        #expect(AppVersion.compare("1.4", "1.4") == .orderedSame)
        // Trailing zeros must not count as a newer release.
        #expect(AppVersion.compare("1.4", "1.4.0") == .orderedSame)
        #expect(AppVersion.compare("1.5", "1.4") == .orderedDescending)
        #expect(AppVersion.compare("1.10", "1.9") == .orderedDescending)
    }

    @Test func malformedRemoteValuesAreRejected() {
        // A typo in the remote config must never trigger the notice.
        #expect(AppVersion.isValid("1.4"))
        #expect(AppVersion.isValid("1.4.2"))
        #expect(!AppVersion.isValid(""))
        #expect(!AppVersion.isValid("1.4-beta"))
        #expect(!AppVersion.isValid("latest"))
    }
}
