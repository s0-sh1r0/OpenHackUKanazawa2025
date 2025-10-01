import SwiftUI
import Foundation

// 問題のデータモデル
struct Question: Identifiable, Codable {
    let id: UUID
    let questions: [MultipleQuestion]
    let answer: String
    let category: String

    init(id: UUID = UUID(), questions: [MultipleQuestion], answer: String, category: String) {
        self.id = id
        self.questions = questions
        self.answer = answer
        self.category = category
    }

    private enum CodingKeys: String, CodingKey {
        case id, questions, answer, category
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id        = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.questions  = try c.decode([MultipleQuestion].self, forKey: .questions)
        self.answer    = try c.decode(String.self, forKey: .answer)
        self.category  = try c.decode(String.self, forKey: .category)
    }
}

// 1つの答えに対する複数の問題文データモデル
struct MultipleQuestion: Identifiable, Codable {
    let id: UUID
    let question: String
    let choices: [String]?
    let explain: String

    init(id: UUID = UUID(), question: String, choices: [String]? = nil, explain: String) {
        self.id = id
        self.question = question
        self.choices = choices
        self.explain = explain
    }

    private enum CodingKeys: String, CodingKey {
        case id, question, choices, explain
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id       = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.question = try c.decode(String.self, forKey: .question)
        self.choices  = try c.decodeIfPresent([String].self, forKey: .choices)
        self.explain  = try c.decode(String.self, forKey: .explain)
    }
}


// 問題集のデータモデル
struct QuizCategory: Identifiable, Codable {
    let id: UUID
    let name: String
    let iconName: String
    let primaryColorData: CodableColor
    let secondaryColorData: CodableColor
    var questions: [Question]
    let questionType: QuestionType
    
    init(
        id: UUID = UUID(),
        name: String,
        iconName: String,
        primaryColor: Color,
        secondaryColor: Color,
        questions: [Question],
        questionType: QuestionType
    ) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.primaryColorData = CodableColor(color: primaryColor)
        self.secondaryColorData = CodableColor(color: secondaryColor)
        self.questions = questions
        self.questionType = questionType
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, iconName, primaryColorData, secondaryColorData, questions, questionType
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try c.decode(String.self, forKey: .name)
        self.iconName = try c.decode(String.self, forKey: .iconName)
        self.primaryColorData = try c.decode(CodableColor.self, forKey: .primaryColorData)
        self.secondaryColorData = try c.decode(CodableColor.self, forKey: .secondaryColorData)
        self.questions = try c.decode([Question].self, forKey: .questions)
        self.questionType = try c.decode(QuestionType.self, forKey: .questionType)
    }
    
    var primaryColor: Color { primaryColorData.color }
    var secondaryColor: Color { secondaryColorData.color }
}

// 問題集の種類を定義
enum QuestionType: String, Codable, CaseIterable {
    case freeText = "記述式問題"
    case multipleChoice = "4択問題"
    case fillInTheBlankMultipleChoice = "穴埋め4択問題"
    case fillInTheBlankFreeText = "記述式穴埋め問題"
    
}

// ユーザーの回答記録
struct UserAnswer: Identifiable {
    let id = UUID()
    let questionId: UUID
    let subQuestionId: UUID?
    let userAnswer: String
    let isCorrect: Bool
    let timestamp: Date
    
    init(questionId: UUID,
         subQuestionId: UUID? = nil,
         userAnswer: String,
         isCorrect: Bool) {
        self.questionId = questionId
        self.subQuestionId = subQuestionId
        self.userAnswer = userAnswer
        self.isCorrect = isCorrect
        self.timestamp = Date()
    }
}


// クイズの進行状態を管理するモデル
class QuizManager: ObservableObject {
    private let categoriesKey = "quizCategories"

    
    @Published var categories: [QuizCategory] = []
    @Published var userAnswers: [UserAnswer] = []
    
    init() {
        loadCategories()
    }
    
