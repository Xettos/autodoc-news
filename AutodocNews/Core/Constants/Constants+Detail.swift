import UIKit

extension Constants {
    enum Detail {
        enum Layout {
            static let heroAspectRatio: CGFloat = 9.0 / 16.0
            static let maxHeroHeight: CGFloat = 460
            static let heroAspectPriority: UILayoutPriority = .defaultHigh + 1
            static let maxColumnWidth: CGFloat = 680
        }

        enum Skeleton {
            static let paragraphLineWidths: [[CGFloat]] = [[1, 0.96, 1, 0.58], [1, 0.92, 0.97, 0.74]]
            static let lineHeight: CGFloat = 14
            static let lineSpacing: CGFloat = 10
            static let lineCornerRadius: CGFloat = lineHeight / 2
        }

        enum Web {
            static let baseURL = URL(string: "https://www.autodoc.ru")
            static let heightMessageName = "contentHeight"
            static let maxContentHeight: CGFloat = 200_000
            static let heightChangeThreshold: CGFloat = 0.5
            static let minimumRenderableHeight: CGFloat = 1
            static let safariSchemes: Set<String> = ["http", "https"]
            static let systemSchemes: Set<String> = ["mailto", "tel"]
            static let blankDocumentAddress = "about:blank"

            static func heightObserverScript(handlerName: String) -> String {
                """
                (() => {
                  const handler = window.webkit.messageHandlers.\(handlerName);
                  const post = () => handler.postMessage(Math.ceil(document.body.getBoundingClientRect().height));
                  new ResizeObserver(post).observe(document.body);
                })();
                """
            }
        }

        enum HTML {
            static let documentLanguage = "ru"
            static let charset = "utf-8"
            static let viewport = "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"
            static let disabledFormatDetection = "telephone=no, email=no, address=no, date=no"
            static let contentSecurityPolicy = "default-src 'none'; img-src https: http: data:; "
                + "media-src https:; frame-src https:; style-src 'unsafe-inline'"

            static func page(stylesheet: String, body: String) -> String {
                """
                <!DOCTYPE html>
                <html lang="\(documentLanguage)">
                <head>
                <meta charset="\(charset)">
                <meta name="viewport" content="\(viewport)">
                <meta name="color-scheme" content="\(CSS.colorScheme)">
                <meta name="format-detection" content="\(disabledFormatDetection)">
                <meta http-equiv="Content-Security-Policy" content="\(contentSecurityPolicy)">
                <style>\(stylesheet)</style>
                </head>
                <body>\(body)</body>
                </html>
                """
            }
        }

        enum CSS {
            enum LightTheme {
                static let text = "#000000"
                static let secondary = "rgba(60, 60, 67, 0.6)"
                static let separator = "rgba(60, 60, 67, 0.29)"
                static let placeholder = "rgba(118, 118, 128, 0.12)"
            }

            enum DarkTheme {
                static let text = "#FFFFFF"
                static let secondary = "rgba(235, 235, 245, 0.6)"
                static let separator = "rgba(84, 84, 88, 0.6)"
                static let placeholder = "rgba(118, 118, 128, 0.24)"
            }

            static let colorScheme = "light dark"
            static let bodyLineHeight = "1.5"
            static let fullWidth = "100%"
            static let textSizeAdjust = "100%"
            static let blockSpacing = "1em"
            static let headingFontSize = "1.15em"
            static let headingLineHeight = "1.3"
            static let headingMargin = "1.2em 0 0.5em"
            static let strongFontWeight = "600"
            static let mediaMargin = "16px"
            static let mediaCornerRadius = "12px"
            static let imagePlaceholderAspectRatio = "3 / 2"
            static let embedAspectRatio = "16 / 9"
            static let quoteIndent = "12px"
            static let quoteBorderWidth = "3px"
            static let listIndent = "1.4em"
            static let hairline = "1px"
            static let ruleMargin = "1.5em 0"
            static let cellPadding = "6px 8px"

            static let ruleBlockSeparator = "\n"

            static let rgbaFormat = "rgba(%d, %d, %d, %.3f)"
            static let colorChannelScale: Double = 255

            enum Rules {
                static func themeVariables(lightLink: String, darkLink: String) -> String {
                    """
                    :root {
                      color-scheme: \(colorScheme);
                      --text: \(LightTheme.text);
                      --secondary: \(LightTheme.secondary);
                      --separator: \(LightTheme.separator);
                      --placeholder: \(LightTheme.placeholder);
                      --link: \(lightLink);
                    }
                    @media (prefers-color-scheme: dark) {
                      :root {
                        --text: \(DarkTheme.text);
                        --secondary: \(DarkTheme.secondary);
                        --separator: \(DarkTheme.separator);
                        --placeholder: \(DarkTheme.placeholder);
                        --link: \(darkLink);
                      }
                    }
                    """
                }

