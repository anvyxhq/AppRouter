# AppRouter

> Type-safe navigation, deep linking, and multi-step flows for SwiftUI apps.

![Swift](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)
![Platform](https://img.shields.io/badge/iOS-17%2B-000000?logo=apple)
![SPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen)
![License](https://img.shields.io/badge/License-MIT-blue)

AppRouter is the navigation layer for app shells: a router, tab routing, deep-link parsing/resolution, and coordinator-style flows — replacing ad-hoc `push`/`present` calls with declarative routes.

## Features

- **Routing** — `Router` and `TabRouter` for programmatic navigation and tab management.
- **Deep links** — `DeepLinkParser` / `DeepLinkResolver` map URLs and universal links to typed destinations.
- **Flows** — `Flow`, `FlowStep`, and `RouterFlowPresenter` model multi-step journeys (onboarding, wizards).
- **Transitions** — `Route` and `Style` describe destinations and presentation style.

No third-party dependencies.

## Requirements

- iOS 17.0+
- Swift 5.9+ / Xcode 16+

## Installation

```swift
.package(url: "https://github.com/anvyxhq/AppRouter.git", branch: "main"),
```

Add `AnvyxRouterKit` to your target.

## Usage

```swift
import AnvyxRouterKit

let router = Router()
router.push(.settings)

// Deep link
if let destination = DeepLinkResolver.shared.resolve(url) {
    router.navigate(to: destination)
}
```

## Modules

| Product | Description |
| --- | --- |
| `AnvyxRouterKit` | Router, tab routing, deep-link parsing/resolution, and multi-step flows. |

## License

MIT — see [LICENSE](LICENSE).
