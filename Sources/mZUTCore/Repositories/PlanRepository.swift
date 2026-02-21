import Foundation

public actor PlanRepository {
    private struct Keys {
        static let cacheData = "plan_cache_v1_data"
    }

    private struct FullPlanCache: Codable {
        var album: String
        var timestamp: TimeInterval
        var byDate: [String: [PlanEventRaw]]
        var scopeTimestamps: [String: TimeInterval]
    }

    private struct AcademicRange {
        let start: Date
        let end: Date
    }

    private struct TempEvent {
        var startMin: Int
        var endMin: Int
        var topPx: Double
        var heightPx: Double
        var title: String
        var room: String
        var group: String
        var startStr: String
        var endStr: String
        var tooltip: String
        var typeClass: String
        var typeLabel: String
        var subjectKey: String
        var teacher: String
        var lane: Int
        var leftPct: Double
        var widthPct: Double
    }

    private let apiClient: MzutAPIClient
    private let sessionStore: MzutSessionStore
    private let gradesRepository: GradesRepository
    private let customPlanEventRepository: CustomPlanEventRepository
    private let urlSession: URLSession
    private let store: KeyValueStore

    private let calendar = Calendar(identifier: .gregorian)
    private let startHour = 6
    private let endHour = 22
    private let hourHeightPx = 48.0

    private let ymdFormatter: DateFormatter
    private let dayHeaderFormatter: DateFormatter
    private let dayMonthFormatter: DateFormatter
    private let hourMinFormatter: DateFormatter
    private let isoLocalFormatter: DateFormatter
    private let isoOffsetFormatter: ISO8601DateFormatter
    private let isoFractionFormatter: ISO8601DateFormatter

    private var fullPlanCache: FullPlanCache?
    private var cachedAlbum: String?
    private var cachedAlbumStudyId: String?
    private var cachedAlbumTs: Date?

    public init(
        apiClient: MzutAPIClient,
        sessionStore: MzutSessionStore,
        gradesRepository: GradesRepository,
        customPlanEventRepository: CustomPlanEventRepository = CustomPlanEventRepository(),
        urlSession: URLSession = .shared,
        store: KeyValueStore = UserDefaultsStore(suiteName: "mzut_plan")
    ) {
        self.apiClient = apiClient
        self.sessionStore = sessionStore
        self.gradesRepository = gradesRepository
        self.customPlanEventRepository = customPlanEventRepository
        self.urlSession = urlSession
        self.store = store

        let ymd = DateFormatter()
        ymd.locale = Locale(identifier: "en_US_POSIX")
        ymd.calendar = Calendar(identifier: .gregorian)
        ymd.timeZone = .current
        ymd.dateFormat = "yyyy-MM-dd"
        self.ymdFormatter = ymd

        let dayHeader = DateFormatter()
        dayHeader.locale = Locale(identifier: "pl_PL")
        dayHeader.calendar = Calendar(identifier: .gregorian)
        dayHeader.timeZone = .current
        dayHeader.dateFormat = "dd.MM.yyyy (EE)"
        self.dayHeaderFormatter = dayHeader

        let dayMonth = DateFormatter()
        dayMonth.locale = Locale(identifier: "pl_PL")
        dayMonth.calendar = Calendar(identifier: .gregorian)
        dayMonth.timeZone = .current
        dayMonth.dateFormat = "dd.MM"
        self.dayMonthFormatter = dayMonth

        let hourMin = DateFormatter()
        hourMin.locale = Locale(identifier: "en_US_POSIX")
        hourMin.calendar = Calendar(identifier: .gregorian)
        hourMin.timeZone = .current
        hourMin.dateFormat = "HH:mm"
        self.hourMinFormatter = hourMin

        let isoLocal = DateFormatter()
        isoLocal.locale = Locale(identifier: "en_US_POSIX")
        isoLocal.calendar = Calendar(identifier: .gregorian)
        isoLocal.timeZone = .current
        isoLocal.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        self.isoLocalFormatter = isoLocal

        let isoOffset = ISO8601DateFormatter()
        isoOffset.formatOptions = [.withInternetDateTime]
        isoOffset.timeZone = .current
        self.isoOffsetFormatter = isoOffset

        let isoFraction = ISO8601DateFormatter()
        isoFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFraction.timeZone = .current
        self.isoFractionFormatter = isoFraction
    }

    public func loadPlan(viewMode: PlanViewMode, currentDate: Date = Date()) async throws -> PlanResult {
        try await loadPlanInternal(viewMode: viewMode, currentDate: currentDate, forceFullRefresh: false, forceScopeRefresh: false)
    }

    public func loadPlan(
        viewMode: PlanViewMode,
        currentDate: Date,
        forceFullRefresh: Bool,
        forceScopeRefresh: Bool
    ) async throws -> PlanResult {
        try await loadPlanInternal(
            viewMode: viewMode,
            currentDate: currentDate,
            forceFullRefresh: forceFullRefresh,
            forceScopeRefresh: forceScopeRefresh
        )
    }

    public func searchPlan(
        viewMode: PlanViewMode,
        currentDate: Date = Date(),
        search: PlanSearchParams
    ) async -> PlanResult {
        let date = startOfDay(currentDate)
        let (rangeStart, rangeEnd) = resolveRange(viewMode: viewMode, currentDate: date)
        var result = baseResult(viewMode: viewMode, currentDate: date)
        result.rangeStart = ymdString(rangeStart)
        result.rangeEnd = ymdString(rangeEnd)
        result.headerLabel = headerLabel(viewMode: viewMode, currentDate: date, rangeStart: rangeStart, rangeEnd: rangeEnd)

        guard let url = buildSearchURL(search: search, rangeStart: rangeStart, rangeEnd: rangeEnd) else {
            return result
        }

        var debug = PlanDebug(
            album: "",
            view: "\(viewMode.rawValue) (SEARCH)",
            rangeStart: ymdString(rangeStart),
            rangeEnd: ymdString(rangeEnd),
            entriesTotal: 0,
            daysWithData: [],
            requests: []
        )

        let events: [PlanEventRaw]
        do {
            events = try await fetchEvents(url: url, debug: &debug)
        } catch {
            events = []
        }

        let grouped = groupByDay(events)
        let days = enumerateDays(from: rangeStart, to: rangeEnd)

        if viewMode == .month {
            result.monthGrid = buildMonthGrid(monthDate: date, daysWithPlan: Set(grouped.keys))
        } else {
            var hasAny = false
            result.dayColumns = days.map { day in
                let key = ymdString(day)
                let dayEvents = buildDayLayout(grouped[key] ?? [])
                if !dayEvents.isEmpty {
                    hasAny = true
                }
                return PlanDayColumn(date: key, events: dayEvents)
            }
            result.hasAnyEventsInRange = hasAny
        }

        debug.entriesTotal = events.count
        debug.daysWithData = grouped.keys.sorted()
        result.debug = debug
        return result
    }

    public func loadSubjectsForFilter(forceRefresh: Bool = false) async throws -> [SubjectFilterItem] {
        guard let album = try await resolveAlbumNumber() else {
            return []
        }

        let range = resolveCurrentAcademicTermRange(for: Date())
        var debug: PlanDebug? = nil
        let byDate = try await ensureScopeData(
            album: album,
            rangeStart: range.start,
            rangeEnd: range.end,
            scopeName: "filter_current",
            forceScopeRefresh: forceRefresh,
            debug: &debug
        )

        return buildSubjectFilterItems(byDate: byDate, rangeStart: range.start, rangeEnd: range.end)
    }

    public func loadSubjectsForSemester(_ semester: Semester, forceRefresh: Bool = false) async throws -> [SubjectFilterItem] {
        guard let album = try await resolveAlbumNumber() else {
            return []
        }
        guard let range = resolveAcademicRange(for: semester) else {
            return []
        }

        var debug: PlanDebug? = nil
        let byDate = try await ensureScopeData(
            album: album,
            rangeStart: range.start,
            rangeEnd: range.end,
            scopeName: "filter_semester",
            forceScopeRefresh: forceRefresh,
            debug: &debug
        )

        return buildSubjectFilterItems(byDate: byDate, rangeStart: range.start, rangeEnd: range.end)
    }

    public func fetchSearchSuggestions(kind: String, query: String) async -> [String] {
        let normalizedKind = kind.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKind.isEmpty, !normalizedQuery.isEmpty else {
            return []
        }

        var components = URLComponents(string: "https://plan.zut.edu.pl/schedule.php")
        components?.queryItems = [
            URLQueryItem(name: "kind", value: normalizedKind),
            URLQueryItem(name: "query", value: normalizedQuery)
        ]

        guard let url = components?.url else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("mZUT-iOS-Plan/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return []
            }
            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return []
            }

            return rows.compactMap { row in
                let item = JSONHelpers.string(row["item"]).trimmingCharacters(in: .whitespacesAndNewlines)
                return item.isEmpty ? nil : item
            }
        } catch {
            return []
        }
    }

    private func loadPlanInternal(
        viewMode: PlanViewMode,
        currentDate: Date,
        forceFullRefresh: Bool,
        forceScopeRefresh: Bool
    ) async throws -> PlanResult {
        let date = startOfDay(currentDate)
        let (rangeStart, rangeEnd) = resolveRange(viewMode: viewMode, currentDate: date)

        var result = baseResult(viewMode: viewMode, currentDate: date)
        result.rangeStart = ymdString(rangeStart)
        result.rangeEnd = ymdString(rangeEnd)
        result.headerLabel = headerLabel(viewMode: viewMode, currentDate: date, rangeStart: rangeStart, rangeEnd: rangeEnd)

        var debug: PlanDebug? = PlanDebug(
            album: "",
            view: viewMode.rawValue,
            rangeStart: ymdString(rangeStart),
            rangeEnd: ymdString(rangeEnd),
            entriesTotal: 0,
            daysWithData: [],
            requests: []
        )

        guard let album = try await resolveAlbumNumber() else {
            result.debug = debug ?? PlanDebug()
            return result
        }
        debug?.album = album

        if forceFullRefresh {
            do {
                var tempDebug = debug ?? PlanDebug()
                let allEvents = try await fetchFullPlanByAlbum(album: album, debug: &tempDebug)
                let grouped = groupByDay(allEvents)
                fullPlanCache = FullPlanCache(album: album, timestamp: Date().timeIntervalSince1970, byDate: grouped, scopeTimestamps: [:])
                writeCacheToDisk(fullPlanCache)
                debug = tempDebug
            } catch {
                // Continue with scoped refresh fallback.
            }
        }

        let byDate = try await ensureScopeData(
            album: album,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            scopeName: viewMode.rawValue,
            forceScopeRefresh: forceScopeRefresh,
            debug: &debug
        )

        let days = enumerateDays(from: rangeStart, to: rangeEnd)
        var allEntries: [PlanEventRaw] = []
        for day in days {
            allEntries.append(contentsOf: byDate[ymdString(day)] ?? [])
        }

        let groupedInRange = groupByDay(allEntries)
        debug?.entriesTotal = allEntries.count
        debug?.daysWithData = groupedInRange.keys.sorted()

        if viewMode == .month {
            result.monthGrid = buildMonthGrid(monthDate: date, daysWithPlan: Set(groupedInRange.keys))
        } else {
            var hasAny = false
            result.dayColumns = days.map { day in
                let key = ymdString(day)
                var dayEvents = buildDayLayout(groupedInRange[key] ?? [])
                dayEvents = mergeCustomEvents(events: dayEvents, date: day)
                if !dayEvents.isEmpty {
                    hasAny = true
                }
                return PlanDayColumn(date: key, events: dayEvents)
            }
            result.hasAnyEventsInRange = hasAny
        }

        result.debug = debug ?? PlanDebug()
        return result
    }
    private func ensureScopeData(
        album: String,
        rangeStart: Date,
        rangeEnd: Date,
        scopeName: String,
        forceScopeRefresh: Bool,
        debug: inout PlanDebug?
    ) async throws -> [String: [PlanEventRaw]] {
        if fullPlanCache == nil || fullPlanCache?.album != album {
            if let disk = readCacheFromDisk(), disk.album == album {
                fullPlanCache = disk
            } else {
                fullPlanCache = FullPlanCache(
                    album: album,
                    timestamp: Date().timeIntervalSince1970,
                    byDate: [:],
                    scopeTimestamps: [:]
                )
            }
        }

        guard var cache = fullPlanCache else {
            return [:]
        }

        let scopeKey = "\(scopeName):\(ymdString(rangeStart))"
        let now = Date().timeIntervalSince1970
        let lastFetch = cache.scopeTimestamps[scopeKey] ?? 0
        let needsRefresh = forceScopeRefresh || cache.byDate.isEmpty || (now - lastFetch > CachePolicy.planUserScopeTTL)

        if needsRefresh {
            do {
                var tempDebug = debug ?? PlanDebug()
                let fresh = try await fetchPlanRangeByAlbum(
                    album: album,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd,
                    debug: &tempDebug
                )
                debug = tempDebug

                let grouped = groupByDay(fresh)
                for day in enumerateDays(from: rangeStart, to: rangeEnd) {
                    let dayKey = ymdString(day)
                    if let list = grouped[dayKey], !list.isEmpty {
                        cache.byDate[dayKey] = list
                    } else {
                        cache.byDate.removeValue(forKey: dayKey)
                    }
                }

                cache.scopeTimestamps[scopeKey] = now
                cache.timestamp = now
                fullPlanCache = cache
                writeCacheToDisk(cache)
            } catch {
                // Soft fail on network issues and return stale cache.
            }
        }

        return fullPlanCache?.byDate ?? [:]
    }

    private func fetchPlanRangeByAlbum(
        album: String,
        rangeStart: Date,
        rangeEnd: Date,
        debug: inout PlanDebug
    ) async throws -> [PlanEventRaw] {
        let apiStart = calendar.date(byAdding: .day, value: -1, to: startOfDay(rangeStart)) ?? rangeStart
        let apiEnd = calendar.date(byAdding: .day, value: 1, to: startOfDay(rangeEnd)) ?? rangeEnd

        let startIso = isoOffsetFormatter.string(from: apiStart)
        let endIso = isoOffsetFormatter.string(from: apiEnd)

        let primary = "https://plan.zut.edu.pl/schedule_student.php?number=\(percentEscape(album))&start=\(percentEscape(startIso))&end=\(percentEscape(endIso))"

        let rows: [[String: Any]]
        do {
            rows = try await fetchJSONArray(urlString: primary, debug: &debug)
        } catch {
            let fallbackStart = ymdString(apiStart)
            let fallbackEnd = ymdString(apiEnd)
            let fallback = "https://plan.zut.edu.pl/schedule_student.php?number=\(percentEscape(album))&start=\(fallbackStart)&end=\(fallbackEnd)"
            rows = try await fetchJSONArray(urlString: fallback, debug: &debug)
        }

        let fromKey = ymdString(rangeStart)
        let toKey = ymdString(rangeEnd)

        return rows.compactMap(parsePlanEventRaw).filter { event in
            guard event.start.count >= 10 else {
                return false
            }
            let day = String(event.start.prefix(10))
            return day >= fromKey && day <= toKey
        }
    }

    private func fetchFullPlanByAlbum(album: String, debug: inout PlanDebug) async throws -> [PlanEventRaw] {
        let url = "https://plan.zut.edu.pl/schedule_student.php?number=\(percentEscape(album))"
        let rows = try await fetchJSONArray(urlString: url, debug: &debug)
        return rows.compactMap(parsePlanEventRaw)
    }

    private func fetchEvents(url: URL, debug: inout PlanDebug) async throws -> [PlanEventRaw] {
        let rows = try await fetchJSONArray(urlString: url.absoluteString, debug: &debug)
        return rows.compactMap(parsePlanEventRaw)
    }

    private func fetchJSONArray(urlString: String, debug: inout PlanDebug) async throws -> [[String: Any]] {
        guard let url = URL(string: urlString) else {
            throw MzutAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("mZUT-iOS-Plan/1.0", forHTTPHeaderField: "User-Agent")

        var reqDebug = PlanDebugRequest(url: urlString, httpCode: 0, jsonOk: false, jsonCount: nil)

        do {
            let (data, response) = try await urlSession.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            reqDebug.httpCode = code

            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                debug.requests.append(reqDebug)
                throw MzutAPIError.httpError(code: code)
            }

            guard let rows = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                debug.requests.append(reqDebug)
                throw MzutAPIError.invalidJSON
            }

            reqDebug.jsonOk = true
            reqDebug.jsonCount = rows.count
            debug.requests.append(reqDebug)
            return rows
        } catch {
            debug.requests.append(reqDebug)
            throw error
        }
    }

    private func parsePlanEventRaw(_ payload: [String: Any]) -> PlanEventRaw? {
        let start = JSONHelpers.string(payload["start"])
        let end = JSONHelpers.string(payload["end"])
        if start.isEmpty || end.isEmpty {
            return nil
        }

        return PlanEventRaw(
            title: JSONHelpers.string(payload["title"]),
            description: JSONHelpers.string(payload["description"]),
            start: start,
            end: end,
            workerTitle: JSONHelpers.string(payload["worker_title"]),
            worker: JSONHelpers.string(payload["worker"]),
            lessonForm: JSONHelpers.string(payload["lesson_form"]),
            lessonFormShort: JSONHelpers.string(payload["lesson_form_short"]),
            groupName: JSONHelpers.string(payload["group_name"]),
            tokName: JSONHelpers.string(payload["tok_name"]),
            room: JSONHelpers.string(payload["room"]),
            lessonStatus: JSONHelpers.string(payload["lesson_status"]),
            lessonStatusShort: JSONHelpers.string(payload["lesson_status_short"]),
            subject: JSONHelpers.string(payload["subject"]),
            hours: JSONHelpers.string(payload["hours"]),
            color: JSONHelpers.string(payload["color"]),
            borderColor: JSONHelpers.string(payload["borderColor"])
        )
    }

    private func groupByDay(_ events: [PlanEventRaw]) -> [String: [PlanEventRaw]] {
        var byDate: [String: [PlanEventRaw]] = [:]

        for event in events {
            guard let date = parseIsoDate(event.start) else {
                continue
            }
            let dayKey = ymdString(startOfDay(date))
            byDate[dayKey, default: []].append(event)
        }

        for key in byDate.keys {
            byDate[key]?.sort { lhs, rhs in
                guard let leftDate = parseIsoDate(lhs.start), let rightDate = parseIsoDate(rhs.start) else {
                    return false
                }
                return leftDate < rightDate
            }
        }

        return byDate
    }

    private func buildDayLayout(_ rawEvents: [PlanEventRaw]) -> [PlanEventUi] {
        if rawEvents.isEmpty {
            return []
        }

        let calendarStartMin = startHour * 60
        let calendarEndMin = endHour * 60

        var events: [TempEvent] = []

        for event in rawEvents {
            guard let startDate = parseIsoDate(event.start),
                  let endDate = parseIsoDate(event.end) else {
                continue
            }

            let startMin = minutesFromMidnight(startDate)
            let endMin = minutesFromMidnight(endDate)

            if endMin <= calendarStartMin || startMin >= calendarEndMin {
                continue
            }

            let clampedStart = max(startMin, calendarStartMin)
            let clampedEnd = min(endMin, calendarEndMin)
            let duration = max(clampedEnd - clampedStart, 15)
            let offset = clampedStart - calendarStartMin

            let topPx = (Double(offset) / 60.0) * hourHeightPx
            var heightPx = (Double(duration) / 60.0) * hourHeightPx
            if heightPx < 22 {
                heightPx = 22
            }

            let subject = event.subject.isEmpty ? event.title : event.subject
            let shortForm = event.lessonFormShort.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = shortForm.isEmpty ? subject : "\(subject) (\(shortForm))"
            let teacher = !event.workerTitle.isEmpty ? event.workerTitle : event.worker
            let startStr = hourMinFormatter.string(from: startDate)
            let endStr = hourMinFormatter.string(from: endDate)
            let tooltip = "\(title) | \(startStr) - \(endStr)"
                + (event.room.isEmpty ? "" : " | sala: \(event.room)")
                + (event.groupName.isEmpty ? "" : " | grupa: \(event.groupName)")
                + (teacher.isEmpty ? "" : " | \(teacher)")

            let typeKey = resolveFilterTypeKey(event)
            let subjectKey = (!subject.isEmpty && typeKey != nil) ? "\(subject)||\(typeKey!)" : ""

            events.append(
                TempEvent(
                    startMin: startMin,
                    endMin: endMin,
                    topPx: topPx,
                    heightPx: heightPx,
                    title: title,
                    room: event.room,
                    group: event.groupName,
                    startStr: startStr,
                    endStr: endStr,
                    tooltip: tooltip,
                    typeClass: eventTypeClass(event),
                    typeLabel: eventTypeLabel(event),
                    subjectKey: subjectKey,
                    teacher: teacher,
                    lane: 0,
                    leftPct: 0,
                    widthPct: 100
                )
            )
        }

        events.sort {
            if $0.startMin == $1.startMin {
                return $0.endMin < $1.endMin
            }
            return $0.startMin < $1.startMin
        }

        var clusters: [[TempEvent]] = []
        var currentCluster: [TempEvent] = []
        var clusterEnd = Int.min

        for event in events {
            if currentCluster.isEmpty {
                currentCluster = [event]
                clusterEnd = event.endMin
            } else if event.startMin < clusterEnd {
                currentCluster.append(event)
                clusterEnd = max(clusterEnd, event.endMin)
            } else {
                clusters.append(currentCluster)
                currentCluster = [event]
                clusterEnd = event.endMin
            }
        }
        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }

        var laidOut: [TempEvent] = []
        for cluster in clusters {
            var laneEnds: [Int] = []
            var clusterEvents: [TempEvent] = []

            for var event in cluster {
                var assigned = false
                for laneIndex in 0..<laneEnds.count where event.startMin >= laneEnds[laneIndex] {
                    laneEnds[laneIndex] = event.endMin
                    event.lane = laneIndex
                    assigned = true
                    break
                }
                if !assigned {
                    event.lane = laneEnds.count
                    laneEnds.append(event.endMin)
                }
                clusterEvents.append(event)
            }

            let laneCount = max(1, laneEnds.count)
            let laneWidth = 100.0 / Double(laneCount)
            for idx in clusterEvents.indices {
                let lane = clusterEvents[idx].lane
                clusterEvents[idx].leftPct = Double(lane) * laneWidth
                clusterEvents[idx].widthPct = laneWidth
            }

            laidOut.append(contentsOf: clusterEvents)
        }

        return laidOut.map { event in
            return PlanEventUi(
                startMin: event.startMin,
                endMin: event.endMin,
                topPx: event.topPx,
                heightPx: event.heightPx,
                leftPct: event.leftPct,
                widthPct: event.widthPct,
                title: event.title,
                room: event.room,
                group: event.group,
                startStr: event.startStr,
                endStr: event.endStr,
                tooltip: event.tooltip,
                typeClass: event.typeClass,
                typeLabel: event.typeLabel,
                subjectKey: event.subjectKey,
                teacher: event.teacher
            )
        }
    }

    private func mergeCustomEvents(events: [PlanEventUi], date: Date) -> [PlanEventUi] {
        let dateKey = ymdString(date)
        let custom = customPlanEventRepository.getEventsForDate(dateKey)
        if custom.isEmpty {
            return events
        }

        var merged = events
        for customEvent in custom {
            let loweredSubject = customEvent.subjectName.lowercased()
            var matched = false

            for index in merged.indices {
                let title = merged[index].title.lowercased()
                guard !loweredSubject.isEmpty, title.contains(loweredSubject) else {
                    continue
                }

                let typeClass = merged[index].typeClass.lowercased()
                let isLecture = typeClass.contains("lec") || merged[index].title.hasSuffix("(W)")
                let typeMatches = customEvent.eventType == .exam ? isLecture : !isLecture

                var timeMatches = true
                if let customStart = parseTimeMinutes(customEvent.startTime) {
                    timeMatches = customStart == merged[index].startMin
                }

                if typeMatches && timeMatches {
                    merged[index].hasCustomOverlay = true
                    merged[index].customOverlayLabel = customEvent.eventType.shortLabel
                    merged[index].customEventId = String(customEvent.id)
                    merged[index].customEventType = customEvent.eventType.rawValue
                    if !customEvent.notes.isEmpty {
                        merged[index].tooltip = customEvent.notes
                    }
                    matched = true
                    break
                }
            }

            if !matched, let startMin = parseTimeMinutes(customEvent.startTime) {
                let endMin = parseTimeMinutes(customEvent.endTime) ?? (startMin + 90)
                merged.append(
                    PlanEventUi(
                        startMin: startMin,
                        endMin: endMin,
                        topPx: (Double(startMin - startHour * 60) / 60.0) * hourHeightPx,
                        heightPx: (Double(endMin - startMin) / 60.0) * hourHeightPx,
                        leftPct: 0,
                        widthPct: 100,
                        title: customEvent.subjectName,
                        room: "",
                        group: "",
                        startStr: customEvent.startTime,
                        endStr: customEvent.endTime,
                        tooltip: customEvent.notes,
                        typeClass: "custom-\(customEvent.eventType.rawValue)",
                        typeLabel: customEvent.eventType.label,
                        subjectKey: "custom-\(customEvent.id)",
                        teacher: "",
                        isCustomEvent: true,
                        customEventType: customEvent.eventType.rawValue,
                        hasCustomOverlay: false,
                        customOverlayLabel: nil,
                        customEventId: String(customEvent.id)
                    )
                )
            }
        }

        return merged.sorted {
            if $0.startMin == $1.startMin {
                return $0.endMin < $1.endMin
            }
            return $0.startMin < $1.startMin
        }
    }
    private func buildMonthGrid(monthDate: Date, daysWithPlan: Set<String>) -> [[PlanMonthCell?]] {
        let monthStart = startOfMonth(monthDate)
        let monthEnd = endOfMonth(monthDate)

        var grid: [[PlanMonthCell?]] = []
        var week: [PlanMonthCell?] = Array(repeating: nil, count: 7)

        var cursor = monthStart
        var col = dayOfWeekMondayFirst(cursor) - 1

        while cursor <= monthEnd {
            let dateKey = ymdString(cursor)
            week[col] = PlanMonthCell(date: dateKey, hasPlan: daysWithPlan.contains(dateKey))
            col += 1
            if col >= 7 {
                grid.append(week)
                week = Array(repeating: nil, count: 7)
                col = 0
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }

        if week.contains(where: { $0 != nil }) {
            grid.append(week)
        }

        return grid
    }

    private func buildSubjectFilterItems(byDate: [String: [PlanEventRaw]], rangeStart: Date, rangeEnd: Date) -> [SubjectFilterItem] {
        var normalizedToSubject: [String: String] = [:]
        var normalizedToTypes: [String: Set<String>] = [:]

        for day in enumerateDays(from: rangeStart, to: rangeEnd) {
            let dayKey = ymdString(day)
            let events = byDate[dayKey] ?? []
            for event in events {
                let subject = (event.subject.isEmpty ? event.title : event.subject).trimmingCharacters(in: .whitespacesAndNewlines)
                if subject.isEmpty {
                    continue
                }

                guard let typeKey = resolveFilterTypeKey(event) else {
                    continue
                }

                let normalized = normalizeFilterString(subject)
                if normalized.isEmpty {
                    continue
                }

                normalizedToSubject[normalized] = normalizedToSubject[normalized] ?? subject
                normalizedToTypes[normalized, default: []].insert(typeKey)
            }
        }

        let sortedKeys = normalizedToSubject.keys.sorted { lhs, rhs in
            let l = normalizedToSubject[lhs] ?? ""
            let r = normalizedToSubject[rhs] ?? ""
            return l.localizedCaseInsensitiveCompare(r) == .orderedAscending
        }

        var items: [SubjectFilterItem] = []
        for key in sortedKeys {
            guard let subject = normalizedToSubject[key] else {
                continue
            }
            let types = normalizedToTypes[key] ?? []

            if types.contains("lec") {
                items.append(SubjectFilterItem(label: subject, typeKey: "lec", typeLabel: getFilterTypeLabel("lec"), filterKey: "\(subject)||lec"))
            }
            if types.contains("aud") {
                items.append(SubjectFilterItem(label: subject, typeKey: "aud", typeLabel: getFilterTypeLabel("aud"), filterKey: "\(subject)||aud"))
            }
            if types.contains("lab") {
                items.append(SubjectFilterItem(label: subject, typeKey: "lab", typeLabel: getFilterTypeLabel("lab"), filterKey: "\(subject)||lab"))
            }
        }

        return items
    }

    private func resolveAcademicRange(for semester: Semester) -> AcademicRange? {
        let yearRaw = (semester.rokAkademicki ?? "").replacingOccurrences(of: " ", with: "")
        var yearStart: Int?
        var yearEnd: Int?

        if !yearRaw.isEmpty {
            if let slash = yearRaw.firstIndex(of: "/") {
                yearStart = parseAcademicYearValue(String(yearRaw[..<slash]))
                yearEnd = parseAcademicYearValue(String(yearRaw[yearRaw.index(after: slash)...]))
            } else if let single = parseAcademicYearValue(yearRaw) {
                yearStart = single
                yearEnd = single + 1
            }
        }

        let term = normalizeFilterString(semester.pora ?? "")
        var isWinter = term.contains("zim") || term.contains("winter")
        var isSummer = term.contains("let") || term.contains("sum")

        if !isWinter && !isSummer {
            let digits = (semester.nrSemestru ?? "").replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
            if let number = Int(digits), number > 0 {
                isWinter = number % 2 == 1
                isSummer = !isWinter
            }
        }

        if isWinter {
            let startYear = yearStart ?? ((yearEnd ?? calendar.component(.year, from: Date())) - 1)
            let endYear = yearEnd ?? (startYear + 1)
            guard let start = dateFrom(year: startYear, month: 10, day: 1),
                  let february = dateFrom(year: endYear, month: 2, day: 1) else {
                return nil
            }
            return AcademicRange(start: start, end: endOfMonth(february))
        }

        if isSummer {
            let year = yearEnd ?? yearStart ?? calendar.component(.year, from: Date())
            guard let start = dateFrom(year: year, month: 3, day: 1),
                  let end = dateFrom(year: year, month: 9, day: 30) else {
                return nil
            }
            return AcademicRange(start: start, end: end)
        }

        return resolveCurrentAcademicTermRange(for: Date())
    }

    private func resolveCurrentAcademicTermRange(for date: Date) -> AcademicRange {
        let now = startOfDay(date)
        let month = calendar.component(.month, from: now)
        let year = calendar.component(.year, from: now)

        if month >= 10 {
            let start = dateFrom(year: year, month: 10, day: 1) ?? now
            let end = endOfMonth(dateFrom(year: year + 1, month: 2, day: 1) ?? now)
            return AcademicRange(start: start, end: end)
        }

        if month <= 2 {
            let start = dateFrom(year: year - 1, month: 10, day: 1) ?? now
            let end = endOfMonth(dateFrom(year: year, month: 2, day: 1) ?? now)
            return AcademicRange(start: start, end: end)
        }

        let start = dateFrom(year: year, month: 3, day: 1) ?? now
        let end = dateFrom(year: year, month: 9, day: 30) ?? now
        return AcademicRange(start: start, end: end)
    }

    private func resolveAlbumNumber() async throws -> String? {
        let now = Date()

        let snapshot = await MainActor.run {
            (
                userId: sessionStore.userId,
                authKey: sessionStore.authKey,
                studies: sessionStore.studies,
                activeStudy: sessionStore.activeStudy
            )
        }

        guard let userId = snapshot.userId,
              let authKey = snapshot.authKey else {
            return nil
        }

        var studies = snapshot.studies
        if studies.isEmpty {
            studies = try await gradesRepository.loadStudies(forceRefresh: false)
        }
        guard !studies.isEmpty else {
            return nil
        }

        let activeStudyId = Study.normalizeId(snapshot.activeStudy?.przynaleznoscId)
            ?? Study.normalizeId(studies.first?.przynaleznoscId)
        guard let activeStudyId else {
            return nil
        }

        if let cachedAlbum,
           let cachedAlbumStudyId,
           let cachedAlbumTs,
           cachedAlbumStudyId == activeStudyId,
           now.timeIntervalSince(cachedAlbumTs) < CachePolicy.planAlbumTTL {
            return cachedAlbum
        }

        if studies.count == 1,
           let cache = fullPlanCache,
           !cache.album.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cachedAlbum = cache.album
            cachedAlbumStudyId = activeStudyId
            cachedAlbumTs = now
            return cache.album
        }

        let response = try await apiClient.callApi(function: "getStudy", params: [
            "login": userId,
            "token": authKey,
            "przynaleznoscId": activeStudyId
        ])

        let album = JSONHelpers.string(response?["album"]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !album.isEmpty else {
            return nil
        }

        cachedAlbum = album
        cachedAlbumStudyId = activeStudyId
        cachedAlbumTs = now
        return album
    }

    private func buildSearchURL(search: PlanSearchParams, rangeStart: Date, rangeEnd: Date) -> URL? {
        let query = search.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return nil
        }

        let category = search.category.lowercased()
        var queryKey = "number"
        if category.contains("teacher") || category.contains("wyk") {
            queryKey = "teacher"
        } else if category.contains("room") || category.contains("sal") {
            queryKey = "room"
        } else if category.contains("group") || category.contains("grup") {
            queryKey = "group"
        } else if category.contains("subject") || category.contains("przedm") {
            queryKey = "subject"
        }

        let startIso = isoOffsetFormatter.string(from: rangeStart)
        let endIso = isoOffsetFormatter.string(from: endOfDay(rangeEnd))

        var components = URLComponents(string: "https://plan.zut.edu.pl/schedule_student.php")
        components?.queryItems = [
            URLQueryItem(name: queryKey, value: query),
            URLQueryItem(name: "start", value: startIso),
            URLQueryItem(name: "end", value: endIso)
        ]

        return components?.url
    }

    private func eventTypeClass(_ event: PlanEventRaw) -> String {
        let statusShort = event.lessonStatusShort.lowercased()
        let formFull = event.lessonForm.lowercased()
        let formShort = event.lessonFormShort.lowercased()
        let subject = (event.subject.isEmpty ? event.title : event.subject).lowercased()
        let hay = "\(formFull) \(subject)"

        switch statusShort {
        case "e": return "week-event-type-exam"
        case "ez": return "week-event-type-exam-remote"
        case "o": return "week-event-type-cancelled"
        case "r": return "week-event-type-rector"
        case "dz": return "week-event-type-dean"
        case "zz": return "week-event-type-remote"
        default: break
        }

        if hay.contains("egzamin") || formFull.contains("exam") {
            return "week-event-type-exam"
        }
        if hay.contains("odwolane") || hay.contains("odwołane") || formFull.contains("cancelled") {
            return "week-event-type-cancelled"
        }
        if hay.contains("zdalne") || formFull.contains("remote") || formFull.contains("online") {
            return "week-event-type-remote"
        }
        if hay.contains("zaliczenie") || formShort == "zal" || formShort == "zalp" {
            return "week-event-type-pass"
        }
        if hay.contains("laboratorium") || formShort == "l" || formFull.contains("laboratory") {
            return "week-event-type-lab"
        }
        if hay.contains("audytoryjne") || formShort == "a" || formFull.contains("auditory") {
            return "week-event-type-auditory"
        }
        if hay.contains("wyklad") || hay.contains("wykład") || formShort == "w" || formFull.contains("lecture") {
            return "week-event-type-lecture"
        }

        return ""
    }

    private func eventTypeLabel(_ event: PlanEventRaw) -> String {
        switch eventTypeClass(event) {
        case "week-event-type-lecture": return "Wykład"
        case "week-event-type-lab": return "Laboratorium"
        case "week-event-type-auditory": return "Audytoryjne"
        case "week-event-type-exam": return "Egzamin"
        case "week-event-type-pass": return "Zaliczenie"
        case "week-event-type-cancelled": return "Odwołane"
        case "week-event-type-remote": return "Zdalne"
        default: return event.lessonForm
        }
    }

    private func resolveFilterTypeKey(_ event: PlanEventRaw) -> String? {
        let formShort = normalizeFilterString(event.lessonFormShort)
        if formShort == "l" || formShort.contains("lab") { return "lab" }
        if formShort == "a" || formShort.contains("aud") { return "aud" }
        if formShort == "w" || formShort.contains("wyk") || formShort.contains("lec") { return "lec" }

        let typeClass = eventTypeClass(event).lowercased()
        if typeClass.hasSuffix("-lab") { return "lab" }
        if typeClass.hasSuffix("-auditory") { return "aud" }
        if typeClass.hasSuffix("-lecture") { return "lec" }

        let form = normalizeFilterString(event.lessonForm)
        if form.contains("laboratorium") || form.contains("laboratory") { return "lab" }
        if form.contains("audytoryjne") || form.contains("auditory") || form.contains("auditorium") { return "aud" }
        if form.contains("wyklad") || form.contains("lecture") { return "lec" }

        return nil
    }

    private func getFilterTypeLabel(_ typeKey: String) -> String {
        switch typeKey {
        case "lec": return "Wykład"
        case "aud": return "Audytoryjne"
        case "lab": return "Laboratorium"
        default: return ""
        }
    }

    private func parseAcademicYearValue(_ raw: String) -> Int? {
        let digits = raw.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard digits.count >= 4 else {
            return nil
        }
        guard let year = Int(String(digits.prefix(4))), (2000...2100).contains(year) else {
            return nil
        }
        return year
    }

    private func normalizeFilterString(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
    }

    private func readCacheFromDisk() -> FullPlanCache? {
        guard let data = store.data(forKey: Keys.cacheData),
              let cache = try? JSONDecoder().decode(FullPlanCache.self, from: data) else {
            return nil
        }
        return cache
    }

    private func writeCacheToDisk(_ cache: FullPlanCache?) {
        guard let cache else {
            store.removeValue(forKey: Keys.cacheData)
            return
        }
        store.set(try? JSONEncoder().encode(cache), forKey: Keys.cacheData)
    }

    private func baseResult(viewMode: PlanViewMode, currentDate: Date) -> PlanResult {
        let prev: Date
        let next: Date

        switch viewMode {
        case .day:
            prev = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            next = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        case .week:
            prev = calendar.date(byAdding: .day, value: -7, to: currentDate) ?? currentDate
            next = calendar.date(byAdding: .day, value: 7, to: currentDate) ?? currentDate
        case .month:
            prev = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
            next = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }

        return PlanResult(
            viewMode: viewMode,
            currentDate: ymdString(currentDate),
            rangeStart: "",
            rangeEnd: "",
            dayColumns: [],
            hasAnyEventsInRange: false,
            monthGrid: [],
            prevDate: ymdString(prev),
            nextDate: ymdString(next),
            todayDate: ymdString(Date()),
            headerLabel: "",
            debug: PlanDebug()
        )
    }

    private func resolveRange(viewMode: PlanViewMode, currentDate: Date) -> (Date, Date) {
        switch viewMode {
        case .day:
            let day = startOfDay(currentDate)
            return (day, day)
        case .week:
            let monday = startOfWeekMonday(currentDate)
            let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
            return (monday, sunday)
        case .month:
            return (startOfMonth(currentDate), endOfMonth(currentDate))
        }
    }

    private func headerLabel(viewMode: PlanViewMode, currentDate: Date, rangeStart: Date, rangeEnd: Date) -> String {
        switch viewMode {
        case .day:
            return dayHeaderFormatter.string(from: currentDate)
        case .week:
            let end = String(dayHeaderFormatter.string(from: rangeEnd).prefix(10))
            return "\(dayMonthFormatter.string(from: rangeStart)) - \(end)"
        case .month:
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "pl_PL")
            formatter.dateFormat = "LLLL yyyy"
            return formatter.string(from: currentDate).capitalized
        }
    }

    private func startOfWeekMonday(_ date: Date) -> Date {
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2
        return calendar.date(from: components).map(startOfDay) ?? startOfDay(date)
    }

    private func startOfMonth(_ date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components).map(startOfDay) ?? startOfDay(date)
    }

    private func endOfMonth(_ date: Date) -> Date {
        let start = startOfMonth(date)
        let next = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        let previous = calendar.date(byAdding: .day, value: -1, to: next) ?? start
        return startOfDay(previous)
    }

    private func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func endOfDay(_ date: Date) -> Date {
        let start = startOfDay(date)
        let next = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return next.addingTimeInterval(-1)
    }

    private func enumerateDays(from start: Date, to end: Date) -> [Date] {
        var output: [Date] = []
        var cursor = startOfDay(start)
        let target = startOfDay(end)

        while cursor <= target {
            output.append(cursor)
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? cursor
        }

        return output
    }

    private func parseIsoDate(_ text: String) -> Date? {
        if let parsed = isoFractionFormatter.date(from: text) {
            return parsed
        }
        if let parsed = isoOffsetFormatter.date(from: text) {
            return parsed
        }
        return isoLocalFormatter.date(from: text)
    }

    private func parseTimeMinutes(_ text: String) -> Int? {
        let parts = text.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else {
            return nil
        }
        return (hour * 60) + minute
    }

    private func minutesFromMidnight(_ date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func dayOfWeekMondayFirst(_ date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return ((weekday + 5) % 7) + 1
    }

    private func ymdString(_ date: Date) -> String {
        ymdFormatter.string(from: date)
    }

    private func dateFrom(year: Int, month: Int, day: Int) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day)).map(startOfDay)
    }

    private func percentEscape(_ input: String) -> String {
        input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
    }
}
