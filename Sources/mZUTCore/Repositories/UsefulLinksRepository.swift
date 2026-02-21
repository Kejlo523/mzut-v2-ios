import Foundation

public final class UsefulLinksRepository {
    private let links: [UsefulLink]

    public init() {
        self.links = Self.defaultLinks()
    }

    public func loadSortedLinks(studies: [Study]) -> [UsefulLink] {
        var majors = Set<String>()
        var faculties = Set<String>()
        detectUserCodes(from: studies, majors: &majors, faculties: &faculties)

        return links
            .map { link in
                var mutable = link
                mutable.priorityWeight = computeWeight(for: link, majors: majors, faculties: faculties)
                mutable.highlight = mutable.priorityWeight <= 1
                return mutable
            }
            .sorted { lhs, rhs in
                if lhs.priorityWeight != rhs.priorityWeight {
                    return lhs.priorityWeight < rhs.priorityWeight
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
    }

    private func computeWeight(for link: UsefulLink, majors: Set<String>, faculties: Set<String>) -> Int {
        if link.scope == .major,
           let code = link.majorCode,
           majors.contains(code) {
            return 0
        }

        if link.scope == .faculty,
           let code = link.facultyCode,
           faculties.contains(code) {
            return 1
        }

        if link.scope == .global {
            return 2
        }

        return 3
    }

    private func detectUserCodes(from studies: [Study], majors: inout Set<String>, faculties: inout Set<String>) {
        for study in studies {
            let label = study.displayLabel.lowercased()

            if label.contains("informatyka") {
                majors.insert("INF")
                faculties.insert("WI")
            }

            if label.contains("ekonomia") {
                majors.insert("EKO")
                faculties.insert("WNEIZ")
            }

            if label.contains("mechanika") || label.contains("budowa maszyn") {
                majors.insert("MIB")
                faculties.insert("WIMIM")
            }

            if label.contains("elektrotechnika") || label.contains("automatyka") {
                majors.insert("ELE")
                faculties.insert("WE")
            }

            if label.contains("budownictwo") || label.contains("architektura") {
                majors.insert("BUD")
                faculties.insert("WBIA")
            }
        }
    }

    private static func defaultLinks() -> [UsefulLink] {
        [
            UsefulLink(id: "global_plan_zajec", title: "Plan zajec (Rozklad)", url: "https://plan.zut.edu.pl", description: "Aktualny rozklad zajec dla wszystkich kierunkow i grup.", scope: .global),
            UsefulLink(id: "global_usosweb", title: "USOSweb / e-dziekanat", url: "https://usosweb.zut.edu.pl", description: "Oceny, zapisy na przedmioty, platnosci i wnioski.", scope: .global),
            UsefulLink(id: "global_office365", title: "Poczta / Office 365", url: "https://o365.zut.edu.pl", description: "Poczta studencka, Teams, OneDrive.", scope: .global),
            UsefulLink(id: "global_elearning", title: "E-learning ZUT (Moodle)", url: "https://e-edukacja.zut.edu.pl", description: "Kursy online i materialy wykladowe.", scope: .global),
            UsefulLink(id: "global_zut_home", title: "Strona glowna ZUT", url: "https://www.zut.edu.pl", description: "Aktualnosci uczelniane i komunikaty.", scope: .global),
            UsefulLink(id: "global_konto_zut", title: "Zarzadzanie kontem ZUT", url: "https://konto.zut.edu.pl", description: "Zmiana hasla i konfiguracja dostepu.", scope: .global),
            UsefulLink(id: "global_mleg", title: "mLegitymacja", url: "https://mlegitymacja.zut.edu.pl", description: "Aktywacja i przedluzanie mLegitymacji.", scope: .global),
            UsefulLink(id: "global_uci", title: "Pomoc IT (UCI)", url: "https://uci.zut.edu.pl", description: "Instrukcje sieci, VPN i zgloszenia.", scope: .global),
            UsefulLink(id: "global_library", title: "Biblioteka Glowna", url: "https://bg.zut.edu.pl", description: "Katalog ksiazek oraz bazy publikacji.", scope: .global),
            UsefulLink(id: "global_pomoc_materialna", title: "Stypendia i pomoc materialna", url: "https://www.zut.edu.pl/zut-studenci/pomoc-materialna-akademiki-kredyty.html", description: "Regulaminy i terminy stypendiow.", scope: .global),
            UsefulLink(id: "global_osiedle_studenckie", title: "Akademiki (Osiedle Studenckie)", url: "https://osiedlestudenckie.zut.edu.pl", description: "Oplaty, kwaterowanie i regulaminy DS.", scope: .global),
            UsefulLink(id: "global_samorzad", title: "Samorzad Studencki", url: "https://www.samorzad.zut.edu.pl", description: "Wydarzenia, prawa studenta i inicjatywy.", scope: .global),
            UsefulLink(id: "global_biuro_karier", title: "Biuro Karier", url: "https://biurokarier.zut.edu.pl", description: "Oferty pracy, staze i targi.", scope: .global),
            UsefulLink(id: "global_prk_portal", title: "Sylabusy i programy (PRK)", url: "https://prk.zut.edu.pl", description: "Wyszukiwarka sylabusow i programow.", scope: .global),
            UsefulLink(id: "inf_wi_home", title: "Wydzial Informatyki (WI)", url: "https://www.wi.zut.edu.pl", description: "Strona wydzialu i ogloszenia dziekanatu.", scope: .faculty, facultyCode: "WI"),
            UsefulLink(id: "inf_wi_students", title: "WI - Strefa Studenta", url: "https://www.wi.zut.edu.pl/pl/dla-studenta", description: "Plany studiow, dyplomowanie i druki.", scope: .faculty, facultyCode: "WI"),
            UsefulLink(id: "eko_faculty_home", title: "Wydzial Ekonomiczny", url: "https://ekonomia.zut.edu.pl", description: "Aktualnosci wydzialowe i informacje.", scope: .faculty, facultyCode: "WNEIZ"),
            UsefulLink(id: "eko_plany", title: "Wydzial Ekonomiczny - Strefa studenta", url: "https://ekonomia.zut.edu.pl/strona-studentow", description: "Organizacja roku i dokumenty.", scope: .faculty, facultyCode: "WNEIZ"),
            UsefulLink(id: "mech_faculty_home", title: "Wydzial Inzynierii Mechanicznej i Mechatroniki", url: "https://wimim.zut.edu.pl", description: "Strona wydzialu WIMiM.", scope: .faculty, facultyCode: "WIMIM"),
            UsefulLink(id: "we_faculty_home", title: "Wydzial Elektryczny (WE)", url: "https://we.zut.edu.pl", description: "Informacje dla elektrykow i automatykow.", scope: .faculty, facultyCode: "WE"),
            UsefulLink(id: "wbiis_faculty_home", title: "Wydzial Budownictwa i Inzynierii Srodowiska", url: "https://wbiis.zut.edu.pl", description: "Strona wydzialu WBiIS.", scope: .faculty, facultyCode: "WBIA"),
            UsefulLink(id: "wa_faculty_home", title: "Wydzial Architektury", url: "https://wa.zut.edu.pl", description: "Strona wydzialu Architektury.", scope: .faculty, facultyCode: "WBIA")
        ]
    }
}
