// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import Foundation
import FirebaseCore
import FirebaseFirestore
import GoogleSignInSwift
@preconcurrency import FirebaseAuth
@preconcurrency import GoogleSignIn

enum AuthenticationState {
    case unauthenticated
    case authenticating
    case authenticated
}

enum AuthenticationFlow {
    case login
    case signUp
}

@MainActor
class AuthManager: ObservableObject {
    @Published var name: String = "unkown"
    
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    
    @Published var flow: AuthenticationFlow = .login
    
    @Published var isValid: Bool  = false
    @Published var authenticationState: AuthenticationState = .unauthenticated
    @Published var errorMessage: String = ""
    @Published var user: User?
    @Published var displayName: String = ""
    @Published var photoURL: URL?
    @Published var userID: String = ""
    @Published var itemStore: ItemStore = ItemStore()
    
    init() {
//        registerAuthStateHandler()
        
        $flow
            .combineLatest($email, $password, $confirmPassword)
            .map { flow, email, password, confirmPassword in
                flow == .login
                ? !(email.isEmpty || password.isEmpty)
                : !(email.isEmpty || password.isEmpty || confirmPassword.isEmpty)
            }
            .assign(to: &$isValid)
    }
    
    private var authStateHandler: AuthStateDidChangeListenerHandle?
    
    func registerAuthStateHandler() {
        if authStateHandler == nil {
            authStateHandler = Auth.auth().addStateDidChangeListener { auth, user in
                self.user = user
                self.authenticationState = user == nil ? .unauthenticated : .authenticated
                self.displayName = user?.displayName ?? ""
                self.photoURL = user?.photoURL
            }
        }
    }
    
    func switchFlow() {
        flow = flow == .login ? .signUp : .login
        errorMessage = ""
    }
    
    private func wait() async {
        do {
            print("Wait")
            try await Task.sleep(nanoseconds: 1_000_000_000)
            print("Done")
        }
        catch { }
    }
    
    func reset() {
        flow = .login
        email = ""
        password = ""
        confirmPassword = ""
    }
}

extension AuthManager {
    func signInWithEmailPassword() async -> Bool {
        authenticationState = .authenticating
        do {
            try await Auth.auth().signIn(withEmail: self.email, password: self.password)
            return true
        }
        catch  {
            print(error)
            errorMessage = error.localizedDescription
            authenticationState = .unauthenticated
            return false
        }
    }
    
    func signUpWithEmailPassword() async -> Bool {
        authenticationState = .authenticating
        do  {
            try await Auth.auth().createUser(withEmail: email, password: password)
            return true
        }
        catch {
            print(error)
            errorMessage = error.localizedDescription
            authenticationState = .unauthenticated
            return false
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
        }
        catch {
            print(error)
            errorMessage = error.localizedDescription
        }
    }
    
    func deleteAccount() async -> Bool {
        do {
            try await user?.delete()
            return true
        }
        catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

enum AuthenticationError: Error {
    case tokenError(message: String)
}

extension AuthManager {
    func signInWithGoogle() async -> Bool {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            fatalError("No client ID found in Firebase configuration")
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("There is no root view controller!")
        
            return false
        }
        
        do {
            let userAuthentication = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            let user = userAuthentication.user
            guard let idToken = user.idToken else { throw AuthenticationError.tokenError(message: "ID token missing") }
            let accessToken = user.accessToken
            
            let credential = GoogleAuthProvider.credential(withIDToken: idToken.tokenString,
                                                           accessToken: accessToken.tokenString)
            
            let result = try await Auth.auth().signIn(with: credential)
            let firebaseUser = result.user
            print("User \(firebaseUser.uid) signed in with email \(firebaseUser.email ?? "unknown")")
            
            self.userID = firebaseUser.uid
            authenticationState = .authenticated
            return true
        }
        catch {
            print(error.localizedDescription)
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}

// 제품 관리
public struct Item: Codable, Sendable {
    var itemId: String = UUID().uuidString    // 상품ID
    var name: String        // 상품명
    var category: String    // 카테고리
    var price: Int          // 가격
    var description: String // 상세설명
    var stockQuantity: Int  // 재고수량
    var imageURL: String    // 이미지 URL
    var color: String       // 색상
    var isAvailable: Bool   // 상품상태(품절, 판매중 / Bool)
    
    // price가격을 천 단위 구분
    var formattedPrice: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.groupingSeparator = "," // 천 단위 구분
        if let formattedPrice = numberFormatter.string(from: NSNumber(value: price)) {
            return formattedPrice
        } else {
            return "\(price)"
        }
    }
}

public struct Order: Codable {
    var trackingNumber: String
    var orderDate: Date                // 주문 날짜
    var nickname: String               // 닉네임
    var shippingAddress: String        // 배송지
    var phoneNumber: String            // 전화번호
    var productName: String            // 상품명
    var imageURL: String               // 이미지 URL
    var color: String                  // 색상
    var itemId: String                // 상품ID
    
    var hasAppleCarePlus: Bool         // 애플 케어 플러스 유무
    var quantity: Int                  // 수량
    var unitPrice: Int                 // 단가
    
    var bankName: String               // 은행명
    var accountNumber: String          // 계좌번호
    
    // *수량 + 애플 케어가 true라면 기존 가격에서 10% 더함
    var totalPrice: Int {
        let total = (quantity * unitPrice) + ((quantity/10) * quantity)
        return hasAppleCarePlus ? total : (quantity * unitPrice)
    }
    
    // 날짜 Formatter 생성
    var formattedOrder: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM월 dd일 HH시 mm분"
        return formatter.string(from: orderDate)
    }
}

// 고객ID
struct UserID: Identifiable {
    var id: UUID = UUID() // 고객 아이디
    
