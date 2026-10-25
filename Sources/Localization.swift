import Foundation

enum AppLanguage: String, CaseIterable {
    case system, english = "en", chinese = "zh-Hans"
}

enum Localization {
    static var code: String {
        if let i = CommandLine.arguments.firstIndex(of: "--language"), CommandLine.arguments.indices.contains(i + 1) {
            return CommandLine.arguments[i + 1].hasPrefix("zh") ? "zh-Hans" : "en"
        }
        let saved = UserDefaults.standard.string(forKey: "language") ?? "system"
        if saved == "en" || saved == "zh-Hans" { return saved }
        return (Locale.preferredLanguages.first ?? "en").hasPrefix("zh") ? "zh-Hans" : "en"
    }
    static func text(_ key: String, code: String? = nil) -> String {
        let language = code ?? self.code
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let value = Localization.text(key)
    return args.isEmpty ? value : String(format: value, locale: Locale(identifier: Localization.code), arguments: args)
}

func runLocalizationTests() {
    let root = Bundle.main.resourceURL!
    func table(_ code: String) -> [String: String] {
        let data = try! Data(contentsOf: root.appendingPathComponent("\(code).lproj/Localizable.strings"))
        return try! PropertyListSerialization.propertyList(from: data, format: nil) as! [String: String]
    }
    let en = table("en"), zh = table("zh-Hans")
    precondition(Set(en.keys) == Set(zh.keys), "Language keys must match")
    precondition(!en.isEmpty && !en.values.contains("") && !zh.values.contains(""))
    for key in en.keys {
        let pattern = "%[0-9]*\\$?[ds@]"
        let re = try! NSRegularExpression(pattern: pattern)
        func tokens(_ s: String) -> [String] { re.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { (s as NSString).substring(with: $0.range) }.sorted() }
        precondition(tokens(en[key]!) == tokens(zh[key]!), "Format mismatch: \(key)")
    }
    precondition(zh["away_action"] == "离开" && zh["resume_timer"] == "恢复计时" && zh["restart"] == "重新开始")
    precondition(Localization.text("app_name", code: "en") == "RestLeaf")
    precondition(Localization.text("app_name", code: "zh-Hans") == "歇一会")
    print("PASS: \(en.count) bilingual strings, matching format placeholders and requested labels")
}
