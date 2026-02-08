import SwiftUI

struct SettingsView: View {
    @ObservedObject var permissionsManager: PermissionsManager

    var body: some View {
        SettingsPermissionsView(permissionsManager: permissionsManager)
    }
}

#Preview {
    SettingsView(permissionsManager: .shared)
        .environmentObject(AuthViewModel.shared)
}
