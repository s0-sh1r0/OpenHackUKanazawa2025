import SwiftUI

struct ExplanationView: View {
    let category: QuizCategory
    let questionIDs: Set<UUID>
    @EnvironmentObject var quizManager: QuizManager
    @Environment(\.presentationMode) var presentationMode
    
    private func latestUserAnswer(for questionId: UUID) -> UserAnswer? {
        quizManager.userAnswers
            .filter { $0.questionId == questionId }
            .sorted { $0.timestamp > $1.timestamp }
            .first
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(
                    Array(category.questions.enumerated())
                        .filter { questionIDs.contains($0.element.id) },
                    id: \.element.id
                ) { originalIndex, q in
                    Section(header: Text("問題\(originalIndex + 1)")) {
                        // 使用したサブ設問を特定
                        let ua = latestUserAnswer(for: q.id)
                        let usedPrompt: MultipleQuestion? = {
                            if let sid = ua?.subQuestionId {
                                return q.questions.first(where: { $0.id == sid })
                            } else {
                                return q.questions.first
                            }
                        }()
                        
                        // サブ設問（1つだけ表示）
                        if let mq = usedPrompt {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Q").font(.headline)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(mq.question).font(.body)
                                    
                                    if let choices = mq.choices, !choices.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            ForEach(choices.indices, id: \.self) { i in
                                                HStack(alignment: .top, spacing: 6) {
                                                    Text("•").bold()
                                                    Text(choices[i])
                                                }
                                            }
                                        }
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 6)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                            
                            // 正解・あなたの回答・結果
                            let yourText = ua?.userAnswer ?? "未回答"
                            let isCorrect = ua?.isCorrect
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("正解")
                                    .font(.subheadline).foregroundColor(.green)
                                Text(q.answer)
                                    .font(.body).padding(.leading, 4)
                                
                                Text("あなたの回答")
                                    .font(.subheadline).foregroundColor(.red)
                                Text(yourText)
                                    .font(.body).padding(.leading, 4)
                                
                                Text("結果")
                                    .font(.subheadline)
                                    .foregroundColor(isCorrect == true ? .green : .red)
                                Text(isCorrect == nil ? "未回答" : (isCorrect! ? "正解" : "不正解"))
                                    .font(.body).padding(.leading, 4)
                            }
                            .padding(.top, 4)
                            
                            // 解説（このサブ設問のみ）
                            let exp = mq.explain.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !exp.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("解説")
                                        .font(.subheadline).fontWeight(.bold)
                                    Text(exp)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 4)
                                }
                                .padding(.top, 6)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("解説")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}

#Preview("Explanation - freeText (answered subset only)") {
    // --- サンプル: 記述式 ---
    // Q1（サブ設問2つ）
    let mq1a = MultipleQuestion(
        question: "1192年に鎌倉幕府を開いた人物は？（パターンA）",
        choices: nil,
        explain: "鎌倉幕府の初代将軍は源頼朝。"
    )
    let mq1b = MultipleQuestion(
        question: "鎌倉幕府の初代将軍は誰？（パターンB）",
        choices: nil,
        explain: "武家政権を確立したのが源頼朝。"
    )

    // Q2（サブ設問1つ）
    let mq2 = MultipleQuestion(
        question: "1603年に江戸幕府を開いた人物は？",
        choices: nil,
        explain: "江戸幕府の初代将軍は徳川家康。"
    )

    // Question配列
    let q1 = Question(questions: [mq1a, mq1b], answer: "源頼朝", category: "日本史")
    let q2 = Question(questions: [mq2],        answer: "徳川家康", category: "日本史")

    // Category
    let cat = QuizCategory(
        name: "日本史(記述式)",
        iconName: "building.columns",
        primaryColor: .red,
        secondaryColor: .orange,
        questions: [q1, q2],
        questionType: .freeText
    )

    // 回答は Q1 の「サブ設問B（mq1b）」だけを解いた想定（正解）
    let manager = QuizManager()
    manager.addUserAnswer(
        UserAnswer(
            questionId: q1.id,
            subQuestionId: q1.questions[1].id,
            userAnswer: "源頼朝",
            isCorrect: true
        )
    )

    // 解いた問題だけ（= Q1）
    let answeredIDs: Set<UUID> = [q1.id]

    return ExplanationView(category: cat, questionIDs: answeredIDs)
        .environmentObject(manager)
}