    var order: [Order]
    var profileInfo: ProfileInfo
}
// 고객 관리
struct ProfileInfo: Codable {
    var nickname: String               // 닉네임
    var email: String                  // 이메일
    var registrationDate: Date         // 가입날짜
    var recentlyViewedProducts: [String] // 최근 본 제품(상품 ID 리스트)
    
    // 가입 날짜 Formatter 생성
    var formattedRegistration: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM월 dd일 HH시 mm분"
        return formatter.string(from: registrationDate)
    }
}
protocol ItemStoreType {
    func addProduct(_ item: Item, userID: String) async
    func updateProducts(_ item: Item) async
    func loadProducts() async
    func deleteProduct(_ item: Item, userID: String) async
}

@MainActor
public class ItemStore: ObservableObject, ItemStoreType {
    
    @Published private(set) var items: [Item] = []
    
    func addProduct(_ item: Item, userID: String) async {
        items.append(item)
        
        do {
            let db = Firestore.firestore()
            
            // userID 찍힘..
            print("userID: \(userID), itemId: \(item.itemId)")
            
            try await db.collection("Item").document("\(item.itemId)").setData([
                "name": item.name,
                "category": item.category,
                "color": item.color,
                "description": item.description,
                "imageURL": item.imageURL,
                
                "price": item.price,
                "stockQuantity": item.stockQuantity,
                
                "isAvailable": item.isAvailable,
            ])
            
            print("Document successfully written!")
        } catch {
            print("Error writing document: \(error)")
        }
    }
    
    func updateProducts(_ item: Item) async {
        do {
            let db = Firestore.firestore()
            try await db.collection("Item").document("\(item.itemId)").setData([
                "name": item.name,
                "category": item.category,
                "color": item.color,
                "description": item.description,
                "imageURL": item.imageURL,
                
                "price": item.price,
                "stockQuantity": item.stockQuantity,
                
                "isAvailable": item.isAvailable,
            ])
            
            
            print("Document successfully written!")
        } catch {
            print("Error writing document: \(error)")
        }
        for (index, updateItem) in items.enumerated() {
            if updateItem.itemId == item.itemId {
                items[index].name = item.name
                items[index].category = item.category
                items[index].color = item.color
                items[index].description = item.description
                items[index].imageURL = item.imageURL
                
                items[index].price = item.price
                items[index].stockQuantity = item.stockQuantity
                
                items[index].isAvailable = item.isAvailable
                
            }
        }
    }
    func loadProducts() async {
        do{
            let db = Firestore.firestore()
            let snapshots = try await db.collection("Item").getDocuments()
            
            var savedItems: [Item] = []
            
            for document in snapshots.documents {
                let id: String = document.documentID
                
                let docData = document.data()
                let name: String = docData["name"] as? String ?? ""
                let category: String = docData["category"] as? String ?? ""
                let color: String = docData["color"] as? String ?? ""
                let description: String = docData["description"] as? String ?? ""
                let imageURL: String = docData["imageURL"] as? String ?? ""
                
                
                let price: Int = docData["price"] as? Int ?? 0
                let stockQuantity: Int = docData["stockQuantity"] as? Int ?? 0
                
                let isAvailable: Bool = docData["isAvailable"] as? Bool ?? true
                let item: Item = Item(itemId: id,name: name, category: category, price: price, description: description, stockQuantity: stockQuantity, imageURL: imageURL, color: color, isAvailable: isAvailable)
                
                savedItems.append(item)
                print("save Items: \(savedItems)")
            }
            
            self.items = savedItems
            print("items: \(self.items)")
            
        } catch{
            print("\(error)")
        }
    }
    // MARK: 상품 삭제
    func deleteProduct(_ item: Item, userID: String) async {
        do {
            let db = Firestore.firestore()
            
            try await db.collection("User").document(userID).collection("Item").document("\(item.itemId)").delete()
            // 컬렉션에 있는 USER 안에 Item 안에 itemId를 삭제
            print("Document successfully removed!")
            
            
            if let index = items.firstIndex(where: { $0.itemId == item.itemId }) {
                items.remove(at: index)
            }
        } catch {
            print("Error deleting document: \(error)")
        }
    }
    
    //MARK: 상품 카테고리 필터
    func filterByCategory(items: [Item], category: String) {
        self.items = items.filter { $0.category == category }
    }
}

