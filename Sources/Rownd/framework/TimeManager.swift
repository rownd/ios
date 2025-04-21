import Foundation
import Get
import OSLog

// Data structure for the World Time API response
struct WorldTimeResponse: Codable {
    let utcDateTime: String

    enum CodingKeys: String, CodingKey {
        case utcDateTime = "utc_datetime"
    }
}

class NetworkTimeManager {
    internal static let shared = NetworkTimeManager()

    private let log = Logger(subsystem: "io.rownd.sdk", category: "TimeManager")
    private var fetchTimeTask: Task<(), Never>?
    private var fetchedWorldTime: Date?
    private var fetchTime: Date?

    internal var currentTime: Date? {
        get {
            guard let fetchedWorldTime = fetchedWorldTime, let fetchTime = fetchTime else {
                log.warning("Network time not available.")
                return nil
            }

            // Calculate the time passed since the world time was fetched
            let timePassed = Date().timeIntervalSince(fetchTime)

            // Add the time passed to the fetched world time to get the current world time
            return fetchedWorldTime.addingTimeInterval(timePassed)
        }
    }

    let client = APIClient(baseURL: URL(string: "https://time.rownd.io"))

    init() {
        let ntpStart = Date()
        Task {
            await fetchWorldTime()

            Task { @MainActor in
                if Context.currentContext.store.state.clockSyncState != .synced {
                    Context.currentContext.store.dispatch(SetClockSync(clockSyncState: .synced))
                }
            }
        }

        Task {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if Context.currentContext.store.state.clockSyncState == .waiting {
                    self.log.warning("TimeManager clock not synced after \(ntpStart.distance(to: Date())) seconds.")
                    Context.currentContext.store.dispatch(SetClockSync(clockSyncState: .unknown))
                }
            }
        }
    }

    // Fetch the current world time and store the initial reference
    func fetchWorldTime() async {
        let task = Task {
            defer { fetchTimeTask = nil }

            do {
                let response: WorldTimeResponse = try await client.send(Request(path: "/now")).value

                // Custom date formatter to handle the response from world time
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSXXXXX" // Supports microseconds and time zone
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)

                if let fetchedDate = formatter.date(from: response.utcDateTime) {
                    // Store the fetched world time and the system time when fetched
                    self.fetchedWorldTime = fetchedDate
                    self.fetchTime = Date()
                } else {
                    log.warning("Error parsing network time")
                }
            } catch {
                log.warning("Error fetching network time: \(error)")
            }
        }

        self.fetchTimeTask = task

        return await task.value
    }

    // Get the current world time without re-fetching
    func getCurrentWorldTime() async -> Date {
        if let fetchTimeTask = fetchTimeTask {
            await fetchTimeTask.value
        }

        if fetchedWorldTime == nil {
            await fetchWorldTime()
        }

        guard let fetchedWorldTime = fetchedWorldTime, let fetchTime = fetchTime else {
            log.warning("Network time not found. Using local time instead")
            return Date()
        }

        // Calculate the time passed since the world time was fetched
        let timePassed = Date().timeIntervalSince(fetchTime)

        // Add the time passed to the fetched world time to get the current world time
        return fetchedWorldTime.addingTimeInterval(timePassed)
    }
}
