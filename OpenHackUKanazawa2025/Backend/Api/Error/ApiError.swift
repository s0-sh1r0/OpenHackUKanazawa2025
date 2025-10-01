import Foundation
/// API エラー
public enum APIError: Error, LocalizedError {
    case invalidURL
    case encodingFailed
    case transport(Error)
    case server(status: Int, data: Data?)
    case decodingFailed(Error)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "URLが不正です"
        case .encodingFailed: return "JSONエンコードに失敗しました"
        case .transport(let e): return "通信エラー: \(e.localizedDescription)"
        case .server(let status, _): return "サーバエラー: HTTP \(status)"
        case .decodingFailed(let e): return "JSONデコードに失敗: \(e.localizedDescription)"
        case .cancelled: return "キャンセルされました"
        }
    }
}
