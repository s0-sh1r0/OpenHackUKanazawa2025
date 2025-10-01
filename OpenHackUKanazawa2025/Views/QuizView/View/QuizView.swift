import SwiftUI

struct QuizView: View {
    let category: QuizCategory
    @EnvironmentObject var quizManager: QuizManager
    @Environment(\.presentationMode) var presentationMode
    
    @State private var currentQuestionIndex = 0
    @State private var userAnswer = ""
    @State private var selectedChoiceIndex: Int? = nil
    @State private var showAnswer = false
    @State private var isAnswerCorrect = false
    @State private var showResult = false
    @State private var answeredQuestions: Set<Int> = []
    @State private var isBackTop = false
    @State private var currentSubIndex = 0
    
    private var currentQuestion: Question {
        category.questions[currentQuestionIndex]
    }
    private var currentPrompt: MultipleQuestion {
        currentQuestion.questions[currentSubIndex]
    }
    private var currentChoices: [String] {
        currentPrompt.choices ?? []
    }
    private var isChoiceBased: Bool {
        switch category.questionType {
        case .multipleChoice, .fillInTheBlankMultipleChoice: return true
        default: return false
        }
    }
    private var progress: Double {
        Double(answeredQuestions.count) / Double(category.questions.count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            VStack(spacing: 16) {
                HStack {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text(category.name)
                        .font(.headline).fontWeight(.semibold)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(currentQuestionIndex + 1)/\(category.questions.count)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [category.primaryColor, category.secondaryColor]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // メイン
            VStack(spacing: 24) {
                Spacer()
                
                // 質問カード
                VStack(spacing: 20) {
                    Text("問題")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(currentPrompt.question)
                        .font(.title2).fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(16)
                .padding(.horizontal)
                
                // 回答エリア
                if !showAnswer {
                    if isChoiceBased {
                        ChoiceAnswerArea(
                            choices: currentChoices,
                            selectedIndex: $selectedChoiceIndex,
                            confirm: checkAnswerChoice,
                            primary: category.primaryColor
                        )
                    } else {
                        FreeTextAnswerArea(
                            userAnswer: $userAnswer,
                            confirm: checkAnswerFreeText,
                            primary: category.primaryColor
                        )
                    }
                } else {
                    // 結果表示
                    ResultArea(
                        isCorrect: isAnswerCorrect,
                        correctText: currentQuestion.answer,
                        yourText: userAnswer,
                        primary: category.primaryColor,
                        nextAction: nextQuestion,
                        isLast: currentQuestionIndex >= category.questions.count - 1
                    )
                }
                
                Spacer()
            }
            .padding(.top)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showResult) {
            ResultView(category: category,
                       answeredQuestions: answeredQuestions,
                       onRetry: {resetQuiz()},
                       onReturnToTop: {presentationMode.wrappedValue.dismiss()}
            )
                .environmentObject(quizManager)
        }
        .onAppear {
            pickSubIndex()
        }
    }
    
    // MARK: - Actions
    private func pickSubIndex() {
        let count = currentQuestion.questions.count
        guard count > 0 else { currentSubIndex = 0; return }
        currentSubIndex = Int.random(in: 0..<count)
    }
    
    private func checkAnswerFreeText() {
        let ua = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        let ca = currentQuestion.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        isAnswerCorrect = ua.caseInsensitiveCompare(ca) == .orderedSame
        finalizeAnswer(userShownAnswer: ua)
    }
    
    private func checkAnswerChoice() {
        guard let idx = selectedChoiceIndex, idx < currentChoices.count else { return }
        let chosen = currentChoices[idx]
        userAnswer = chosen
        let ca = currentQuestion.answer.trimmingCharacters(in: .whitespacesAndNewlines)
        isAnswerCorrect = chosen.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare(ca) == .orderedSame
        finalizeAnswer(userShownAnswer: chosen)
    }
    
    private func finalizeAnswer(userShownAnswer: String) {
        // 記録
        let record = UserAnswer(
            questionId: currentQuestion.id,
            subQuestionId: currentPrompt.id, 
            userAnswer: userShownAnswer,
            isCorrect: isAnswerCorrect
        )
        quizManager.addUserAnswer(record)
        answeredQuestions.insert(currentQuestionIndex)
        showAnswer = true
    }
    
    private func nextQuestion() {
        if currentQuestionIndex < category.questions.count - 1 {
            currentQuestionIndex += 1
            pickSubIndex()
            userAnswer = ""
            selectedChoiceIndex = nil
            showAnswer = false
        } else {
            showResult = true
        }
    }
    
    private func resetQuiz() {
        currentQuestionIndex = 0
        userAnswer = ""
        selectedChoiceIndex = nil
        showAnswer = false
        isAnswerCorrect = false
        showResult = false
        answeredQuestions.removeAll()
        // サブ設問ランダム化を導入している場合は↓も
        // currentSubIndex = 0
        // pickSubIndex()
    }
    
    // MARK: - Subviews
    
    private func letter(_ i: Int) -> String {
        guard (0..<26).contains(i) else { return "#" }
        return String(UnicodeScalar(65 + i)!) // A=65
    }
    
    private struct ChoiceAnswerArea: View {
        let choices: [String]
        @Binding var selectedIndex: Int?
        let confirm: () -> Void
        let primary: Color
        
        var body: some View {
            VStack(spacing: 16) {
                Text("選択肢から答えを選んでください")
                    .font(.headline).fontWeight(.medium)
                
                VStack(spacing: 12) {
                    ForEach(choices.indices, id: \.self) { i in
                        Button {
                            selectedIndex = i
                        } label: {
                            HStack {
                                Text("\(String(UnicodeScalar(65 + i)!)). \(choices[i])")
                                    .font(.body).fontWeight(.medium)
                                    .foregroundColor(selectedIndex == i ? .white : .primary)
                                Spacer()
                                if selectedIndex == i {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                }
                            }
                            .padding()
                            .background(selectedIndex == i ? primary : Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                
                Button(action: confirm) {
                    Text("回答する")
                        .font(.headline).fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedIndex == nil ? Color.gray : primary)
                        .cornerRadius(12)
                }
                .disabled(selectedIndex == nil)
                .padding(.horizontal)
            }
        }
    }
    
    private struct FreeTextAnswerArea: View {
        @Binding var userAnswer: String
        let confirm: () -> Void
        let primary: Color
        
        var body: some View {
            VStack(spacing: 16) {
                Text("答えを入力してください")
                    .font(.headline).fontWeight(.medium)
                
                TextField("回答を入力", text: $userAnswer)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.title3)
                    .padding(.horizontal)
                
                Button(action: confirm) {
                    Text("回答する")
                        .font(.headline).fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(userAnswer.isEmpty ? Color.gray : primary)
                        .cornerRadius(12)
                }
                .disabled(userAnswer.isEmpty)
                .padding(.horizontal)
            }
        }
    }
    
    private struct ResultArea: View {
        let isCorrect: Bool
        let correctText: String
        let yourText: String
        let primary: Color
        let nextAction: () -> Void
        let isLast: Bool
        
        var body: some View {
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(isCorrect ? .green : .red)
                    Text(isCorrect ? "正解！" : "不正解")
                        .font(.title2).fontWeight(.bold)
                        .foregroundColor(isCorrect ? .green : .red)
                }
                
                VStack(spacing: 8) {
                    Text("正解")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text(correctText)
                        .font(.title2).fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                if !isCorrect {
                    VStack(spacing: 8) {
                        Text("あなたの回答")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(.secondary)
                        Text(yourText)
                            .font(.title3)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                Button(action: nextAction) {
                    Text(isLast ? "結果を見る" : "次の問題")
                        .font(.headline).fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(primary)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview("freeText") {
    let sampleQuestions = [ Question(
        questions: [MultipleQuestion(
            question: "1192年に鎌倉幕府を開いた人物は？",
            explain: "鎌倉幕府の初代将軍。"
        )],
        answer: "源頼朝",
        category: "日本史") ]
    let sampleCategory = QuizCategory(
        name: "日本史",
        iconName: "building.columns",
        primaryColor: .red,
        secondaryColor: .orange,
        questions: sampleQuestions,
        questionType: .freeText
    )
    QuizView(category: sampleCategory)
        .environmentObject(QuizManager())
}

#Preview("freeText random") {
    let sampleQuestions = [
        Question(
            questions: [MultipleQuestion(
                question: "1192年に鎌倉幕府を開いた人物は？",
                choices: ["源頼朝","足利尊氏","北条政子","平清盛"],
                explain: "正解は源頼朝。"
            )],
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
    QuizView(category: sampleCategory)
        .environmentObject(QuizManager())
}

#Preview("multipleChoice") {
    let sampleQuestions = [
        Question(
            questions: [MultipleQuestion(
                question: "1192年に鎌倉幕府を開いた人物は？",
                choices: ["源頼朝","足利尊氏","北条政子","平清盛"],
                explain: "正解は源頼朝。"
            )],
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
    QuizView(category: sampleCategory)
        .environmentObject(QuizManager())
}

#Preview("multipleChoice random") {
    let sampleQuestions = [
        Question(
            questions: [
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？pattern1",
                                 choices: ["源頼朝","足利尊氏1","北条政子1","平清盛1"],
                                 explain: "源頼朝が正解。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？pattern2",
                                 choices: ["源頼朝","足利尊氏2","北条政子2","平清盛2"],
                                 explain: "源頼朝が正解。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？pattern3",
                                 choices: ["源頼朝","足利尊氏3","北条政3","平清盛3"],
                                 explain: "源頼朝が正解。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？pattern4",
                                 choices: ["源頼朝","足利尊氏4","北条政子4","平清盛4"],
                                 explain: "源頼朝が正解。"),
                MultipleQuestion(question: "1192年に鎌倉幕府を開いた人物は？pattern5",
                                 choices: ["源頼朝","足利尊氏5","北条政子5","平清盛5"],
                                 explain: "源頼朝が正解。")
            ],
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
    QuizView(category: sampleCategory)
        .environmentObject(QuizManager())
}
