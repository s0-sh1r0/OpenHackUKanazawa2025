import SwiftUI

struct EditCategoryView: View {
    let category: QuizCategory
    
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var quizManager: QuizManager
    @StateObject private var aiVM = AIQuestionViewModel()
    
    @State private var categoryName: String = ""
    @State private var newQuestionText: String = ""
    @State private var newAnswerText: String = ""
    @State private var newQuestions: [Question] = []
    
    @State private var answers: [String] = []
    @State private var answer: String = ""
    @State private var canSave: Bool = false
    
    // ★ quizManager 側の最新を常に映す
    private var displayedCategory: QuizCategory {
        quizManager.categories.first(where: { $0.id == category.id }) ?? category
    }
    
    var body: some View {
        NavigationView {
            List {
                // 既存の問題一覧
                Section(header: Text("\(displayedCategory.name)問題一覧")) {
                    ForEach(displayedCategory.questions) { q in
                        QuestionRow(
                            q: q,
                            questionType: displayedCategory.questionType,
                            onAddSubQuestion: { text in
                                // 手入力: 問題文のみ追加
                                quizManager.addSubQuestion(
                                    text,
                                    choices: nil,
                                    explain: "解説なし",
                                    to: q.id,
                                    in: displayedCategory.id
                                )
                            },
                            onAddAISubQuestion: { mq in
                                // AI生成: 選択肢/解説まで保持して追加
                                quizManager.addSubQuestion(
                                    mq.question,
                                    choices: mq.choices,
                                    explain: mq.explain,
                                    to: q.id,
                                    in: displayedCategory.id
                                )
                            }
                        )
                        .environmentObject(aiVM)
                    }
                    .onDelete(perform: deleteQuestion)
                }
                
                // 新規の問題（Question）を追加するエリア
                if category.questionType == .freeText || category.questionType == .fillInTheBlankFreeText {
                    Section(header: Text("問題の追加")) {
                        ForEach(newQuestions) { q in
                            QuestionRow(
                                q: q,
                                questionType: displayedCategory.questionType,
                                onAddSubQuestion: { text in
                                    // 手入力: 問題文のみ追加
                                    quizManager.addSubQuestion(
                                        text,
                                        choices: nil,
                                        explain: "解説なし",
                                        to: q.id,
                                        in: displayedCategory.id
                                    )
                                },
                                onAddAISubQuestion: { mq in
                                    // AI生成: 選択肢/解説まで保持して追加
                                    quizManager.addSubQuestion(
                                        mq.question,
                                        choices: mq.choices,
                                        explain: mq.explain,
                                        to: q.id,
                                        in: displayedCategory.id
                                    )
                                }
                            )
                            .environmentObject(aiVM)
                        }
                        .onDelete(perform: deleteNewQuestions)
                        
                        TextField("新しい問題", text: $newQuestionText)
                        TextField("新しい回答", text: $newAnswerText)
                        
                        Button("問題を追加") {
                            addNewQuestion()
                        }
                        .disabled(newQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  newAnswerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                
                Section(header: Text("覚えたい単語")) {
                    ForEach(answers.indices, id: \.self) { i in
                        Text(answers[i])
                    }
                    TextField("新しい解答", text: $answer)
                    Button("解答を追加") {
                        answers.append(answer)
                        answer = ""
                    }
                    .disabled(answer.isEmpty || answer.isEmpty)
                    VStack(alignment: .leading, spacing: 8) {
                        if aiVM.isLoading {
                            ProgressView("AI生成中…")
                        }

                        Button {
                            Task {
                                // 画面のカテゴリ種別から送信先API（1問1答/4択 & 穴埋め) を自動判定
                                let useMCQ = (displayedCategory.questionType == .multipleChoice ||
                                              displayedCategory.questionType == .fillInTheBlankMultipleChoice)
                                let useBlank = (displayedCategory.questionType == .fillInTheBlankFreeText ||
                                                displayedCategory.questionType == .fillInTheBlankMultipleChoice)

                                let generated = await aiVM.generateQuestionsForCategory(
                                    categoryName: displayedCategory.name,
                                    answers: answers,
                                    isMultipleChoice: useMCQ,
                                    isFillInTheBlank: useBlank
                                )
                                // 既存カテゴリに直接追加して永続化
                                quizManager.addQuestions(generated, to: displayedCategory.id)
                                answers.removeAll()
                                canSave.toggle()
                            }
                        } label: {
                            Label("問題文をAIで生成", systemImage: "sparkles")
                        }
                        .disabled(answers.isEmpty || aiVM.isLoading)

                        if let msg = aiVM.errorMessage {
                            Text(msg).foregroundColor(.red)
                        }
                    }

                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("問題を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        EditButton()
                        Button("保存") { saveQuestion() }
                            .disabled(newQuestions.isEmpty)
                    }
                }
            }
        }
        .onAppear {
            if categoryName.isEmpty { categoryName = category.name }
        }
    }
    
    // MARK: 新規 Question の追加（既存の q にサブ設問を足すのとは別）
    private func addNewQuestion() {
        let prompt = MultipleQuestion(
            question: newQuestionText,
            choices: nil,
            explain: "解説なし"        // ★ 追加
        )
        let newQuestion = Question(questions: [prompt],
                                   answer: newAnswerText,
                                   category: categoryName)
        newQuestions.append(newQuestion)
        newQuestionText = ""
        newAnswerText = ""
    }
    
    private func deleteNewQuestions(at offsets: IndexSet) {
        newQuestions.remove(atOffsets: offsets)
    }
    
    private func saveQuestion() {
        quizManager.addQuestions(newQuestions, to: category.id)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func deleteQuestion(at offsets: IndexSet) {
        let qs = displayedCategory.questions
        let ids = offsets.compactMap { idx in
            qs.indices.contains(idx) ? qs[idx].id : nil
        }
        for id in ids {
            quizManager.deleteQuestion(id, from: displayedCategory.id)
        }
    }
}

// 行ビュー：既存 Question のサブ設問一覧 + その場で追加
private struct QuestionRow: View {
    let q: Question
    let questionType: QuestionType
    var onAddSubQuestion: (String) -> Void                     // 手入力で追加
    var onAddAISubQuestion: (MultipleQuestion) -> Void          // AIで追加（新規）

    @EnvironmentObject var aiVM: AIQuestionViewModel
    @State private var subText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 既存サブ設問の表示
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(q.questions.enumerated()), id: \.element.id) { idx, mq in
                    VStack(alignment: .leading, spacing: 4) {
                        let prefix = q.questions.count > 1 ? "Q\(idx + 1): " : "Q: "
                        Text(prefix + mq.question)
                            .font(.headline)
                        if let choices = mq.choices, !choices.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(choices, id: \.self) { choice in
                                    HStack(alignment: .top, spacing: 6) {
                                        Text("•").bold()
                                        Text(choice)
                                    }
                                }
                            }
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.leading, 10)
                        }
                    }
                }
            }

            // 共通の答え
            Text("A: \(q.answer)")
                .font(.subheadline)
                .foregroundColor(.gray)

            // --- AIで追加（全タイプで表示） ---
            HStack(spacing: 8) {
                Button {
                    Task {
                        if let mq = await aiVM.generateSubQuestion(for: q, questionType: questionType) {
                            onAddAISubQuestion(mq)  // 親側で保存
                        }
                    }
                } label: {
                    Label("問題文をAIで追加", systemImage: "sparkles")
                }
                .disabled(aiVM.isLoading)
                if aiVM.isLoading {
                    ProgressView()
                        .padding(.leading, 2)
                }
            }
            .foregroundColor(Color.accentColor)

            // --- 手入力: freeText / fillInTheBlankFreeText のときだけ表示 ---
            if questionType == .freeText || questionType == .fillInTheBlankFreeText {
                HStack(alignment: .center, spacing: 8) {
                    TextField("新しい問題文を入力", text: $subText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Button("追加") {
                        let text = subText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return }
                        onAddSubQuestion(text) // 手入力は問題文のみ追加
                        subText = ""
                    }
                    .disabled(subText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            // 失敗メッセージ（任意）
            if let msg = aiVM.errorMessage {
                Text(msg).foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}


#Preview {
    let sampleQuestions = [
        Question(
            questions: [MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？",
                                         explain: "鎌倉幕府の初代将軍。")],
            answer: "源頼朝",
            category: "日本史"
        ),
        Question(
            questions: [MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？",
                                         explain: "鎌倉幕府の初代将軍。")],
            answer: "源頼朝",
            category: "日本史"
        )
    ]
    let sampleCategory = QuizCategory(
        name: "日本史",
        iconName: "building.columns",
        primaryColor: .red,
        secondaryColor: .orange,
        questions: sampleQuestions,
        questionType: .freeText
    )
    EditCategoryView(category: sampleCategory)
        .environmentObject(QuizManager())
}

#Preview("multipleChoice") {
    let sampleQuestions = [
        Question(
            questions: [MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？",
                                         choices: ["源頼朝","足利尊氏","北条政子","平清盛"],
                                         explain: "鎌倉幕府の初代将軍。")],
            answer: "源頼朝",
            category: "日本史"
        ),
        Question(
            questions: [MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？",
                                         choices: ["源頼朝","足利尊氏","北条政子","平清盛"],
                                         explain: "鎌倉幕府の初代将軍。")],
            answer: "源頼朝",
            category: "日本史"
        )
    ]
    let sampleCategory = QuizCategory(
        name: "日本史",
        iconName: "building.columns",
        primaryColor: .red,
        secondaryColor: .orange,
        questions: sampleQuestions,
        questionType: .multipleChoice
    )
    EditCategoryView(category: sampleCategory)
        .environmentObject(QuizManager())
}
