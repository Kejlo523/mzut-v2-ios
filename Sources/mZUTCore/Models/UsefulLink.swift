import Foundation

public enum UsefulLinkScope: String, Codable, Sendable {
    case global = "GLOBAL"
    case faculty = "FACULTY"
    case major = "MAJOR"
    case other = "OTHER"
}

public struct UsefulLink: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var url: String
    public var description: String
    public var scope: UsefulLinkScope
    public var facultyCode: String?
    public var majorCode: String?
    public var priorityWeight: Int
    public var highlight: Bool

    public init(
        id: String,
        title: String,
        url: String,
        description: String,
        scope: UsefulLinkScope,
        facultyCode: String? = nil,
        majorCode: String? = nil,
        priorityWeight: Int = 3,
        highlight: Bool = false
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.description = description
        self.scope = scope
        self.facultyCode = facultyCode
        self.majorCode = majorCode
        self.priorityWeight = priorityWeight
        self.highlight = highlight
    }
}
