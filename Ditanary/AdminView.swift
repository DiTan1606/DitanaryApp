import SwiftUI
import Supabase

struct AdminView: View {
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Quản lý hệ thống")) {
                    NavigationLink(destination: AdminUserManagerView()) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .foregroundColor(.green)
                            Text("Quản lý tài khoản người dùng")
                        }
                    }

                    NavigationLink(destination: AdminVocabManagerView()) {
                        HStack {
                            Image(systemName: "books.vertical.fill")
                                .foregroundColor(.blue)
                            Text("Quản lý bộ từ vựng")
                        }
                    }
                }
                
                Section(header: Text("Thông báo")) {
                    NavigationLink(destination: AdminBroadcastView()) {
                        HStack {
                            Image(systemName: "megaphone.fill")
                                .foregroundColor(.orange)
                            Text("Gửi thông báo toàn hệ thống")
                        }
                    }
                }
            }
            .navigationTitle("Trang Quản Trị")
        }
    }
}

struct AdminVocabManagerView: View {
    @State private var systemVocabs: [Vocabulary] = []
    @State private var isLoading = false
    @State private var showingAdd = false
    
    // Gom nhóm từ vựng theo topics
    var groupedVocabs: [String: [Vocabulary]] {
        Dictionary(grouping: systemVocabs, by: { 
            if let topic = $0.topics, !topic.trimmingCharacters(in: .whitespaces).isEmpty {
                return topic.trimmingCharacters(in: .whitespaces)
            }
            return "Chưa phân loại"
        })
    }
    
    // Sắp xếp tên chủ đề theo alphabet
    var sortedTopics: [String] {
        groupedVocabs.keys.sorted()
    }
    
    var body: some View {
        Group {
            if isLoading && systemVocabs.isEmpty {
                ProgressView("Đang tải dữ liệu...")
            } else if systemVocabs.isEmpty {
                VStack {
                    Text("Chưa có từ vựng hệ thống nào.")
                        .foregroundColor(.secondary)
                    Button("Thêm từ mới ngay") {
                        showingAdd = true
                    }
                    .padding(.top, 10)
                }
            } else {
                List {
                    ForEach(sortedTopics, id: \.self) { topic in
                        NavigationLink {
                            TopicDetailView(
                                topic: topic,
                                vocabs: groupedVocabs[topic] ?? [],
                                onRefresh: {
                                    Task { await fetchSystemVocabs() }
                                }
                            )
                        } label: {
                            HStack {
                                Text(topic)
                                    .font(.headline)
                                Spacer()
                                let topicVocabs = groupedVocabs[topic] ?? []
                                let uniqueCount = Set(topicVocabs.compactMap { $0.vocab?.trimmingCharacters(in: .whitespaces).lowercased() }).count
                                Text("\(uniqueCount) từ")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                .refreshable {
                    await fetchSystemVocabs()
                }
            }
        }
        .navigationTitle("Từ vựng hệ thống")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAdd = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            await fetchSystemVocabs()
        }
        .sheet(isPresented: $showingAdd) {
            AddVocabView(onComplete: {
                Task { await fetchSystemVocabs() }
            })
        }
    }
    
    func fetchSystemVocabs() async {
        // Admin tạo vocab_list với user_id của admin.
        guard let userId = AuthManager.shared.currentUser?.id.uuidString else { return }
        
        isLoading = true
        do {
            let fetched: [Vocabulary] = try await supabase
                .from("vocab_list")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            DispatchQueue.main.async {
                self.systemVocabs = fetched
                self.isLoading = false
            }
        } catch {
            print("Lỗi tải từ vựng hệ thống: \(error)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }
}

struct AdminUserManagerView: View {
    @State private var profiles: [Profile] = []
    @State private var isLoading = false
    @State private var selectedProfile: Profile? = nil
    
    var body: some View {
        Group {
            if isLoading && profiles.isEmpty {
                ProgressView("Đang tải danh sách...")
            } else if profiles.isEmpty {
                Text("Không có người dùng nào.")
                    .foregroundColor(.secondary)
            } else {
                List {
                    ForEach(profiles) { profile in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.display_name ?? "Chưa có tên")
                                .font(.headline)
                            Text(profile.email ?? "Không có email")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Vai trò: \(profile.role ?? "user")")
                                .font(.caption)
                                .foregroundColor(profile.role == "admin" ? .red : .blue)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedProfile = profile
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task { await deleteUser(profile) }
                            } label: {
                                Label("Xóa", systemImage: "trash")
                            }
                            
                            Button {
                                selectedProfile = profile
                            } label: {
                                Label("Sửa", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                }
                .refreshable {
                    await fetchProfiles()
                }
            }
        }
        .navigationTitle("Quản lý Người dùng")
        .task {
            await fetchProfiles()
        }
        .sheet(item: $selectedProfile) { profile in
            EditUserView(profile: profile, onComplete: {
                Task { await fetchProfiles() }
            })
        }
    }
    
    func fetchProfiles() async {
        isLoading = true
        do {
            let fetched: [Profile] = try await supabase
                .from("profiles")
                .select()
                .order("created_at", ascending: false)
                .execute()
                .value
            
            DispatchQueue.main.async {
                self.profiles = fetched
                self.isLoading = false
            }
        } catch {
            print("Lỗi tải profiles: \(error)")
            DispatchQueue.main.async { self.isLoading = false }
        }
    }
    
    func deleteUser(_ profile: Profile) async {
        do {
            struct DeleteParams: Encodable {
                let target_user_id: String
            }
            try await supabase.rpc("delete_user", params: DeleteParams(target_user_id: profile.id))
                .execute()
            
            DispatchQueue.main.async {
                self.profiles.removeAll { $0.id == profile.id }
            }
        } catch {
            print("Lỗi xoá user: \(error)")
        }
    }
}

struct EditUserView: View {
    @Environment(\.dismiss) var dismiss
    @State var profile: Profile
    var onComplete: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Thông tin User")) {
                    TextField("Tên hiển thị", text: Binding(
                        get: { profile.display_name ?? "" },
                        set: { profile.display_name = $0 }
                    ))
                    
                    Picker("Vai trò", selection: Binding(
                        get: { profile.role ?? "user" },
                        set: { profile.role = $0 }
                    )) {
                        Text("User").tag("user")
                        Text("Admin").tag("admin")
                    }
                }
            }
            .navigationTitle("Sửa thông tin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Lưu") {
                        Task { await saveProfile() }
                    }
                }
            }
        }
    }
    
    func saveProfile() async {
        do {
            struct UpdateData: Encodable {
                let display_name: String
                let role: String
            }
            try await supabase
                .from("profiles")
                .update(UpdateData(display_name: profile.display_name ?? "", role: profile.role ?? "user"))
                .eq("id", value: profile.id)
                .execute()
            
            DispatchQueue.main.async {
                onComplete()
                dismiss()
            }
        } catch {
            print("Lỗi cập nhật: \(error)")
        }
    }
}

struct AdminBroadcastView: View {
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isSending = false
    @State private var statusMessage = ""
    
