# Privacy Policy

**Effective Date:** February 27, 2026  
**Last Updated:** February 27, 2026

---

## Introduction

Pomodoro App ("we," "our," or "the App") is a macOS productivity tool designed to help you focus. This Privacy Policy explains how we collect, use, and protect your information when you use our app and visit our website at https://pomodoro-app.tech.

We are committed to transparency. Because Pomodoro App is open-source, you can verify our privacy practices by reviewing the code at https://github.com/T-1234567890/pomodoro-app.

---

## What This Policy Covers

This policy applies to:

- **The macOS application** (distributed via GitHub Releases, TestFlight, and the App Store)
- **Our website** at https://pomodoro-app.tech

Both are developed as an open-source project under the MIT License.

---

## Information We Collect

### Website

When you visit our website, we collect:

**Information You Provide:**
- Email addresses submitted through Google Forms for TestFlight waitlist and giveaway entry
- GitHub usernames when you interact with our repository (issues, pull requests, discussions)

**Information Collected Automatically:**
- Standard web server data: IP address, browser type, referring page, pages visited
- Public GitHub data: contributor avatars, repository statistics, commit history, issue counts (displayed via GitHub API)
- Browser preferences: language selection and cached contributor data stored in your browser's localStorage (never sent to our servers)

**Third-Party Services:**
- **Google Forms**: Collects email addresses for waitlist management
- **GitHub API**: Displays public repository data
- **Google Fonts**: Provides web typography (may collect browser metadata per Google's privacy policy)

### macOS Application

The app works in two modes:

**Local-Only Mode (Default):**  
All your data stays on your Mac. No account required, no data sent to servers.

**Cloud-Connected Mode (Optional):**  
When you sign in, authentication and optional cloud features become available.

#### Data Stored Locally

The following data is stored on your Mac and never uploaded unless you explicitly enable cloud sync (not currently implemented):

**Preferences (UserDefaults):**
- Timer settings (work duration, break duration, long break interval)
- Audio preferences (ambient noise selection)
- UI preferences (language, onboarding status)
- Session presets

**Task Data (JSON Files):**
- Todo items: title, notes, due date, completion status, priority
- Planning items: tasks and calendar-linked items
- Session records: start time, end time, duration, linked task ID

**Media Files:**
- Locally stored ambient sound files
- Music playback state (Apple Music / Spotify integration)

**Storage Location:**  
`~/Library/Application Support/Pomodoro` and `~/Library/Preferences`, protected by macOS sandboxing.

#### Data Collected When You Sign In (Optional)

**Firebase Authentication** processes:
- Email address
- Password (hashed—we never see your plaintext password)
- User ID (Firebase-generated identifier)
- Authentication tokens (stored in macOS Keychain)

**Google Sign-In** provides:
- Google account email
- Display name
- Profile photo URL

**Feature Gate API:**  
When signed in, the app checks your account tier and AI quota limits:
- User tier status (free, beta, plus, pro, developer)
- AI token quotas (DeepSeek, Gemini Flash remaining tokens)
- Feature entitlements
- Quota reset date

**How It Works:**
1. App sends your Firebase ID token to our backend API
2. Backend verifies the token with Firebase
3. Backend returns your entitlement data
4. App caches this information locally

**System Permissions (Optional):**  
The app requests these permissions only when you use related features:
- **Notifications**: Display focus session alerts (local only)
- **Calendar**: Read calendar events for planning view (read-only via EventKit)
- **Reminders**: Sync tasks with Apple Reminders (read/write via EventKit)

Calendar and Reminders data stay local unless you enable future cloud sync.

---

## How We Use Your Information

**Website:**
- Waitlist emails: Send TestFlight invitations and giveaway notifications (no marketing)
- GitHub data: Acknowledge contributors and display project activity
- Analytics: Understand traffic patterns (no third-party analytics tools)

**macOS App:**
- Authentication: Verify your identity for optional cloud features
- Feature access: Determine which features are available to you
- Local functionality: Power timer, tasks, session tracking, and integrations (all offline-capable)

---

## AI Features (Planned)

The app's code includes references to future AI features:
- AI focus assistant
- AI session suggestions
- AI task writing assistance

**Current Status:** Not implemented. The app checks for AI quotas but makes no AI API calls yet.

**Future Behavior:**  
When AI features launch:
- AI requests will be sent to secure APIs (e.g., Google Gemini, DeepSeek) only when you explicitly use AI features
- Task content may be processed by AI providers acting as data processors
- AI providers will not use your data for model training unless you separately opt in with them
- You will be able to disable AI features in settings

AI features will be opt-in by design.

---

## Cloud Sync (Planned)

The code includes placeholders for optional cloud sync. When implemented:
- Task data may sync to a cloud database (likely Firestore)
- Session history may be backed up to cloud storage
- You will control sync via settings

**Current Status:** Not active. All data stays local.

---

## Third-Party Services

The app uses these services:

**Firebase (Google Cloud):**
- **Firebase Authentication**: Manages sign-in (email, password, Google OAuth)
- **Firebase Core**: SDK initialization
- Data stored on Google Cloud infrastructure
- Acts as a data processor on our behalf
- [Firebase Privacy Policy](https://firebase.google.com/support/privacy)

**Google Sign-In SDK:**
- Handles OAuth authentication
- Processes Google account data
- [Google Privacy Policy](https://policies.google.com/privacy)

**VPS.Town:**
- Infrastructure sponsor (hosts backend API for testing)
- No access to user data

**Data Processing Terms:**  
Firebase and Google Cloud operate under [Google Cloud's Data Processing Terms](https://cloud.google.com/terms/data-processing-addendum).

**Important:** The `GoogleService-Info.plist` file in the public repository is a placeholder for CI/CD. Production builds use a separate, secure Firebase configuration.

---

## What We Don't Do

**No Analytics Tracking:**  
The app does not include:
- Crash reporting SDKs (e.g., Firebase Crashlytics)
- Usage analytics platforms (e.g., Firebase Analytics, Mixpanel)
- Telemetry or behavioral tracking
- User activity monitoring

**No Data Sales:**  
We do not share, sell, or rent your data to advertisers, data brokers, or marketing platforms.

**No Background Access:**  
The app does not access Calendar or Reminders data in the background.

---

## Data Storage & Security

**Website:**
- HTTPS encryption for all pages
- Google Forms encryption for waitlist submissions
- localStorage data stays in your browser

**macOS App:**

**Local Data Protection:**
- macOS sandboxing restricts app access
- Sensitive tokens stored in macOS Keychain (not UserDefaults)
- All local files protected by macOS file permissions

**Network Security:**
- All API requests use HTTPS (TLS 1.2 or higher)
- Firebase SDK enforces certificate pinning
- Authentication tokens expire automatically (ID tokens: 1 hour, refresh tokens: 30 days)

**Third-Party Infrastructure:**
- Firebase/Google Cloud: [Google Cloud Security](https://cloud.google.com/security)
- Backend API: Hosted on secure infrastructure (VPS.Town)

**Security Limitations:**  
No system is 100% secure. While we follow industry best practices, we cannot guarantee absolute security. You are responsible for securing your device (password, FileVault encryption, etc.).

---

## Data Retention

**Website:**
- Waitlist emails: Retained until invitations are sent or you request deletion
- Browser cache: Refreshed every 5 minutes

**macOS App:**

**Local Data:**  
Retained on your device until you:
- Delete items manually
- Clear app data in settings
- Uninstall the app

**Account Data:**
- Authentication data: Retained until you delete your account
- Authentication tokens: Expire automatically (1 hour for ID tokens, 30 days for refresh tokens)
- Feature gate cache: Refreshed every 5 minutes while signed in

**Cloud Data (Future):**  
When cloud sync launches, retention periods will be disclosed in an updated policy.

---

## Data Sharing & Legal Disclosure

We do not sell your personal data.

**We share data only when:**

**Service Providers (Data Processors):**
- Firebase/Google Cloud: Processes authentication and may process future cloud sync data
- Future AI providers: Process AI requests only when you use AI features

**Legal Requirements:**  
We may disclose data if required by law, court order, or legal process to:
- Comply with legal obligations
- Protect our rights or property
- Investigate fraud or security issues

**Business Transfers:**  
If the project is acquired or merged, user data may be transferred to the successor. You will be notified via email and in-app notification.

---

## Your Rights & Control

### Website

**Opt Out of Waitlist:**
- Don't submit your email via the form
- Email support@pomodoro-app.tech to remove your email

**Browser Data:**
- Clear localStorage to remove cached data
- Disable JavaScript to prevent localStorage writes

### macOS App

**Manage Local Data:**
- Delete tasks/sessions: Use in-app delete buttons
- Clear preferences: Settings > Advanced > Reset
- Remove all data: Uninstall the app (deletes `~/Library/Application Support/Pomodoro`)

**Manage Account Data:**
- **Sign out**: Settings > Account > Sign Out
- **Delete account**: Email support@pomodoro-app.tech with your account email. We will:
  - Delete your Firebase Authentication account
  - Remove associated feature gate data
  - Confirm deletion within 7 business days

**Export Your Data:**
- Local data is stored in JSON format. Email support@pomodoro-app.tech for export instructions
- Cloud data export (future): Will be available in settings when cloud sync launches

**Self-Service Deletion:**  
We plan to add in-app account deletion in a future update.

---

## International Users

The app and website are operated from the **United States**. If you are located outside the U.S., your data may be transferred to, stored, and processed in the U.S. and other countries where our service providers operate.

By using the app or website, you consent to this transfer.

### European Users (GDPR Principles)

While Pomodoro App is developed by an independent developer, we aim to respect GDPR principles where applicable:

**Your Rights:**
- **Access**: Request a copy of your data
- **Deletion**: Request deletion of your data
- **Rectification**: Request correction of inaccurate data
- **Portability**: Request export of your data in JSON format
- **Withdraw consent**: Sign out or delete your account

**Legal Basis for Processing:**
- **Contract performance**: Authentication and account management
- **Legitimate interest**: App functionality, security, and improvement
- **Consent**: Optional features (e.g., cloud sync, AI features)

### California Users (CCPA)

California residents have the right to:
- Know what personal information is collected
- Request deletion of personal information
- Opt out of sale of personal information

**We do not sell personal information.**

**Contact:** Email support@pomodoro-app.tech to exercise your rights.

---

## Children's Privacy

Pomodoro App is not directed at children under 13. We do not knowingly collect personal information from children under 13.

If you are a parent or guardian and believe your child under 13 has provided us with personal information, contact us immediately at support@pomodoro-app.tech. We will delete the information within 30 days.

By using the app, you represent that you are at least 13 years old (or the applicable age of digital consent in your jurisdiction).

---

## Changes to This Policy

We may update this Privacy Policy as the app evolves. Changes will be reflected by updating the "Last Updated" date at the top.

**Material Changes:**  
Significant changes (e.g., enabling cloud sync, launching AI features, changing data retention) will be announced via:
- GitHub repository release notes
- In-app notification
- Website banner
- Email (for waitlist subscribers and signed-in users)

**Continued Use:**  
Continued use of the app or website after changes constitutes acceptance of the updated policy. If you do not agree, you may delete your account and uninstall the app.

**Version History:**  
Previous versions of this policy are available in the GitHub repository commit history.

---

## App Store Compliance

This privacy policy complies with Apple App Store requirements and accurately reflects the app's data collection practices as of the "Last Updated" date.

**App Store Privacy Labels:**  
The app's data collection practices are disclosed in the App Store privacy labels section. This policy provides additional detail.

**TestFlight Users:**  
This policy applies to both TestFlight beta builds and App Store production builds.

---

## Contact

For privacy-related questions, data deletion requests, or concerns:

**Email:** support@pomodoro-app.tech  
**GitHub Issues:** https://github.com/T-1234567890/pomodoro-app/issues  
**Website:** https://pomodoro-app.tech

**Response Time:** We will respond to privacy inquiries within 7 business days.

**Data Protection Officer:** As an indie developer project, we do not have a dedicated DPO. Privacy inquiries are handled by the project maintainer.

---

## Summary: What Data We Collect

| Data Type | Website | macOS App (Local) | macOS App (Cloud) | Purpose |
|-----------|---------|-------------------|-------------------|---------|
| Email (waitlist) | ✅ | ❌ | ❌ | TestFlight invites |
| GitHub username | ✅ (public) | ❌ | ❌ | Contributor acknowledgment |
| Browser metadata | ✅ | ❌ | ❌ | Basic analytics |
| Timer preferences | ❌ | ✅ | 🔜 (opt-in) | App functionality |
| Tasks / session history | ❌ | ✅ | 🔜 (opt-in) | Productivity tracking |
| Firebase auth email | ❌ | ✅ (opt-in) | ✅ (if signed in) | Account authentication |
| Calendar / Reminders | ❌ | ✅ (opt-in) | ❌ | System integration |
| AI request data | ❌ | ❌ | 🔜 (opt-in, future) | Smart features |
| Feature gate data | ❌ | ❌ | ✅ (if signed in) | Entitlement verification |

**Legend:**  
✅ Currently implemented  
❌ Not collected  
🔜 Coming soon (not yet implemented)

---

**Thank you for using Pomodoro App and trusting us with your time and focus.**

---

*This privacy policy is based on the actual implementation as of February 27, 2026. For the most up-to-date information, refer to the source code at https://github.com/T-1234567890/pomodoro-app*

*Open-source transparency: Because this project is open-source, you can verify our privacy claims by reviewing the code. If you find discrepancies, please report them via GitHub Issues.*