    func saveCategories() {
        if let encoded = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(encoded, forKey: categoriesKey)
        }
    }
    
    func loadCategories() {
        if let savedCategoriesData = UserDefaults.standard.data(forKey: categoriesKey) {
            if let decodedCategories = try? JSONDecoder().decode([QuizCategory].self, from: savedCategoriesData) {
                categories = decodedCategories
                return
            }
        }
        // UserDefaultsにデータがない場合はサンプルデータをロード
        loadSampleData()
    }
    
    func addQuestions(_ questions: [Question], to categoryId: UUID) {
        if let index = categories.firstIndex(where: { $0.id == categoryId }) {
            categories[index].questions.append(contentsOf: questions)
            saveCategories()
        }
    }
    
    func deleteQuestion(_ questionId: UUID, from categoryId: UUID) {
        if let index = categories.firstIndex(where: { $0.id == categoryId }) {
            categories[index].questions.removeAll { $0.id == questionId }
            saveCategories()
        }
    }
    
    func addCategory(_ category: QuizCategory) {
        self.categories.append(category)
        self.saveCategories()
    }

    func deleteCategory(at index: Int) {
        if index < self.categories.count {
            self.categories.remove(at: index)
            self.saveCategories()
        }
    }

    func deleteCategory(withId id: UUID) {
        self.categories.removeAll { $0.id == id }
        self.saveCategories()
    }
    
    func addSubQuestion(_ text: String,
                        choices: [String]? = nil,
                        explain: String = "解説なし",
                        to questionId: UUID,
                        in categoryId: UUID) {
        guard let catIndex = categories.firstIndex(where: { $0.id == categoryId }),
              let qIndex = categories[catIndex].questions.firstIndex(where: { $0.id == questionId }) else {
            return
        }
        let oldQ = categories[catIndex].questions[qIndex]
        var newPrompts = oldQ.questions
        newPrompts.append(MultipleQuestion(question: text, choices: choices, explain: explain))

        let updated = Question(id: oldQ.id,
                               questions: newPrompts,
                               answer: oldQ.answer,
                               category: oldQ.category)
        categories[catIndex].questions[qIndex] = updated
        saveCategories()
    }
    
    func clearUserAnswers(for questionIDs: Set<UUID>) {
        userAnswers.removeAll { ua in questionIDs.contains(ua.questionId) }
    }
    
    private func loadSampleData() {
        // 日本史（1問1答）
        let historyQuestions = [
            Question(questions: [MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？",
                                                  explain: "鎌倉幕府の初代将軍である源氏の武将。")],
                     answer: "源頼朝", category: "日本史"),
            Question(questions: [MultipleQuestion(question: "1603年に江戸幕府を開いた人物は？",
                                                  explain: "徳川家が約260年の江戸時代を築いた。")],
                     answer: "徳川家康", category: "日本史"),
            Question(questions: [MultipleQuestion(question: "1868年に始まった新しい時代の名前は？",
                                                  explain: "明治維新により近代国家への改革が始まった。")],
                     answer: "明治時代", category: "日本史"),
            Question(questions: [MultipleQuestion(question: "1467年から始まった戦乱の時代を何と呼ぶ？",
                                                  explain: "応仁の乱を契機として約100年にわたる戦乱期。")],
                     answer: "戦国時代", category: "日本史"),
            Question(questions: [MultipleQuestion(question: "794年に平安京に都を移した天皇は？",
                                                  explain: "長岡京から平安京へ遷都した。")],
                     answer: "桓武天皇", category: "日本史")
        ]

        // 日本史（同義の別表現パターン：記述）
        let history2Questions = [
            Question(questions: [
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン1）",
                                 explain: "問の言い回しを変えた同義パターン。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン2）",
                                 explain: "同義パターン2。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン3）",
                                 explain: "同義パターン3。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン4）",
                                 explain: "同義パターン4。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン5）",
                                 explain: "同義パターン5。")
            ], answer: "源頼朝", category: "日本史")
        ]

        // 日本史（4択）
        let history3Questions = [
            Question(questions: [
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？",
                                 choices: ["源頼朝","足利尊氏","北条政子","平清盛"],
                                 explain: "正解は源頼朝。鎌倉幕府初代将軍。")
            ], answer: "源頼朝", category: "日本史")
        ]

        // 日本史（4択・複数パターン）
        let history4Questions = [
            Question(questions: [
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン1）",
                                 choices: ["源頼朝","足利尊氏1","北条政子1","平清盛1"],
                                 explain: "源頼朝が正解。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン2）",
                                 choices: ["源頼朝","足利尊氏2","北条政子2","平清盛2"],
                                 explain: "源頼朝が正解。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン3）",
                                 choices: ["源頼朝","足利尊氏3","北条政3","平清盛3"],
                                 explain: "源頼朝が正解。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン4）",
                                 choices: ["源頼朝","足利尊氏4","北条政子4","平清盛4"],
                                 explain: "源頼朝が正解。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン5）",
                                 choices: ["源頼朝","足利尊氏5","北条政子5","平清盛5"],
                                 explain: "源頼朝が正解。")
            ], answer: "源頼朝", category: "日本史")
        ]

        // 日本史（4択・別問含む）
        let history5Questions = [
            Question(questions: [
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン1）",
                                 choices: ["源頼朝","足利尊氏1","北条政子1","平清盛1"],
                                 explain: "源頼朝が正解。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン2）",
                                 choices: ["源頼朝","足利尊氏2","北条政子2","平清盛2"],
                                 explain: "源頼朝が正解。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン3）",
                                 choices: ["源頼朝","足利尊氏3","北条政3","平清盛3"],
                                 explain: "源頼朝が正解。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン4）",
                                 choices: ["源頼朝","足利尊氏4","北条政子4","平清盛4"],
                                 explain: "源頼朝が正解。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？（パターン5）",
                                 choices: ["源頼朝","足利尊氏5","北条政子5","平清盛5"],
                                 explain: "源頼朝が正解。")
            ], answer: "源頼朝", category: "日本史"),
            Question(questions: [
                MultipleQuestion(question: "1603年に江戸幕府を開いた人物は？（パターン1）",
                                 choices: ["徳川家康","足利尊氏1","北条政子1","平清盛1"],
                                 explain: "徳川家康が正解。"),
                MultipleQuestion(question: "1603年に江戸幕府を開いた人物は？（パターン2）",
                                 choices: ["徳川家康","足利尊氏2","北条政子2","平清盛2"],
                                 explain: "徳川家康が正解。"),
                MultipleQuestion(question: "1603年に江戸幕府を開いた人物は？（パターン3）",
                                 choices: ["徳川家康","足利尊氏3","北条政3","平清盛3"],
                                 explain: "徳川家康が正解。"),
                MultipleQuestion(question: "1603年に江戸幕府を開いた人物は？（パターン4）",
                                 choices: ["徳川家康","足利尊氏4","北条政子4","平清盛4"],
                                 explain: "徳川家康が正解。"),
                MultipleQuestion(question: "1603年に江戸幕府を開いた人物は？（パターン5）",
                                 choices: ["徳川家康","足利尊氏5","北条政子5","平清盛5"],
                                 explain: "徳川家康が正解。")
            ], answer: "徳川家康", category: "日本史")
        ]

        // 世界史
        let worldHistoryQuestions = [
            Question(questions: [MultipleQuestion(question: "1789年に始まったフランスの革命は？",
                                                  explain: "人権宣言などを生んだフランス革命。")],
                     answer: "フランス革命", category: "世界史"),
            Question(questions: [MultipleQuestion(question: "1492年にアメリカ大陸を発見した人物は？",
                                                  explain: "コロンブスが到達した。")],
                     answer: "コロンブス", category: "世界史"),
            Question(questions: [MultipleQuestion(question: "古代エジプトの王を何と呼ぶ？",
                                                  explain: "古代エジプトの君主はファラオ。")],
                     answer: "ファラオ", category: "世界史"),
            Question(questions: [MultipleQuestion(question: "1914年から1918年まで続いた戦争は？",
                                                  explain: "ヨーロッパを中心に世界規模で展開。")],
                     answer: "第一次世界大戦", category: "世界史"),
            Question(questions: [MultipleQuestion(question: "古代ギリシャの哲学者で「哲学の父」と呼ばれるのは？",
                                                  explain: "西洋哲学の基礎を築いた人物。")],
                     answer: "ソクラテス", category: "世界史")
        ]

        // 世界史（パターン）
        let worldHistory2Questions = [
            Question(questions: [
                MultipleQuestion(question: "1789年に始まったフランスの革命は？（パターン1）",
                                 explain: "同義パターン1。"),
                MultipleQuestion(question: "1789年に始まったフランスの革命は？（パターン2）",
                                 explain: "同義パターン2。"),
                MultipleQuestion(question: "1789年に始まったフランスの革命は？（パターン3）",
                                 explain: "同義パターン3。")
            ], answer: "フランス革命", category: "世界史"),
        ]

        // 地理
        let geographyQuestions = [
            Question(questions: [MultipleQuestion(question: "日本で最も高い山は？",
                                                  explain: "標高3776m。静岡県と山梨県に跨る。")],
                     answer: "富士山", category: "地理"),
            Question(questions: [MultipleQuestion(question: "世界で最も長い川は？",
                                                  explain: "一般にナイル川とされる。")],
                     answer: "ナイル川", category: "地理"),
            Question(questions: [MultipleQuestion(question: "オーストラリアの首都は？",
                                                  explain: "シドニーやメルボルンではなくキャンベラ。")],
                     answer: "キャンベラ", category: "地理"),
            Question(questions: [MultipleQuestion(question: "世界で最も大きな砂漠は？",
                                                  explain: "北アフリカに広がる砂漠。")],
                     answer: "サハラ砂漠", category: "地理"),
            Question(questions: [MultipleQuestion(question: "日本の最南端の県は？",
                                                  explain: "琉球諸島を含む。")],
                     answer: "沖縄県", category: "地理")
        ]

        // 英単語
        let englishQuestions = [
            Question(questions: [MultipleQuestion(question: "「美しい」を英語で言うと？",
                                                  explain: "形容詞。例: a beautiful day")],
                     answer: "beautiful", category: "英単語"),
            Question(questions: [MultipleQuestion(question: "「重要な」を英語で言うと？",
                                                  explain: "形容詞。例: an important notice")],
                     answer: "important", category: "英単語"),
            Question(questions: [MultipleQuestion(question: "「困難な」を英語で言うと？",
                                                  explain: "形容詞。例: a difficult problem")],
                     answer: "difficult", category: "英単語"),
            Question(questions: [MultipleQuestion(question: "「興味深い」を英語で言うと？",
                                                  explain: "形容詞。例: an interesting book")],
                     answer: "interesting", category: "英単語"),
            Question(questions: [MultipleQuestion(question: "「必要な」を英語で言うと？",
                                                  explain: "形容詞。例: necessary documents")],
                     answer: "necessary", category: "英単語")
        ]

        categories = [
            QuizCategory(
                name: "日本史",
                iconName: "building.columns",
                primaryColor: .red,
                secondaryColor: .orange,
                questions: historyQuestions,
                questionType: .freeText
            ),
            QuizCategory(
                name: "日本史2",
                iconName: "building.columns",
                primaryColor: .red,
                secondaryColor: .orange,
                questions: history2Questions,
                questionType: .freeText
            ),
            QuizCategory(
                name: "日本史3",
                iconName: "building.columns",
                primaryColor: .red,
                secondaryColor: .orange,
                questions: history3Questions,
                questionType: .multipleChoice
            ),
            QuizCategory(
                name: "日本史4",
                iconName: "building.columns",
                primaryColor: .red,
                secondaryColor: .orange,
                questions: history4Questions,
                questionType: .multipleChoice
            ),
            QuizCategory(
                name: "日本史5",
                iconName: "building.columns",
                primaryColor: .red,
                secondaryColor: .orange,
                questions: history5Questions,
                questionType: .multipleChoice
            ),
            QuizCategory(
                name: "世界史",
                iconName: "globe",
                primaryColor: .blue,
                secondaryColor: .cyan,
                questions: worldHistoryQuestions,
                questionType: .freeText
            ),
            QuizCategory(
                name: "世界史2",
                iconName: "globe",
                primaryColor: .blue,
                secondaryColor: .cyan,
                questions: worldHistory2Questions,
                questionType: .freeText
            ),
            QuizCategory(
                name: "地理",
                iconName: "map",
                primaryColor: .green,
                secondaryColor: .mint,
                questions: geographyQuestions,
                questionType: .freeText
            ),
            QuizCategory(
                name: "英単語",
                iconName: "textbook",
                primaryColor: .purple,
                secondaryColor: .pink,
                questions: englishQuestions,
                questionType: .freeText
            )
        ]
    }

    
    func addUserAnswer(_ answer: UserAnswer) {
        userAnswers.append(answer)
    }
    
    func getCorrectAnswersCount(for category: QuizCategory) -> Int {
        let categoryAnswers = userAnswers.filter { answer in
            category.questions.contains { $0.id == answer.questionId }
        }
        return categoryAnswers.filter { $0.isCorrect }.count
    }
    
    func getTotalAnswersCount(for category: QuizCategory) -> Int {
        let categoryAnswers = userAnswers.filter { answer in
            category.questions.contains { $0.id == answer.questionId }
        }
        return categoryAnswers.count
    }
}

// ColorをCodableにするためのラッパー
struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    
    init(color: Color) {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
            self.red   = Double(r)
            self.green = Double(g)
            self.blue  = Double(b)
            self.alpha = Double(a)
        } else {
            // sRGB に変換してから成分を取得（ダイナミックカラー等の保険）
            let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
            let conv = uiColor.cgColor.converted(to: sRGB, intent: .defaultIntent, options: nil)
            let comps = conv?.components ?? [0,0,0,1]
            self.red   = Double(comps[0])
            self.green = Double(comps.count > 2 ? comps[1] : comps[0])
            self.blue  = Double(comps.count > 2 ? comps[2] : comps[0])
            self.alpha = Double(conv?.alpha ?? 1)
        }
    }
    
    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
}
