import SwiftUI

struct AddCategoryView: View {
    @EnvironmentObject var quizManager: QuizManager
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var aiVM = AIQuestionViewModel()
    
    @State private var categoryName: String = ""
    @State private var iconName: String = "book.closed.fill"
    @State private var primaryColor: Color = .blue
    @State private var secondaryColor: Color = .cyan
    
    @State private var newQuestionText: String = ""
    @State private var newAnswerText: String = ""
    @State private var questions: [Question] = []
    
    @State private var showingIconPicker = false
    @State private var showingColorPicker = false
    
    @State private var isMultipleChoice = false
    @State private var isFillInTheBlank = false
    
    @State private var answers: [String] = []
    @State private var answer: String = ""
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("問題集情報")) {
                    TextField("問題集名", text: $categoryName)
                    
                    HStack {
                        Text("アイコン")
                        Spacer()
                        Image(systemName: iconName)
                            .font(.title2)
                            .foregroundColor(primaryColor)
                        Button("変更") {
                            showingIconPicker = true
                        }
                    }
                    
                    ColorPicker("メインカラー", selection: $primaryColor)
                    ColorPicker("サブカラー", selection: $secondaryColor)
                }
                
                Section(header: Text("問題のタイプ(デフォルトは1問1答形式)")) {
                    Toggle("4択問題形式", isOn: $isMultipleChoice)
                    Toggle("穴埋め問題形式", isOn: $isFillInTheBlank)
                }
                
                if !isMultipleChoice {
                    Section(header: Text("問題の追加")) {
                        ForEach(questions) { q in
                            QuestionRow(q: q)
                        }
                        .onDelete(perform: deleteQuestions)
                        TextField("新しい質問", text: $newQuestionText)
                        TextField("新しい回答", text: $newAnswerText)
                        
                        Button("問題を追加") {
                            addQuestion()
                        }
                        .disabled(newQuestionText.isEmpty || newAnswerText.isEmpty)
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
                                let generated = await aiVM.generateQuestionsForCategory(
                                    categoryName: categoryName.isEmpty ? "未分類" : categoryName,
                                    answers: answers,
                                    isMultipleChoice: isMultipleChoice,
                                    isFillInTheBlank: isFillInTheBlank
                                )
                                // 生成結果をこの画面の編集中配列へ追加（保存時にカテゴリ化）
                                questions.append(contentsOf: generated)
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
            .navigationTitle("問題集を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("保存") { saveCategory() }
                            .disabled(categoryName.isEmpty || questions.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $iconName, availableIcons: availableIcons)
            }
        }
    }
    
    private func addQuestion() {
        let prompt = MultipleQuestion(
            question: newQuestionText,
            choices: nil,
            explain: "解説なし"
        )
        let newQuestion = Question(questions: [prompt], answer: newAnswerText, category: categoryName)
        questions.append(newQuestion)
        newQuestionText = ""
        newAnswerText = ""
    }
    
    private func deleteQuestions(at offsets: IndexSet) {
        questions.remove(atOffsets: offsets)
    }
    
    private func saveCategory() {
        let newCategory = QuizCategory(
            name: categoryName,
            iconName: iconName,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            questions: questions,
            questionType: selectedQuestionType
        )
        quizManager.addCategory(newCategory)
        presentationMode.wrappedValue.dismiss()
    }
    
    private var selectedQuestionType: QuestionType {
        switch (isMultipleChoice, isFillInTheBlank) {
        case (false, false):
            return .freeText
        case (true,  false):
            return .multipleChoice
        case (false, true):
            return .fillInTheBlankFreeText
        case (true,  true):
            return .fillInTheBlankMultipleChoice
        }
    }
}

struct IconPickerView: View {
    @Binding var selectedIcon: String
    let availableIcons: [String]
    @Environment(\.presentationMode) var presentationMode
    
    let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 5)
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button(action: {
                            selectedIcon = icon
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: icon)
                                .font(.largeTitle)
                                .padding()
                                .background(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("アイコンを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

private struct QuestionRow: View {
    let q: Question
    var body: some View {
        let prompt = q.questions.first?.question ?? ""
        VStack(alignment: .leading) {
            Text("Q: \(prompt)")
                .font(.headline)
            Text("A: \(q.answer)")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

struct AddCategoryView_Previews: PreviewProvider {
    static var previews: some View {
        AddCategoryView()
            .environmentObject(QuizManager())
    }
}
