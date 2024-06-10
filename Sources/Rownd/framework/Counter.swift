import Foundation

class Counter {
    // active count in seconds
    private var count: Int
    private var timer: Timer?

    init() {
        self.count = 0
        start()
    }

    // Function to start the timer
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.count += 1
        }
    }

    // Function to stop the timer
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // Function to reset the count
    func reset() {
        count = 0
    }

    // Function to get the current count
    func getCount() -> Int {
        return count
    }
}
