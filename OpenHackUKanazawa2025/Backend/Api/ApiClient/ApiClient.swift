import Foundation

// MARK: - 共通

public enum HTTPMethod: String {
    case GET, POST, PUT, PATCH, DELETE
}

/// 問題の文体（APIの `pattern` 文字列と一致）
public enum ProblemPattern: String, Codable {
    case ichimonIttou = "1問1答"
    case anaume = "穴埋め"
}

// MARK: - エンドポイント

public enum Endpoint {
    /// 1問1答: 単発生成 POST http://127.0.0.1:8000/generator/generate_problem/
    case qaGenerate
    /// 1問1答: 一括生成 POST http://127.0.0.1:8000/generator/generate_workbook_for_q_and_a/
    case qaBatch
    /// 4択: 単発生成 POST http://127.0.0.1:8000/generator/generate_question_4choice_api/
    case mcqGenerate
    /// 4択: 一括生成 POST http://127.0.0.1:8000/generator/generate_4_choice_workbook_for_q_and_a/
    case mcqBatch
    /// 任意
    case custom(path: String, method: HTTPMethod)

    public var path: String {
        switch self {
        case .qaGenerate:  return "/generator/generate_problem/"
        case .qaBatch:     return "/generator/generate_workbook_for_q_and_a/"
        case .mcqGenerate: return "/generator/generate_question_4choice_api/"
        case .mcqBatch:    return "/generator/generate_4_choice_workbook_for_q_and_a/"
        case .custom(let p, _): return p
        }
    }

    public var method: HTTPMethod {
        switch self {
        case .qaGenerate, .qaBatch, .mcqGenerate, .mcqBatch:
            return .POST
        case .custom(_, let m):
            return m
        }
    }
}


// MARK: - リクエスト/レスポンスモデル（日本語キー対応）

// 1問1答 単発: Request { 解答, 問題文:[], pattern }
public struct SingleQARequest: Codable {
    public let answer: String
    public let existingQuestions: [String]
    public let pattern: ProblemPattern

    public init(answer: String, existingQuestions: [String] = [], pattern: ProblemPattern) {
        self.answer = answer
        self.existingQuestions = existingQuestions
        self.pattern = pattern
    }

    enum CodingKeys: String, CodingKey {
        case answer = "解答"
        case existingQuestions = "問題文" // 仕様: 過去に使った問題文の配列
        case pattern
    }
}

// 1問1答 単発: Response { 問題文, 解説 }
public struct SingleQAResponse: Codable, Hashable {
    public let question: String
    public let explanation: String

    enum CodingKeys: String, CodingKey {
        case question = "問題文"
        case explanation = "解説"
    }
}

// 1問1答 複数: Request { 解答:[解答], pattern }
public struct BatchQARequest: Codable {
    public let answers: [String]
    public let pattern: ProblemPattern

    public init(answers: [String], pattern: ProblemPattern) {
        self.answers = answers
        self.pattern = pattern
    }

    enum CodingKeys: String, CodingKey {
        case answers = "解答"
        case pattern
    }
}

// 4択 単発: Request { 解答, 問題文:[], pattern }
public struct SingleMCQRequest: Codable {
    public let answer: String
    public let existingQuestions: [String]
    public let pattern: ProblemPattern

    public init(answer: String, existingQuestions: [String] = [], pattern: ProblemPattern) {
        self.answer = answer
        self.existingQuestions = existingQuestions
        self.pattern = pattern
    }

    enum CodingKeys: String, CodingKey {
        case answer = "解答"
        case existingQuestions = "問題文"
        case pattern
    }
}

// 4択 単発/複数: Response要素 { 問題文, 選択肢, 解説 }
public struct MCQItem: Codable, Hashable {
    public let question: String
    public let choices: [String]
    public let explanation: String

    enum CodingKeys: String, CodingKey {
        case question = "問題文"
        case choices = "選択肢"
        case explanation = "解説"
    }
}

// 4択 複数: Request { 解答:[解答], pattern }
public struct BatchMCQRequest: Codable {
    public let answers: [String]
    public let pattern: ProblemPattern

    public init(answers: [String], pattern: ProblemPattern) {
        self.answers = answers
        self.pattern = pattern
    }

    enum CodingKeys: String, CodingKey {
        case answers = "解答"
        case pattern
    }
}

// MARK: - ApiClient

public struct ApiClient {
    public let baseURL: URL
    public var defaultHeaders: [String: String] = ["Content-Type": "application/json"]
    public var timeout: TimeInterval = 20

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(baseURL: URL,
                session: URLSession = .shared,
                defaultHeaders: [String: String] = ["Content-Type": "application/json"],
                timeout: TimeInterval = 20) {
        self.baseURL = baseURL
        self.session = session
        self.defaultHeaders = defaultHeaders
        self.timeout = timeout

        let enc = JSONEncoder()
        // 日本語キーを使うため keyEncodingStrategy はデフォルト
        enc.outputFormatting = [.withoutEscapingSlashes]
        self.encoder = enc

        let dec = JSONDecoder()
        // 日本語キーを使うため keyDecodingStrategy はデフォルト
        self.decoder = dec
    }

    // MARK: - 低レベル

    private func makeURL(_ endpoint: Endpoint) throws -> URL {
        guard var comp = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        comp.path = comp.path.appending(endpoint.path)
        guard let url = comp.url else { throw APIError.invalidURL }
        return url
    }

    private func makeRequest(endpoint: Endpoint, body: Data?) throws -> URLRequest {
        let url = try makeURL(endpoint)
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = endpoint.method.rawValue
        defaultHeaders.forEach { req.setValue($0.value, forHTTPHeaderField: $0.key) }
        req.httpBody = body
        return req
    }

