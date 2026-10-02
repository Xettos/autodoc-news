import Foundation

extension Constants {
    enum App {
        static let sceneConfigurationName = "Default Configuration"

        enum Log {
            static let subsystem = "ru.autodoc.test.news"
            static let networkingCategory = "Networking"
            static let decodingCategory = "Decoding"
            static let imageLoadingCategory = "ImageLoading"
        }

        enum Diagnostics {
            static let invalidBaseURL = "Некорректный базовый URL API"
            static let invalidPageRequest = "Нумерация страниц API начинается с 1"
            static let decodingFailed = "Ошибка декодирования"
            static let skippedBrokenItem = "Пропущен некорректный элемент"
            static let skippedUnmappableItem = "Пропущена новость без пути"
            static let unmappableArticle = "Статья не прошла маппинг"
            static let imageLoadFailed = "Не удалось загрузить картинку"
            static let missingCoordinatorFactory = "AppDelegate не отдал CoordinatorFactory — сцена останется пустой"
            static let codingPathSeparator = "."
        }
    }
}
