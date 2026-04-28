import Foundation

@MainActor
final class ScheduleMonitor {
    static let shared = ScheduleMonitor()

    private var timer: Timer?

    private init() {
        start()
    }

    private func start() {
        // 对齐到下一个整分钟，然后每 60 秒触发一次
        let now = Date()
        let nextMinute = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(second: 0),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(60)
        let delay = nextMinute.timeIntervalSince(now)

        Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            Task { @MainActor [weak self] in
                self?.tick()
                self?.startRepeating()
            }
        }
    }

    private func startRepeating() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                TriggerStore.shared.evaluateTime()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick() {
        TriggerStore.shared.evaluateTime()
    }
}