    private func run(_ req: URLRequest, retries: Int = 1) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        var lastError: Error?

        while attempt <= retries {
            do {
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse else {
                    throw APIError.transport(URLError(.badServerResponse))
                }
                if (200..<300).contains(http.statusCode) {
                    return (data, http)
                } else if (http.statusCode == 429 || (500..<600).contains(http.statusCode)), attempt < retries {
                    attempt += 1
                    try await Task.sleep(nanoseconds: UInt64(0.5 * Double(attempt) * 1_000_000_000))
                    continue
                } else {
                    throw APIError.server(status: http.statusCode, data: data)
                }
            } catch is CancellationError {
                throw APIError.cancelled
            } catch {
                lastError = error
                if attempt < retries {
                    attempt += 1
                    try await Task.sleep(nanoseconds: UInt64(0.4 * Double(attempt) * 1_000_000_000))
                    continue
                } else {
                    throw APIError.transport(error)
                }
            }
        }
        throw APIError.transport(lastError ?? URLError(.unknown))
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        _ endpoint: Endpoint,
        body: RequestBody,
        retries: Int = 1
    ) async throws -> ResponseBody {
        let data: Data
        do {
            data = try encoder.encode(body)
        } catch {
            throw APIError.encodingFailed
        }

        let req = try makeRequest(endpoint: endpoint, body: data)
        let (respData, _) = try await run(req, retries: retries)
        do {
            return try decoder.decode(ResponseBody.self, from: respData)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
}

// MARK: - 具体APIメソッド

public extension ApiClient {
    // 1) 1問1答 単発
    func generateSingleQA(
        answer: String,
        existingQuestions: [String] = [],
        pattern: ProblemPattern,
        retries: Int = 1
    ) async throws -> SingleQAResponse {
        let req = SingleQARequest(answer: answer, existingQuestions: existingQuestions, pattern: pattern)
        return try await post(.qaGenerate, body: req, retries: retries)
    }

    // 2) 1問1答 複数
    func generateBatchQA(
        answers: [String],
        pattern: ProblemPattern,
        retries: Int = 1
    ) async throws -> [SingleQAResponse] {
        let req = BatchQARequest(answers: answers, pattern: pattern)
        return try await post(.qaBatch, body: req, retries: retries)
    }

    // 3) 4択 単発（仕様に合わせ **配列**で返却）
    func generateSingleMCQ(
        answer: String,
        existingQuestions: [String] = [],
        pattern: ProblemPattern,
        retries: Int = 1
    ) async throws -> [MCQItem] {
        let req = SingleMCQRequest(answer: answer, existingQuestions: existingQuestions, pattern: pattern)
        return try await post(.mcqGenerate, body: req, retries: retries)
    }

    // 4) 4択 複数
    func generateBatchMCQ(
        answers: [String],
        pattern: ProblemPattern,
        retries: Int = 1
    ) async throws -> [MCQItem] {
        let req = BatchMCQRequest(answers: answers, pattern: pattern)
        return try await post(.mcqBatch, body: req, retries: retries)
    }
}

// MARK: - 並行実行ヘルパ（任意）
// サーバのbatchを使わず、単発APIをクライアント側で並行発行したい場合に。

public extension ApiClient {
    /// 1問1答 単発APIを N 件並行で叩く
    func generateSingleQAInParallel(
        pairs: [(answer: String, existing: [String], pattern: ProblemPattern)],
        retries: Int = 1
    ) async -> [SingleQAResponse] {
        await withTaskGroup(of: SingleQAResponse?.self) { group in
            for p in pairs {
                group.addTask {
                    do {
                        return try await self.generateSingleQA(
                            answer: p.answer,
                            existingQuestions: p.existing,
                            pattern: p.pattern,
                            retries: retries
                        )
                    } catch {
                        return nil
                    }
                }
            }
            var results: [SingleQAResponse] = []
            for await r in group {
                if let r { results.append(r) }
            }
            return results
        }
    }

    /// 4択 単発APIを N 件並行で叩く（各要素が1件配列で返る仕様に合わせて flatten）
    func generateSingleMCQInParallel(
        pairs: [(answer: String, existing: [String], pattern: ProblemPattern)],
        retries: Int = 1
    ) async -> [MCQItem] {
        await withTaskGroup(of: [MCQItem]?.self) { group in
            for p in pairs {
                group.addTask {
                    do {
                        return try await self.generateSingleMCQ(
                            answer: p.answer,
                            existingQuestions: p.existing,
                            pattern: p.pattern,
                            retries: retries
                        )
                    } catch {
                        return nil
                    }
                }
            }
            var results: [MCQItem] = []
            for await arr in group {
                if let arr { results.append(contentsOf: arr) }
            }
            return results
        }
    }
}

// MARK: - 使用例（ViewModel内などで）
/*
let api = ApiClient(baseURL: URL(string: "http://localhost:8080")!)

// 1問1答: 単発
let qa1 = try await api.generateSingleQA(
    answer: "遣唐使",
    existingQuestions: [],
    pattern: .ichimonIttou
)

// 1問1答: 一括
let qas = try await api.generateBatchQA(
    answers: ["光合成", "関ヶ原の戦い"],
    pattern: .ichimonIttou
)

// 4択: 単発（配列で1件返る想定）
let mcqArr = try await api.generateSingleMCQ(
    answer: "大宝律令",
    pattern: .ichimonIttou
)
let mcq = mcqArr.first

// クライアント側で並行（単発APIを複数同時に）
let parallel = await api.generateSingleQAInParallel(
    pairs: [
        (answer: "鎖国", existing: [], pattern: .anaume),
        (answer: "朱印船貿易", existing: [], pattern: .anaume)
    ]
)
*/
