import UIKit

extension Constants {
    enum Feed {
        enum Layout {
            enum Grid {
                struct ColumnBreakpoint: Sendable {
                    let upperWidth: CGFloat
                    let columnCount: Int
                }

                static let columnBreakpoints = [
                    ColumnBreakpoint(upperWidth: 600, columnCount: 1),
                    ColumnBreakpoint(upperWidth: 900, columnCount: 2),
                    ColumnBreakpoint(upperWidth: 1250, columnCount: 3)
                ]
                static let maximumColumnCount = 4
                static let spacing = Spacing.l
                static let compactHorizontalInset = Spacing.l
                static let wideHorizontalInset = Spacing.xl
            }

            enum Card {
                static let imageAspectRatio: CGFloat = 16.0 / 9.0
                static let titleMaxLines = 3
                static let textInsets = NSDirectionalEdgeInsets(
                    top: Spacing.m,
                    leading: Spacing.m,
                    bottom: Spacing.m,
                    trailing: Spacing.m
                )
                static let badgeToTitleSpacing = Spacing.s
                static let titleToDateSpacing = Spacing.s
            }

            enum Featured {
                static let titleMaxLines = 3
                static let textInsets = NSDirectionalEdgeInsets(
                    top: Spacing.l,
                    leading: Spacing.l,
                    bottom: Spacing.l,
                    trailing: Spacing.l
                )
                static let interitemSpacing = Spacing.s
                static let compactAspectRatio: CGFloat = 16.0 / 9.0
                static let wideAspectRatio: CGFloat = 2.4
                static let maximumHeight: CGFloat = 460
                static let minimumImageReveal = Spacing.xxl
                static let scrimHeightRatio: CGFloat = 0.7
                static let dateTextAlpha: CGFloat = 0.85
            }

            enum Badge {
                static let verticalPadding = Spacing.xs + Spacing.xs
            }

            enum Sections {
                static let featuredItemCount = 1
                static let interSectionSpacing = Spacing.l
                static let featuredTopInset = Spacing.s
                static let bottomInset = Spacing.l
                static let pagingEstimatedHeight: CGFloat = 72
            }

            enum Skeleton {
                static let feedPlaceholderCount = 8
                static let titleLineWidthRatios: [CGFloat] = [1, 0.65]
                static let badgeWidthRatio: CGFloat = 0.3
                static let dateWidthRatio: CGFloat = 0.4
                static let badgeHeight = Spacing.l
                static let lineHeight = Spacing.m
                static let lineSpacing = Spacing.s
            }

            enum PagingFooter {
                static let contentInsets = NSDirectionalEdgeInsets(
                    top: Spacing.l,
                    leading: Spacing.l,
                    bottom: Spacing.l,
                    trailing: Spacing.l
                )
                static let stackSpacing = Spacing.s
            }

            enum Banner {
                static let maximumWidth: CGFloat = 520
                static let edgeInset = Spacing.l
                static let contentInsets = NSDirectionalEdgeInsets(
                    top: Spacing.m,
                    leading: Spacing.l,
                    bottom: Spacing.m,
                    trailing: Spacing.l
                )
            }
        }

        enum Pagination {
            static let nextPageThreshold = 5
        }

        enum Animation {
            static let pressedScale: CGFloat = 0.97
            static let highlightDuration: TimeInterval = 0.18
            static let bannerVisibleDuration: Duration = .seconds(4)
            static let bannerTransitionDuration: TimeInterval = 0.25
            static let bannerHiddenOffset: CGFloat = 16
        }

        enum KeyCommands {
            static let refreshInput = "r"
        }

        enum Text {
            static let screenTitle = "Новости"
            static let retry = "Повторить"
            static let refresh = "Обновить"
            static let refreshDiscoverabilityTitle = "Обновить ленту"
            static let pagingLoadingAccessibilityLabel = "Загрузка новостей"
            static let fallbackErrorMessage = "Не удалось загрузить новости. Попробуйте ещё раз."
            static let failureTitle = "Не удалось загрузить новости"
            static let emptyTitle = "Новостей пока нет"
            static let emptyMessage = "Загляните чуть позже — мы покажем свежие публикации."
            static let share = "Поделиться"
            static let openInSafari = "Открыть в Safari"
            static let copyLink = "Скопировать ссылку"
            static let accessibilityLabelSeparator = ", "

            enum Symbol {
                static let failure = "wifi.exclamationmark"
                static let empty = "newspaper"
                static let share = "square.and.arrow.up"
                static let openInSafari = "safari"
                static let copyLink = "link"
            }
        }

        enum Diagnostics {
            static let nonPositivePageSize = "Размер страницы должен быть положительным"
            static let unknownSection = "Layout запросил секцию, которой нет в data source"
        }

        enum Log {
            static let viewModelCategory = "NewsFeed"

            static func pageLoadFailed(kind: String, page: Int) -> String {
                "Не удалось загрузить страницу \(page) (\(kind)):"
            }
        }
    }
}
