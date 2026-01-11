import SwiftUI
import Security

struct KeyringView: View {
    @State private var credentials: [Credential] = []
    @State private var showAddSheet = false
    @State private var selectedCredential: Credential?
    @EnvironmentObject var languageService: LanguageService
    
    var body: some View {
        Group {
            if credentials.isEmpty {
                emptyState
            } else {
                credentialsList
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    showAddSheet = true
                } label: {
                    Label(languageService.s("add_new"), systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddCredentialSheet { credential in
                credentials.append(credential)
                saveCredentials()
            }
        }
        .sheet(item: $selectedCredential) { credential in
            EditCredentialSheet(credential: credential) { updated in
                if let index = credentials.firstIndex(where: { $0.id == updated.id }) {
                    credentials[index] = updated
                    saveCredentials()
                }
            }
        }
        .onAppear {
            loadCredentials()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "key")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(languageService.s("keyring_empty"))
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text(languageService.s("keyring_desc"))
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showAddSheet = true
            } label: {
                Label(languageService.s("add_credential"), systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var credentialsList: some View {
        List {
            ForEach(credentials) { credential in
                CredentialRow(credential: credential)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCredential = credential
                    }
            }
            .onDelete(perform: deleteCredentials)
        }
        .listStyle(.inset)
    }
    
    private func deleteCredentials(at offsets: IndexSet) {
        credentials.remove(atOffsets: offsets)
        saveCredentials()
    }
    
    private func loadCredentials() {
        if let data = UserDefaults.standard.data(forKey: "credentials"),
           let decoded = try? JSONDecoder().decode([Credential].self, from: data) {
            credentials = decoded
        }
    }
    
    private func saveCredentials() {
        if let encoded = try? JSONEncoder().encode(credentials) {
            UserDefaults.standard.set(encoded, forKey: "credentials")
        }
    }
}

struct CredentialRow: View {
    let credential: Credential
    @EnvironmentObject var languageService: LanguageService
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(credential.name)
                    .font(.headline)
                
                Text(credential.username)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .help(languageService.s("edit_credential"))
        }
        .padding(.vertical, 8)
    }
}

struct AddCredentialSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageService: LanguageService
    let onSave: (Credential) -> Void
    
    @State private var name = ""
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 0) {

            HStack {
                Text(languageService.s("new_credential"))
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            

            Form {
                Section {
                    TextField(languageService.s("name_hint"), text: $name)
                    TextField(languageService.s("username"), text: $username)
                    SecureField(languageService.s("password"), text: $password)
                }
            }
            .formStyle(.grouped)
            
            Divider()
            

            HStack {
                Spacer()
                Button(languageService.s("cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button(languageService.s("save")) {
                    let credential = Credential(name: name, username: username, password: password)
                    onSave(credential)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || username.isEmpty || password.isEmpty)
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 400, height: 300)
    }
}

struct EditCredentialSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageService: LanguageService
    let credential: Credential
    let onSave: (Credential) -> Void
    
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    
    var body: some View {
        VStack(spacing: 0) {

            HStack {
                Text(languageService.s("edit_credential"))
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            

            Form {
                Section {
                    TextField(languageService.s("name"), text: $name)
                    TextField(languageService.s("username"), text: $username)
                    SecureField(languageService.s("password"), text: $password)
                }
            }
            .formStyle(.grouped)
            
            Divider()
            

            HStack {
                Spacer()
                Button(languageService.s("cancel")) {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button(languageService.s("save")) {
                    var updated = credential
                    updated.name = name
                    updated.username = username
                    updated.password = password
                    onSave(updated)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || username.isEmpty || password.isEmpty)
                .keyboardShortcut(.return)
            }
            .padding()
        }
        .frame(width: 400, height: 300)
        .onAppear {
            name = credential.name
            username = credential.username
            password = credential.password
        }
    }
}

#Preview {
    KeyringView()
        .environmentObject(LanguageService())
}
