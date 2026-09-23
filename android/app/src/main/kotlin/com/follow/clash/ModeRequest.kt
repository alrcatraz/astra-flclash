package com.follow.clash

/**
 * Holds an outbound-mode request that arrived while no Flutter engine was alive
 * (e.g. a Modes-and-Routines shortcut fired after the app was swiped away).
 * MainActivity drains it once Dart is up and applies the mode through the
 * normal in-app path, so the request is never silently lost.
 */
object ModeRequest {
    @Volatile
    var pending: String? = null
}
