import SwiftUI

struct ResultView: View {
    let category: QuizCategory
    let answeredQuestions: Set<Int>
    let onRetry: () -> Void
    let onReturnToTop: () -> Void
    @EnvironmentObject var quizManager: QuizManager
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingExplanation = false
    
    private var sessionQuestionIDs: Set<UUID> {
        Set(
            answeredQuestions.compactMap { i in
                guard category.questions.indices.contains(i) else { return nil }
                return category.questions[i].id
            }
        )
    }
    
    private var correctCount: Int {
        quizManager.getCorrectAnswersCount(for: category)
    }
    
    private var totalCount: Int {
        answeredQuestions.count
    }
    
    private var accuracy: Double {
        totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // ヘッダー
            VStack(spacing: 16) {
                Text("結果")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(category.name)
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            // スコア表示
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 12)
                        .frame(width: 150, height: 150)
                    
                    Circle()
                        .trim(from: 0, to: accuracy)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [category.primaryColor, category.secondaryColor]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 150, height: 150)
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("\(Int(accuracy * 100))%")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("\(correctCount)/\(totalCount)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(getResultMessage())
                    .font(.headline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // ボタン
            VStack(spacing: 16) {
                Button(action: {
                    showingExplanation = true
                }) {
                    Text("解説を見る")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(category.secondaryColor)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                    let ids = sessionQuestionIDs
                    quizManager.clearUserAnswers(for: ids)
                    DispatchQueue.main.async {
                        onRetry()
                    }
                }) {
                    Text("もう一度挑戦")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(category.primaryColor)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                    let ids = sessionQuestionIDs
                    quizManager.clearUserAnswers(for: ids)
                    DispatchQueue.main.async {
                        onRetry()
                        onReturnToTop()
                    }
                }) {
                    Text("問題集選択に戻る")
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(category.primaryColor)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(category.primaryColor, lineWidth: 2)
                        )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        .sheet(isPresented: $showingExplanation) {
            ExplanationView(
                category: category,
                questionIDs: sessionQuestionIDs
//                questions: answeredQuestionsArray,
//                userAnswers: relevantUserAnswers
            )
        }
    }
    
    private func getResultMessage() -> String {
        switch accuracy {
        case 1.0:
            return "素晴らしい！完璧な結果です！"
        case 0.9..<1.0:
            return "おしい！もう少しで完璧です！"
        case 0.7..<0.9:
            return "よくできました！もうちょっとです！"
        case 0.5..<0.7:
            return "まずまずの結果です。復習して再挑戦しましょう！"
        default:
            return "もう一度復習してから挑戦してみましょう！"
        }
    }
}

struct ResultView_Previews: PreviewProvider {
    static var previews: some View {
        // サンプル問題
        let questions = [
            Question(
                questions: [MultipleQuestion(
                    question: "1192年に鎌倉幕府を開いた人物は？",
                    explain: "鎌倉幕府の初代将軍。"
                )],
                answer: "源頼朝",
                category: "日本史"
            ),
            Question(
                questions: [MultipleQuestion(
                    question: "天下統一を果たした三英傑のうち、江戸幕府を開いた人物は？",
                    explain: "徳川家康は江戸幕府の初代将軍。"
                )],
                answer: "徳川家康",
                category: "日本史"
            ),
            Question(
                questions: [MultipleQuestion(
                    question: "織田信長が1575年に勝利した合戦は？",
                    explain: "鉄砲を用いた戦術で武田勝頼に勝利。"
                )],
                answer: "長篠の戦い",
                category: "日本史"
            )
        ]
        
        // カテゴリ
        let category = QuizCategory(
            name: "日本史",
            iconName: "building.columns",
            primaryColor: .red,
            secondaryColor: .orange,
            questions: questions,
            questionType: .freeText
        )
        
        // 回答済みインデックス（0,2問目を回答済みの例）
        let answered: Set<Int> = [0, 2]
        
        // QuizManager にダミー回答を投入
        let manager = QuizManager()
        let a1 = UserAnswer(
            questionId: questions[0].id,
            userAnswer: "源頼朝",
            isCorrect: true
        )
        let a2 = UserAnswer(
            questionId: questions[2].id,
            userAnswer: "桶狭間の戦い",
            isCorrect: false
        )
        manager.addUserAnswer(a1)
        manager.addUserAnswer(a2)
        
        // プレビュー
        return ResultView(
            category: category,
            answeredQuestions: answered,
            onRetry: {},
            onReturnToTop: {}
        )
        .environmentObject(manager)
        .previewDisplayName("ResultView Preview")
    }
}