    var body: some View {
        Form {
            Section(header: Text("Nội dung thông báo")) {
                TextField("Tiêu đề", text: $title)
                TextEditor(text: $content)
                    .frame(minHeight: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            
            Section {
                Button(action: sendBroadcast) {
                    if isSending {
                        ProgressView()
                    } else {
                        Text("Gửi cho tất cả người dùng")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(isSending || title.isEmpty || content.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            
            if !statusMessage.isEmpty {
                Section {
                    Text(statusMessage)
                        .foregroundColor(statusMessage.contains("Thành công") ? .green : .red)
                }
            }
        }
        .navigationTitle("Gửi Thông Báo")
    }
    
    func sendBroadcast() {
        Task {
            isSending = true
            statusMessage = "Đang gửi..."
            
            do {
                // 1. Lấy danh sách tất cả profile
                let fetched: [Profile] = try await supabase
                    .from("profiles")
                    .select()
                    .execute()
                    .value
                
                // 2. Tạo thông báo cho từng người
                for profile in fetched {
                    let notification = Notification(
                        id: UUID().uuidString,
                        user_id: profile.id,
                        title: title,
                        content: content,
                        is_read: false
                    )
                    
                    try await supabase
                        .from("notifications")
                        .insert(notification)
                        .execute()
                }
                
                DispatchQueue.main.async {
                    isSending = false
                    statusMessage = "Thành công! Đã gửi đến \(fetched.count) người dùng."
                    title = ""
                    content = ""
                }
            } catch {
                print("Lỗi gửi broadcast: \(error)")
                DispatchQueue.main.async {
                    isSending = false
                    statusMessage = "Thất bại: \(error.localizedDescription)"
                }
            }
        }
    }
}
