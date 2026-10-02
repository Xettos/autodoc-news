# Автодок Новости

Тестовое задание: лента новостей из `https://webapi.autodoc.ru/api/news/{page}/{pageSize}` и экран полной новости.

UIKit без storyboard, MVVM + Combine, `UICollectionView` с `UICollectionViewCompositionalLayout` и `UICollectionViewDiffableDataSource`, async/await, Swift 6. Сторонних библиотек нет.

## Запуск

- Xcode 26+, iOS 17+ (iPhone и iPad)
- Открыть `AutodocNews.xcodeproj`, схема `AutodocNews`
- Тесты: `⌘U`

## Что сделано

**Лента**
- Постраничная загрузка с дозагрузкой при прокрутке, pull-to-refresh, повтор при ошибке
- Первая новость крупной карточкой, остальные сеткой
- Скелетон при первой загрузке, экраны ошибки и пустой ленты
- Дубли между страницами отбрасываются (страницы API сдвигаются, когда выходят новые новости)

**Экран новости**
- Шапка (обложка, категория, дата, заголовок) показывается сразу из данных ленты
- Текст статьи загружается с `/api/news/item/{url}` и выводится в `WKWebView` с отключённым JavaScript
- «Поделиться», «Открыть в Safari», ссылки из текста открываются в `SFSafariViewController`

**iPad**
- 1–4 колонки в зависимости от ширины окна: поворот, Split View, Stage Manager
- Текст статьи ограничен по ширине колонкой
- Zoom-переход из карточки в статью (iOS 18+)
- Контекстное меню, drag & drop ссылки, `⌘R` для обновления, несколько окон

## Архитектура

```
App            AppDependencies, AppCoordinator, SceneDelegate
Features       NewsFeed, NewsDetail (ViewController + ViewModel)
Domain         NewsItem, NewsArticle, NewsPage, NewsRepository
Data           RemoteNewsRepository, DTO, маппинг
Core           Networking, ImageLoading, UI, Formatting, Constants
```

- Зависимости закрыты протоколами и передаются через `init`. Конкретные типы создаются только в `AppDependencies`.
- ViewModel не импортирует UIKit, состояние отдаёт через Combine, навигация вынесена в координатор.
- Все значения и тексты лежат в `Constants`, разбитом по областям (`Constants+API`, `Constants+Feed`, `Constants+Detail` и т. д.).

## Производительность

- Высоты карточек вычисляются из ширины колонки и Dynamic Type, self-sizing не используется.
- В снапшоте diffable data source только идентификаторы новостей; новые страницы добавляются к снапшоту без полной пересборки.
- Загрузка картинок своя:
  - кэш декодированных изображений в `NSCache` и дисковый `URLCache`;
  - одинаковые запросы (ячейка и prefetch) объединяются в одну загрузку, которая отменяется, когда уходит последний подписчик;
  - картинки декодируются через ImageIO сразу в размер ячейки, вне главного потока, не больше двух одновременно;
  - зависшая загрузка обрывается по таймауту и повторяется.
- Prefetching картинок и следующей страницы.
- HTML статьи очищается вне главного потока, высота `WKWebView` подстраивается под контент.

## Тесты

Swift Testing, 230 тестов:
- ViewModel ленты и статьи: пагинация, refresh, гонки, ошибки
- маппинг DTO и разбор дат
- сетевой клиент на подменённом `URLProtocol`
- загрузка картинок: дедупликация, отмена, декодирование
- очистка HTML и политика навигации `WKWebView`
- раскладка сетки
