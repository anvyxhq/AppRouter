# ``AnvyxRouterKit``

Type-safe SwiftUI navigation: an `@Observable` router, tab routing, flow
sequencing, deep-link / universal-link resolution, state restoration, and a
transition catalogue.

## Overview

``Router`` wraps `NavigationPath` plus sheet/cover presentation, generic over your
app's ``Route`` type. Resolve incoming URLs with a ``LinkRegistry`` or
``DeepLinkResolver``, restore state with ``RouterState``, and animate with
``RouteTransition``.

```swift
@State private var router = Router<AppRoute>()
router.push(.detail(id: 3))
router.open(url, using: linkRegistry)      // universal links -> routes
```

## Topics

### Routing
- ``Router``
- ``Route``
- ``TabRouter``
- ``RouterState``

### Deep Links
- ``DeepLinkParser``
- ``DeepLinkResolver``
- ``DeepLinkDestination``
- ``LinkRegistry``
- ``LinkPattern``
- ``LinkParameters``

### Flows
- ``Flow``
- ``FlowStep``
- ``RouterFlowPresenter``

### Transitions
- ``RouteTransition``
- ``RouteTransitionStyle``
