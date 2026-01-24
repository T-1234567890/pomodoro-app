# System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           POMODORO macOS APP                                │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                          UI LAYER (SwiftUI)                           │ │
│  │                                                                       │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────┐   │ │
│  │  │   Settings   │  │    Tasks     │  │       Calendar           │   │ │
│  │  │   (Always)   │  │  (Always)    │  │  (Requires Permission)   │   │ │
│  │  ├──────────────┤  ├──────────────┤  ├──────────────────────────┤   │ │
│  │  │              │  │              │  │                          │   │ │
│  │  │ Permissions  │  │ Non-blocking │  │ Blocking unavailable     │   │ │
│  │  │ Overview:    │  │ banner when  │  │ state when unauthorized  │   │ │
│  │  │              │  │ Reminders    │  │                          │   │ │
│  │  │ • Notifs  ✓  │  │ unauthorized │  │ "Enable Calendar Access" │   │ │
│  │  │ • Calendar ✗ │  │              │  │ button opens System      │   │ │
│  │  │ • Reminders✗ │  │ Add/Edit/    │  │ Settings                 │   │ │
│  │  │              │  │ Complete/    │  │                          │   │ │
│  │  │ Enable       │  │ Delete       │  │ When authorized:         │   │ │
│  │  │ buttons →    │  │              │  │ - Today view             │   │ │
│  │  │ System       │  │ Menu:        │  │ - Week view              │   │ │
│  │  │ Settings     │  │ • Sync       │  │ - Event details          │   │ │
│  │  │              │  │ • Unsync     │  │                          │   │ │
│  │  └──────────────┘  └──────────────┘  └──────────────────────────┘   │ │
│  │                          ↓                      ↓                     │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                              ↓                      ↓                       │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                      BUSINESS LOGIC LAYER                             │ │
│  │                                                                       │ │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │ │
│  │  │ Permissions      │  │    TodoStore     │  │ CalendarManager  │   │ │
│  │  │ Manager          │  │  (Primary)       │  │   (Separate)     │   │ │
│  │  │ (Singleton)      │  │                  │  │                  │   │ │
│  │  ├──────────────────┤  ├──────────────────┤  ├──────────────────┤   │ │
│  │  │                  │  │                  │  │                  │   │ │
│  │  │ • Check status   │  │ • CRUD ops       │  │ • Fetch events   │   │ │
│  │  │ • Register       │  │ • Persistence    │  │ • Today view     │   │ │
│  │  │   intent         │  │ • Filter         │  │ • Week view      │   │ │
│  │  │ • Open System    │  │ • Always works   │  │ • Auth check     │   │ │
│  │  │   Settings       │  │                  │  │                  │   │ │
│  │  │                  │  │      ↓           │  │                  │   │ │
│  │  │ Status for:      │  │ ┌────────────┐  │  │                  │   │ │
│  │  │ • Notifications  │  │ │ RemindersSync │ │                  │   │ │
│  │  │ • Calendar       │  │ │  (Optional)   │ │                  │   │ │
│  │  │ • Reminders      │  │ └────────────┘  │  │                  │   │ │
│  │  │                  │  │ • Only when     │  │                  │   │ │
│  │  └──────────────────┘  │   authorized    │  └──────────────────┘   │ │
│  │                        │ • Link via ID   │                         │ │
│  │                        │ • Create/Update │                         │ │
│  │                        └──────────────────┘                         │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                              ↓                      ↓                       │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                        DATA & STORAGE LAYER                           │ │
│  │                                                                       │ │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐   │ │
│  │  │   TodoItem       │  │  UserDefaults    │  │   EventKit       │   │ │
│  │  │  (Primary Model) │  │   (Storage)      │  │  (System APIs)   │   │ │
│  │  ├──────────────────┤  ├──────────────────┤  ├──────────────────┤   │ │
│  │  │                  │  │                  │  │                  │   │ │
│  │  │ • id: UUID       │  │ • TodoItem[]     │  │ • EKReminder     │   │ │
│  │  │ • title          │  │   JSON           │  │ • EKEvent        │   │ │
│  │  │ • notes          │  │ • Persists       │  │ • EKCalendar     │   │ │
│  │  │ • isCompleted    │  │   locally        │  │                  │   │ │
│  │  │ • dueDate        │  │ • Always         │  │ Read-only:       │   │ │
│  │  │ • priority       │  │   accessible     │  │ • Calendar events│   │ │
│  │  │ • createdAt      │  │                  │  │                  │   │ │
│  │  │ • modifiedAt     │  │                  │  │ Read/Write:      │   │ │
│  │  │                  │  │                  │  │ • Reminders      │   │ │
│  │  │ Optional:        │  │                  │  │   (when auth)    │   │ │
│  │  │ • remindersId    │◄─┼──────────────────┼──┤                  │   │ │
│  │  │   (for sync)     │  │                  │  │                  │   │ │
│  │  └──────────────────┘  └──────────────────┘  └──────────────────┘   │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐ │
│  │                      SYSTEM INTEGRATION LAYER                         │ │
│  │                                                                       │ │
│  │  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────┐ │ │
│  │  │ UNUserNotification │  │    EKEventStore    │  │  NSWorkspace   │ │ │
│  │  │     Center         │  │                    │  │                │ │ │
│  │  ├────────────────────┤  ├────────────────────┤  ├────────────────┤ │ │
│  │  │                    │  │                    │  │                │ │ │
│  │  │ Notification       │  │ Calendar           │  │ Open System    │ │ │
│  │  │ permissions        │  │ permissions        │  │ Settings       │ │ │
│  │  │                    │  │                    │  │                │ │ │
│  │  │ • .authorized      │  │ Reminders          │  │ Primary UX     │ │ │
│  │  │ • .denied          │  │ permissions        │  │ for all        │ │ │
│  │  │ • .notDetermined   │  │                    │  │ permissions    │ │ │
│  │  │                    │  │ • .authorized      │  │                │ │ │
│  │  │ requestAuth()      │  │ • .denied          │  │                │ │ │
│  │  │ only when          │  │ • .notDetermined   │  │                │ │ │
│  │  │ .notDetermined     │  │                    │  │                │ │ │
│  │  │                    │  │ requestAccess()    │  │                │ │ │
│  │  │                    │  │ only when          │  │                │ │ │
│  │  │                    │  │ .notDetermined     │  │                │ │ │
│  │  └────────────────────┘  └────────────────────┘  └────────────────┘ │ │
│  └───────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘

KEY DESIGN PRINCIPLES:

1. Todo is PRIMARY ────────► TodoItem is source of truth
                               App works without permissions

2. Reminders is OPTIONAL ──► RemindersSync adds convenience
                               Never required for core functionality

3. Calendar is SEPARATE ───► Independent feature for time-based events
                               Does not replace Todo list

4. Permission UX ──────────► System Settings is primary UX
                               Clear status indicators
                               Non-blocking where possible (Tasks)
                               Blocking only when necessary (Calendar)

DATA FLOW:

User Action ──► UI Layer ──► Business Logic ──► Data/Storage ──► System APIs
     ↑                                                               │
     └───────────────────── Feedback ────────────────────────────────┘

PERMISSION FLOW:

Check Status ──► If .notDetermined: requestAccess() (may show prompt)
              └► Else: Open System Settings (primary UX)
                   ↓
              User grants in System Settings
                   ↓
              App refreshes status on activation
                   ↓
              UI updates automatically via @Published

THREAD SAFETY:

All @MainActor ──► UI operations on main thread
                   State updates synchronized
                   No race conditions
```
