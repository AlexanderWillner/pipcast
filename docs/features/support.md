# Feedback

The feedback window links to this fork's GitHub Issues through `SupportCoordinator.supportPage`.
It contains the Pipcast app icon, a feedback action and the existing optional reminder preference.
There is no checkout, donation, or funding flow.

The palette menu, About, menu bar and launcher command all use `showSupport()`.
The internal `support` command identifier and stored preference keys remain stable for existing
hotkeys, settings and backups. `openFeedback()` opens GitHub and closes the window.

`SupportReminderStore` retains the existing monthly schedule and user preference. Showing the
window records its anchor; disabling “Remind me to share feedback” stops future reminders.
Reminders only present when `AppCore.canInterruptUser`; they do not interrupt active work.

`SupportWindowView` uses the shared app icon and blue brand colour. Its 460-point window measures
its content height through `AppWindowController`. The button has no default keyboard shortcut.
