import Testing
@testable import TinglanCore

/// Verify timer cancellation and end-of-track state transitions.
@MainActor
@Suite struct SleepTimerTests {

    #if os(macOS)
    @Test func endOfTrackReportsEnterAndLeave() {
        let timer = SleepTimer()
        var seen: [SleepTimer.State] = []
        timer.onStateChange = { seen.append($0) }

        timer.scheduleAtEndOfCurrentTrack()
        #expect(timer.consumeEndOfCurrentTrack())
        #expect(seen == [.endOfCurrentTrack, .inactive])
    }

    @Test func reschedulingTheSameModeIsSilent() {
        let timer = SleepTimer()
        var count = 0
        timer.onStateChange = { _ in count += 1 }

        timer.scheduleAtEndOfCurrentTrack()
        timer.scheduleAtEndOfCurrentTrack()
        #expect(count == 1)
        timer.cancel()
        timer.cancel()
        #expect(count == 2)
    }

    #endif

    @Test func consumingIsOnlyForTheEndOfTrackMode() {
        let timer = SleepTimer()
        timer.schedule(afterMinutes: 30)
        #expect(!timer.consumeEndOfCurrentTrack())
        #expect(timer.state.isActive)
        timer.cancel()
    }
}
