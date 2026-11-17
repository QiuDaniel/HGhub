import Foundation

enum Route: Hashable {
    case channel(cate: String, name: String)
    case ranks
    case settings
    case posts
    case post(id: Int)
}
