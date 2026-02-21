import Foundation

public enum PlanViewMode: String, Codable, CaseIterable, Sendable {
    case day
    case week
    case month
}

public struct PlanEventRaw: Codable, Equatable, Hashable, Sendable {
    public var title: String
    public var description: String
    public var start: String
    public var end: String
    public var workerTitle: String
    public var worker: String
    public var lessonForm: String
    public var lessonFormShort: String
    public var groupName: String
    public var tokName: String
    public var room: String
    public var lessonStatus: String
    public var lessonStatusShort: String
    public var subject: String
    public var hours: String
    public var color: String
    public var borderColor: String

    public init(
        title: String = "",
        description: String = "",
        start: String = "",
        end: String = "",
        workerTitle: String = "",
        worker: String = "",
        lessonForm: String = "",
        lessonFormShort: String = "",
        groupName: String = "",
        tokName: String = "",
        room: String = "",
        lessonStatus: String = "",
        lessonStatusShort: String = "",
        subject: String = "",
        hours: String = "",
        color: String = "",
        borderColor: String = ""
    ) {
        self.title = title
        self.description = description
        self.start = start
        self.end = end
        self.workerTitle = workerTitle
        self.worker = worker
        self.lessonForm = lessonForm
        self.lessonFormShort = lessonFormShort
        self.groupName = groupName
        self.tokName = tokName
        self.room = room
        self.lessonStatus = lessonStatus
        self.lessonStatusShort = lessonStatusShort
        self.subject = subject
        self.hours = hours
        self.color = color
        self.borderColor = borderColor
    }
}

public struct PlanEventUi: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var startMin: Int
    public var endMin: Int
    public var topPx: Double
    public var heightPx: Double
    public var leftPct: Double
    public var widthPct: Double

    public var title: String
    public var room: String
    public var group: String
    public var startStr: String
    public var endStr: String
    public var tooltip: String
    public var typeClass: String
    public var typeLabel: String
    public var subjectKey: String
    public var teacher: String

    public var isCustomEvent: Bool
    public var customEventType: String?
    public var hasCustomOverlay: Bool
    public var customOverlayLabel: String?
    public var customEventId: String?

    public init(
        startMin: Int = 0,
        endMin: Int = 0,
        topPx: Double = 0,
        heightPx: Double = 0,
        leftPct: Double = 0,
        widthPct: Double = 100,
        title: String = "",
        room: String = "",
        group: String = "",
        startStr: String = "",
        endStr: String = "",
        tooltip: String = "",
        typeClass: String = "",
        typeLabel: String = "",
        subjectKey: String = "",
        teacher: String = "",
        isCustomEvent: Bool = false,
        customEventType: String? = nil,
        hasCustomOverlay: Bool = false,
        customOverlayLabel: String? = nil,
        customEventId: String? = nil
    ) {
        self.startMin = startMin
        self.endMin = endMin
        self.topPx = topPx
        self.heightPx = heightPx
        self.leftPct = leftPct
        self.widthPct = widthPct
        self.title = title
        self.room = room
        self.group = group
        self.startStr = startStr
        self.endStr = endStr
        self.tooltip = tooltip
        self.typeClass = typeClass
        self.typeLabel = typeLabel
        self.subjectKey = subjectKey
        self.teacher = teacher
        self.isCustomEvent = isCustomEvent
        self.customEventType = customEventType
        self.hasCustomOverlay = hasCustomOverlay
        self.customOverlayLabel = customOverlayLabel
        self.customEventId = customEventId
    }

    public var id: String {
        let base = "\(startMin)-\(endMin)-\(title)-\(subjectKey)-\(typeClass)"
        if let customEventId {
            return "\(base)-\(customEventId)"
        }
        return base
    }
}

public struct PlanDayColumn: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var date: String
    public var events: [PlanEventUi]

    public init(date: String = "", events: [PlanEventUi] = []) {
        self.date = date
        self.events = events
    }

    public var id: String {
        date
    }
}

public struct PlanMonthCell: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var date: String
    public var hasPlan: Bool

    public init(date: String = "", hasPlan: Bool = false) {
        self.date = date
        self.hasPlan = hasPlan
    }

    public var id: String {
        date
    }
}

public struct SubjectFilterItem: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var label: String
    public var typeKey: String
    public var typeLabel: String
    public var filterKey: String

    public init(label: String = "", typeKey: String = "", typeLabel: String = "", filterKey: String = "") {
        self.label = label
        self.typeKey = typeKey
        self.typeLabel = typeLabel
        self.filterKey = filterKey
    }

    public var id: String {
        filterKey
    }
}

public struct PlanSearchParams: Codable, Equatable, Hashable, Sendable {
    public var category: String
    public var query: String

    public init(category: String = "number", query: String = "") {
        self.category = category
        self.query = query
    }
}

public struct PlanDebugRequest: Codable, Equatable, Hashable, Sendable {
    public var url: String
    public var httpCode: Int
    public var jsonOk: Bool
    public var jsonCount: Int?

    public init(url: String = "", httpCode: Int = 0, jsonOk: Bool = false, jsonCount: Int? = nil) {
        self.url = url
        self.httpCode = httpCode
        self.jsonOk = jsonOk
        self.jsonCount = jsonCount
    }
}

public struct PlanDebug: Codable, Equatable, Hashable, Sendable {
    public var album: String
    public var view: String
    public var rangeStart: String
    public var rangeEnd: String
    public var entriesTotal: Int
    public var daysWithData: [String]
    public var requests: [PlanDebugRequest]

    public init(
        album: String = "",
        view: String = "",
        rangeStart: String = "",
        rangeEnd: String = "",
        entriesTotal: Int = 0,
        daysWithData: [String] = [],
        requests: [PlanDebugRequest] = []
    ) {
        self.album = album
        self.view = view
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.entriesTotal = entriesTotal
        self.daysWithData = daysWithData
        self.requests = requests
    }
}

public struct PlanResult: Codable, Equatable, Hashable, Sendable {
    public var viewMode: PlanViewMode
    public var currentDate: String
    public var rangeStart: String
    public var rangeEnd: String

    public var dayColumns: [PlanDayColumn]
    public var hasAnyEventsInRange: Bool

    public var monthGrid: [[PlanMonthCell?]]

    public var prevDate: String
    public var nextDate: String
    public var todayDate: String
    public var headerLabel: String

    public var debug: PlanDebug

    public init(
        viewMode: PlanViewMode = .week,
        currentDate: String = "",
        rangeStart: String = "",
        rangeEnd: String = "",
        dayColumns: [PlanDayColumn] = [],
        hasAnyEventsInRange: Bool = false,
        monthGrid: [[PlanMonthCell?]] = [],
        prevDate: String = "",
        nextDate: String = "",
        todayDate: String = "",
        headerLabel: String = "",
        debug: PlanDebug = PlanDebug()
    ) {
        self.viewMode = viewMode
        self.currentDate = currentDate
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.dayColumns = dayColumns
        self.hasAnyEventsInRange = hasAnyEventsInRange
        self.monthGrid = monthGrid
        self.prevDate = prevDate
        self.nextDate = nextDate
        self.todayDate = todayDate
        self.headerLabel = headerLabel
        self.debug = debug
    }
}
