import Foundation
import Supabase
import Combine

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var isAuthenticated = false
    @Published var isCheckingAuth = true
    @Published var currentUser: User?
    @Published var currentUserRole: String = "user"
    
    private var authStateTask: Task<Void, Never>?
    
    init() {
        Task {
            await checkSession()
            listenToAuthChanges()
        }
    }
    
    func checkSession() async {
        do {
            let session = try await supabase.auth.session
            self.currentUser = session.user
            self.isAuthenticated = true
            await fetchUserRole(userId: session.user.id.uuidString)
        } catch {
            self.isAuthenticated = false
            self.currentUser = nil
            self.currentUserRole = "user"
        }
        self.isCheckingAuth = false
    }
    
    func fetchUserRole(userId: String) async {
        do {
            struct RoleData: Decodable { let role: String? }
            let fetched: [RoleData] = try await supabase
                .from("profiles")
                .select("role")
                .eq("id", value: userId)
                .execute()
                .value
            
            if let role = fetched.first?.role {
                DispatchQueue.main.async {
                    self.currentUserRole = role
                }
            }
        } catch {
            print("Lỗi lấy role: \(error)")
        }
    }
    
    func listenToAuthChanges() {
        authStateTask?.cancel()
        authStateTask = Task {
            for await (event, session) in await supabase.auth.authStateChanges {
                self.currentUser = session?.user
                self.isAuthenticated = (session != nil)
                
                if let userId = session?.user.id.uuidString {
                    await self.fetchUserRole(userId: userId)
                } else {
                    DispatchQueue.main.async {
                        self.currentUserRole = "user"
                    }
                }
            }
        }
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
        self.isAuthenticated = false
        self.currentUser = nil
    }
    
    // Lấy tên hiển thị từ metadata (hoặc trả về mặc định nếu không có)
    var avatarURL: String? {
        guard let metadata = currentUser?.userMetadata else { return nil }
        if case let .string(url) = metadata["avatar_url"] {
            return url
        }
        return nil
    }
    
    func updateDisplayName(_ name: String) async throws {
        guard let userId = currentUser?.id else { return }
        
        // 1. Cập nhật trong auth.users metadata
        let _ = try await supabase.auth.update(
            user: UserAttributes(data: ["display_name": .string(name)])
        )
        
        // 2. Cập nhật trong bảng profiles
        try await supabase
            .from("profiles")
            .update(["display_name": name] as [String: String])
            .eq("id", value: userId.uuidString)
            .execute()
        
        // Cập nhật lại session để lấy metadata mới
        await checkSession()
    }
    
    func updateAvatar(data: Data) async throws {
        guard let userId = currentUser?.id else { return }
        
        let fileName = "\(userId.uuidString)_\(Date().timeIntervalSince1970).jpg"
        let filePath = "avatars/\(fileName)"
        
        // 1. Upload ảnh lên storage (giả sử có bucket tên 'avatars')
        try await supabase.storage
            .from("avatars")
            .upload(
                path: filePath,
                file: data,
                options: FileOptions(cacheControl: "3600", upsert: true)
            )
        
        // 2. Lấy public URL
        let publicURL = try supabase.storage
            .from("avatars")
            .getPublicURL(path: filePath)
        
        let urlString = publicURL.absoluteString
        
        // 3. Cập nhật metadata
        let _ = try await supabase.auth.update(
            user: UserAttributes(data: ["avatar_url": .string(urlString)])
        )
        
        // 4. Cập nhật bảng profiles
        try await supabase
            .from("profiles")
            .update(["avatar_url": urlString] as [String: String])
            .eq("id", value: userId.uuidString)
            .execute()
        
        // Cập nhật lại session
        await checkSession()
    }
    
    var displayName: String {
        guard let metadata = currentUser?.userMetadata else { return "Người dùng" }
        
        // Thử lấy từ metadata (cách an toàn với AnyJSON)
        if case let .string(name) = metadata["display_name"] {
            return name
        }
        if case let .string(name) = metadata["full_name"] {
            return name
        }
        
        // Fallback dùng JSONSerialization
        do {
            let data = try JSONEncoder().encode(metadata)
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let name = dict["display_name"] as? String { return name }
                if let name = dict["full_name"] as? String { return name }
            }
        } catch {
            print("Lỗi parse metadata: \(error)")
        }
        
        return "Người dùng"
    }
    
    var isAdmin: Bool {
        let adminUUID = AppConfig.adminUserId.lowercased()
        let adminEmail = AppConfig.adminEmail.lowercased()
        
        // 1. Kiểm tra bằng ID cho chắc chắn nhất
        if let id = currentUser?.id.uuidString.lowercased(), id == adminUUID {
            return true
        }
        
        // 2. Hoặc kiểm tra bằng email
        if let email = currentUser?.email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), email == adminEmail {
            return true
        }
        
        // 3. Kiểm tra bằng currentUserRole (từ bảng profiles)
        if currentUserRole == "admin" {
            return true
        }
        
        // 4. Hoặc kiểm tra qua userMetadata
        if let metadata = currentUser?.userMetadata {
            if case let .string(role) = metadata["role"], role == "admin" {
                return true
            }
        }
        
        return false
    }
}