                static let body = """
                    html { -webkit-text-size-adjust: \(textSizeAdjust); }
                    body {
                      margin: 0; padding: 0;
                      display: flow-root;
                      background: transparent;
                      color: var(--text);
                      font: -apple-system-body;
                      line-height: \(bodyLineHeight);
                      overflow-wrap: break-word;
                      -webkit-hyphens: auto; hyphens: auto;
                      -webkit-tap-highlight-color: transparent;
                    }
                    """

                static let cmsReset = """
                    body * {
                      float: none !important;
                      position: static !important;
                      max-width: \(fullWidth) !important;
                      margin-left: 0 !important; margin-right: 0 !important;
                      box-sizing: border-box;
                    }
                    body *:not(img):not(iframe):not(video) { width: auto !important; height: auto !important; }
                    body > :first-child, body > :first-child > :first-child { margin-top: 0 !important; }
                    body > :last-child, body > :last-child > :last-child { margin-bottom: 0 !important; }
                    """

                static let text = """
                    p, div, ul, ol, blockquote, table, figure { margin-top: 0; margin-bottom: \(blockSpacing); }
                    div div { margin-bottom: 0; }
                    h1, h2, h3, h4, h5, h6 {
                      font-size: \(headingFontSize);
                      line-height: \(headingLineHeight);
                      margin: \(headingMargin);
                    }
                    a { color: var(--link); text-decoration: none; }
                    b, strong { font-weight: \(strongFontWeight); }
                    """

                static let media = """
                    img {
                      display: block;
                      width: \(fullWidth) !important; height: auto !important;
                      aspect-ratio: auto \(imagePlaceholderAspectRatio);
                      object-fit: contain;
                      margin: \(mediaMargin) 0 !important;
                      border: 0 !important;
                      border-radius: \(mediaCornerRadius);
                      background: var(--placeholder);
                    }
                    iframe, video {
                      display: block;
                      width: \(fullWidth) !important; height: auto !important;
                      aspect-ratio: \(embedAspectRatio);
                      margin: \(mediaMargin) 0 !important;
                      border: 0; border-radius: \(mediaCornerRadius);
                    }
                    """

                static let blocks = """
                    blockquote {
                      padding-left: \(quoteIndent);
                      border-left: \(quoteBorderWidth) solid var(--link);
                      color: var(--secondary);
                    }
                    ul, ol { padding-left: \(listIndent); }
                    hr { border: 0; border-top: \(hairline) solid var(--separator); margin: \(ruleMargin); }
                    table { display: block; overflow-x: auto; border-collapse: collapse; }
                    td, th { border: \(hairline) solid var(--separator); padding: \(cellPadding); }
                    """
            }
        }

        enum Cleaner {
            static let emptyBlockPattern = #"<(p|div)\b[^>]*>(?:\s|&nbsp;|&#160;|<br\s*/?>)*</\1>"#
            static let leadingLineBreaksPattern = #"^(?:\s|<br\s*/?>)+"#
            static let trailingLineBreaksPattern = #"(?<!\s)(?:\s|<br\s*/?>)++\z"#
            static let schemeSeparator = "//"
            static let optionalHTTPSchemePattern = "(?:https?:)?"
            static let ampersand = "&"
            static let ampersandPattern = "(?:&|&amp;)"

            static func imageSourcePattern(address: String) -> String {
                #"\ssrc\s*=\s*(?:"\#(address)"|'\#(address)')"#
            }

            static func imagePattern(source: String) -> String {
                #"<img\b[^>]*?\#(source)[^>]*>"#
            }

            static func linkedImagePattern(image: String) -> String {
                #"<a\b[^>]*>\s*\#(image)\s*</a>|\#(image)"#
            }
        }

        enum Text {
            static let share = "Поделиться"
            static let openInSafari = "Открыть в Safari"
            static let retry = "Повторить"
            static let publishedAccessibilityFormat = "Опубликовано %@"
            static let loadingAccessibilityLabel = "Загрузка текста новости"
        }

        enum Symbol {
            static let share = "square.and.arrow.up"
            static let safari = "safari"
            static let error = "exclamationmark.triangle"
            static let retry = "arrow.clockwise"
        }

        enum Animation {
            static let revealDuration: TimeInterval = 0.25
        }

        enum Log {
            static let viewModelCategory = "NewsDetail"
            static let webViewCategory = "ArticleWebView"
            static let articleLoadFailed = "Не удалось загрузить статью"
            static let articleRenderFailed = "Ошибка отрисовки статьи"
            static let invalidPattern = "Некорректный шаблон регулярного выражения"
            static let contentAlreadyAligned = "alignContent(to:) уже вызван: повтор продублировал бы констрейнты"
        }
    }
}
