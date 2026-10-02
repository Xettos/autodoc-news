import Foundation

enum NewsEndpoints {
    private typealias Path = Constants.API.Path

    static func page(_ page: Int, size: Int) -> Endpoint<NewsPageDTO> {
        assert(page >= Constants.API.firstPage && size > 0, Constants.App.Diagnostics.invalidPageRequest)
        return Endpoint(path: joined(Path.news, String(page), String(size)))
    }

    static func article(path: String) -> Endpoint<NewsArticleDTO> {
        let normalizedPath = path.trimmingCharacters(in: CharacterSet(charactersIn: Path.separator))
        return Endpoint(path: joined(Path.news, Path.articleItem, normalizedPath))
    }

    private static func joined(_ components: String...) -> String {
        components.joined(separator: Path.separator)
    }
}
