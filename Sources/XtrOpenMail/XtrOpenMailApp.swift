import SwiftUI
import MsgKit

@main
struct XtrOpenMailApp: App {
    @StateObject private var vm = MessageViewModel()
    /// Stessa chiave "theme" del toggle della web app; default "sistema" (vedi AppearancePreference).
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system.rawValue

    var body: some Scene {
        WindowGroup("openmail") {
            ContentView()
                .environmentObject(vm)
                .frame(minWidth: 820, minHeight: 520)
                .preferredColorScheme(preference.colorScheme)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Apri .msg...") {
                    NotificationCenter.default.post(name: .openMsgRequested, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("Aspetto") {
                Picker("Tema", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.inline)
                .disabled(AppearancePreference.isManaged)
            }
        }

        Settings {
            SettingsView()
                .preferredColorScheme(preference.colorScheme)
        }
    }

    private var preference: AppearancePreference {
        AppearancePreference(rawValue: appearance) ?? .system
    }
}

/// Impostazioni (⌘,): tema e informazioni sulla privacy utili a chi gestisce i Mac aziendali.
struct SettingsView: View {
    @AppStorage(AppearancePreference.storageKey) private var appearance = AppearancePreference.system.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s4) {
            BrandMark(name: "openmail", size: 18)
            VStack(alignment: .leading, spacing: Theme.s2) {
                MonoLabel("Tema")
                Picker("Tema", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .disabled(AppearancePreference.isManaged)
                if AppearancePreference.isManaged {
                    Text("Impostato dall'amministratore (profilo di configurazione).")
                        .font(.caption).foregroundStyle(Theme.textMuted)
                }
            }
            policySummary
            Callout(kind: .info) {
                MonoLabel("Privacy", color: Theme.info)
                Text("Nessuna connessione di rete. I log di sistema (sottosistema com.xtremealex.openmail) non contengono nomi file ne' contenuti.")
                    .font(.callout)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.s5)
        .frame(width: 460)
        .background(Theme.bg)
    }
}

private extension SettingsView {
    /// Riepilogo della politica aziendale in vigore: chi gestisce i Mac verifica a colpo d'occhio
    /// che il profilo MDM sia stato applicato.
    var policySummary: some View {
        let policy = MsgPolicy.current()
        return VStack(alignment: .leading, spacing: Theme.s2) {
            MonoLabel("Politica aziendale")
            HStack(spacing: Theme.s2) {
                Pill(text: "Limite \(policy.maxFileSizeMB) MB")
                Pill(text: policy.attachmentExportAllowed ? "Allegati: si" : "Allegati: no")
                Pill(text: policy.folderExportAllowed ? "Cartella: si" : "Cartella: no")
            }
        }
    }
}

