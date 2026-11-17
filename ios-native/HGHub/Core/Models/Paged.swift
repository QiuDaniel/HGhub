import Foundation

struct Pagination: Decodable, Sendable, Hashable {
    let page: Int
    let pages: Int
    let size: Int
    let total: Int

    init(page: Int, pages: Int, size: Int, total: Int) {
        self.page = page
        self.pages = pages
        self.size = size
        self.total = total
    }

    enum CodingKeys: String, CodingKey {
        case page
        case pages
        case size
        case total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
        pages = try container.decodeIfPresent(Int.self, forKey: .pages) ?? 1
        size = try container.decodeIfPresent(Int.self, forKey: .size) ?? 20
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
    }
}

/// 上游分页响应的统一形状：`{ items: [...], pagination: {...} }`
struct Paged<Item: Decodable & Sendable>: Decodable, Sendable {
    let items: [Item]
    let pagination: Pagination

    enum CodingKeys: String, CodingKey {
        case items
        case pagination
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let items = try container.decodeIfPresent([Item].self, forKey: .items) ?? []
        self.items = items
        self.pagination = try container.decodeIfPresent(Pagination.self, forKey: .pagination)
            ?? Pagination(page: 1, pages: 1, size: items.count, total: items.count)
    }
}
