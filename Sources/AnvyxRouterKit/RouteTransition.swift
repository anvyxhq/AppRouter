//
//  RouteTransition.swift
//  AppRouter
//
//  Created by AnhPT on 13/07/2026.
//

import SwiftUI

/// A catalogue of reusable content transitions, so screen/motion changes stay
/// consistent across the app. Apply with `View.routeTransition(_:)` or
/// use the raw `AnyTransition` values directly with `.transition(_:)`.
public enum RouteTransition {

    /// iOS-style push: in from the trailing edge, out to the leading edge (fading).
    public static var push: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing),
            removal: .move(edge: .leading)
        ).combined(with: .opacity)
    }

    /// Modal cover rising from the bottom.
    public static var cover: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }

    /// Simple crossfade.
    public static var fade: AnyTransition { .opacity }

    /// Gentle scale-up with a fade — good for cards and modals.
    public static var scale: AnyTransition {
        .scale(scale: 0.92).combined(with: .opacity)
    }

    /// Subtle zoom for hero/preview presentations.
    public static var zoom: AnyTransition {
        .scale(scale: 1.06).combined(with: .opacity)
    }

    /// A 3D flip around the vertical axis.
    public static var flip: AnyTransition {
        .modifier(
            active: FlipModifier(angle: 90),
            identity: FlipModifier(angle: 0)
        )
    }

    /// Slide in from `edge` and out to the opposite edge (fading).
    public static func slide(from edge: Edge) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: edge),
            removal: .move(edge: edge.opposite)
        ).combined(with: .opacity)
    }
}

/// A named transition + its paired animation, so a screen can pick a style
/// declaratively (e.g. from config or a route's metadata).
public enum RouteTransitionStyle: String, Sendable, CaseIterable {
    case push, cover, fade, scale, zoom, flip

    public var transition: AnyTransition {
        switch self {
        case .push:  RouteTransition.push
        case .cover: RouteTransition.cover
        case .fade:  RouteTransition.fade
        case .scale: RouteTransition.scale
        case .zoom:  RouteTransition.zoom
        case .flip:  RouteTransition.flip
        }
    }

    /// The animation curve that best complements this transition.
    public var animation: Animation {
        switch self {
        case .push, .cover: .spring(response: 0.4, dampingFraction: 0.85)
        case .fade:         .easeInOut(duration: 0.2)
        case .scale, .zoom: .spring(response: 0.35, dampingFraction: 0.8)
        case .flip:         .easeInOut(duration: 0.35)
        }
    }
}

public extension View {
    /// Apply a catalogued ``RouteTransitionStyle`` to conditionally-shown content.
    func routeTransition(_ style: RouteTransitionStyle) -> some View {
        transition(style.transition)
    }
}

// MARK: - Navigation zoom transition (iOS 18)

@available(iOS 18, *)
public extension View {
    /// Mark this view as the source of a zoom navigation transition.
    func anvyxTransitionSource(id: some Hashable & Sendable, in namespace: Namespace.ID) -> some View {
        matchedTransitionSource(id: id, in: namespace)
    }

    /// Zoom into this destination from a matching ``anvyxTransitionSource(id:in:)``.
    func anvyxZoomTransition(sourceID: some Hashable & Sendable, in namespace: Namespace.ID) -> some View {
        navigationTransition(.zoom(sourceID: sourceID, in: namespace))
    }
}

// MARK: - Private

private struct FlipModifier: ViewModifier {
    let angle: Double
    func body(content: Content) -> some View {
        content.rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))
    }
}

private extension Edge {
    var opposite: Edge {
        switch self {
        case .top: .bottom
        case .bottom: .top
        case .leading: .trailing
        case .trailing: .leading
        }
    }
}
