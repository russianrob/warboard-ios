import Foundation
import UserNotifications

/// Schedules local "ready" notifications from a Torn dashboard snapshot:
/// energy/nerve full, and drug/booster/medical cooldown end. They're
/// LOCAL + time-triggered, so they fire even when the app is closed — as
/// long as they were (re)scheduled the last time the app was active
/// (BarReporter reschedules on every poll and every foreground).
///
/// Each kind has a stable identifier, so a fresh snapshot replaces (never
/// duplicates) its pending request, and a kind that's already full / off
/// cooldown / toggled off is cancelled rather than left to fire stale.
@MainActor
enum BarNotificationScheduler {
    private struct Item {
        let id: String
        let enabled: Bool
        let title: String
        let body: String
        let seconds: Int   // seconds from now until it fires; <= 0 means "nothing to schedule"
    }

    static func schedule(from snap: TornAPI.DashboardSnapshot, prefs: PrefsStore) {
        guard snap.error == nil else { return }

        let items: [Item] = [
            Item(id: "warboard.bar.energy", enabled: prefs.notifyEnergy,
                 title: "Energy full ⚡️", body: "Your energy bar is full — go spend it.",
                 seconds: snap.energy.current < snap.energy.maximum ? snap.energy.fulltime : 0),
            Item(id: "warboard.bar.nerve", enabled: prefs.notifyNerve,
                 title: "Nerve full 💢", body: "Your nerve bar is full.",
                 seconds: snap.nerve.current < snap.nerve.maximum ? snap.nerve.fulltime : 0),
            Item(id: "warboard.cooldown.drug", enabled: prefs.notifyDrug,
                 title: "Drug cooldown over 💊", body: "You can take a drug again.",
                 seconds: snap.drugSeconds),
            Item(id: "warboard.cooldown.booster", enabled: prefs.notifyBooster,
                 title: "Booster cooldown over 🧪", body: "Your booster cooldown has ended.",
                 seconds: snap.boosterSeconds),
            Item(id: "warboard.cooldown.medical", enabled: prefs.notifyMedical,
                 title: "Medical cooldown over 🏥", body: "Your medical cooldown has ended.",
                 seconds: snap.medicalSeconds),
        ]

        let center = UNUserNotificationCenter.current()
        for item in items {
            // Always clear the previous pending request first, so a fresh
            // snapshot reschedules cleanly and disabled/elapsed kinds vanish.
            center.removePendingNotificationRequests(withIdentifiers: [item.id])
            guard item.enabled, item.seconds > 0 else { continue }

            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            content.categoryIdentifier = "bar_ready"
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(item.seconds), repeats: false
            )
            center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }

    /// Fires a notification a few seconds out so the user can confirm
    /// permissions + delivery from the settings screen.
    static func sendTest() {
        let content = UNMutableNotificationContent()
        content.title = "Warboard test 🔔"
        content.body = "Notifications are working. You'll get alerts like this when your bars fill."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "warboard.test", content: content, trigger: trigger)
        )
    }
}
