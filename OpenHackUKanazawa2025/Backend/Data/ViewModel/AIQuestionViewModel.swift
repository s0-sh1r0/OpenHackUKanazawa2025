import Foundation
import SwiftUI

@MainActor
final class AIQuestionViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let api: ApiClient

//    init(baseURLString: String = "http://127.0.0.1:8000") {
//        self.api = ApiClient(baseURL: URL(string: baseURLString)!)
//    }
    init(baseURLString: String = "http://172.20.10.6:8000") {
        self.api = ApiClient(baseURL: URL(string: baseURLString)!)
    }
    // MARK: - Public

    /// AddCategoryView 用：answers 配列からまとめて問題を生成して Question 化
    func generateQuestionsForCategory(
        categoryName: String,
        answers: [String],
        isMultipleChoice: Bool,
        isFillInTheBlank: Bool
    ) async -> [Question] {
        guard !answers.isEmpty else { return [] }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let pattern: ProblemPattern = isFillInTheBlank ? .anaume : .ichimonIttou

        do {
            if isMultipleChoice {
                // 4択のバッチ
                let items = try await api.generateBatchMCQ(answers: answers, pattern: pattern)
                // サーバは inputs に1:1で返す想定。対応を保つため zip で合成
                return zip(answers, items).map { answer, item in
                    let mq = MultipleQuestion(
                        question: item.question,
                        choices: item.choices,
                        explain: item.explanation
                    )
                    return Question(questions: [mq], answer: answer, category: categoryName)
                }
            } else {
                // 記述(1問1答)のバッチ
                let items = try await api.generateBatchQA(answers: answers, pattern: pattern)
                return zip(answers, items).map { answer, item in
                    let mq = MultipleQuestion(
                        question: item.question,
                        choices: nil,
                        explain: item.explanation
                    )
                    return Question(questions: [mq], answer: answer, category: categoryName)
                }
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return []
        }
    }

    /// EditCategoryView 用：既存 Question に AI でサブ設問を1つ追加生成
    func generateSubQuestion(
        for original: Question,
        questionType: QuestionType
    ) async -> MultipleQuestion? {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        let existing = original.questions.map { $0.question }
        let pattern: ProblemPattern = {
            switch questionType {
            case .fillInTheBlankFreeText, .fillInTheBlankMultipleChoice:
                return .anaume
            default:
                return .ichimonIttou
            }
        }()

        do {
            switch questionType {
            case .multipleChoice, .fillInTheBlankMultipleChoice:
                // 4択・単発（サーバ仕様で配列返却）
                let arr = try await api.generateSingleMCQ(
                    answer: original.answer,
                    existingQuestions: existing,
                    pattern: pattern
                )
                guard let item = arr.first else { return nil }
                return MultipleQuestion(
                    question: item.question,
                    choices: item.choices,
                    explain: item.explanation
                )

            default:
                // 記述・単発
                let res = try await api.generateSingleQA(
                    answer: original.answer,
                    existingQuestions: existing,
                    pattern: pattern
                )
                return MultipleQuestion(
                    question: res.question,
                    choices: nil,
                    explain: res.explanation
                )
            }
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return nil
        }
    }
}
