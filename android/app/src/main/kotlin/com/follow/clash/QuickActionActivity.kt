package com.follow.clash

import android.app.Activity
import android.os.Bundle
import androidx.core.content.pm.ShortcutManagerCompat
import com.follow.clash.common.Components
import com.follow.clash.common.GlobalState
import com.follow.clash.common.QuickAction
import com.follow.clash.common.action
import com.follow.clash.common.intent
import com.follow.clash.plugins.AppPlugin
import kotlinx.coroutines.launch

class QuickActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent.action) {
            QuickAction.START.action -> GlobalState.launch { ServiceState.handleStartAction() }
            QuickAction.STOP.action -> GlobalState.launch { ServiceState.handleStopAction() }
            QuickAction.TOGGLE.action -> {
                ShortcutManagerCompat.reportShortcutUsed(this, SHORTCUT_ID)
                GlobalState.launch { ServiceState.handleToggleAction() }
            }
            QuickAction.MODE_RULE.action,
            QuickAction.MODE_GLOBAL.action,
            QuickAction.MODE_DIRECT.action -> {
                val mode = intent.modeFromAction() ?: return finish()
                ShortcutManagerCompat.reportShortcutUsed(this, mode)
                if (!AppPlugin.changeMode(mode)) {
                    // No live Flutter engine (app fully dead): the UI-less path
                    // cannot patch the running core. Defer to a cold start —
                    // MainActivity will apply the requested mode once Dart is up.
                    ModeRequest.pending = mode
                    startActivity(
                        Components.mainActivity.intent.apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        },
                    )
                }
            }
        }
        finish()
    }

    private fun Intent.modeFromAction(): String? = when (action) {
        QuickAction.MODE_RULE.action -> "rule"
        QuickAction.MODE_GLOBAL.action -> "global"
        QuickAction.MODE_DIRECT.action -> "direct"
        else -> null
    }

    private companion object {
        const val SHORTCUT_ID = "toggle"
    }
}
