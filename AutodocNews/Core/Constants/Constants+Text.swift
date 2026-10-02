import Foundation

extension Constants {
    enum Text {
        enum Network {
            static let offline = "Нет подключения к интернету. Проверьте сеть и попробуйте снова."
            static let timedOut = "Сервер слишком долго не отвечает. Попробуйте ещё раз."
            static let unreadableResponse = "Не удалось обработать ответ сервера."
            static let transport = "Не удалось загрузить данные. Попробуйте ещё раз."

            static func httpStatus(_ code: Int) -> String {
                "Сервер вернул ошибку (\(code))."
            }
        }

        enum Mapping {
            static let missingArticleBody = "Текст новости недоступен. Попробуйте ещё раз."
            static let missingPath = "Новость недоступна."
        }
    }
}
