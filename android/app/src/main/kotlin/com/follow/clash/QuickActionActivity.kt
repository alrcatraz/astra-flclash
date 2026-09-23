package com.follow.clash

import android.app.Activity
import android.os.Bundle
import androidx.core.content.pm.ShortcutManagerCompat
import com.follow.clash.common.Components
import com.follow.clash.common.GlobalState
import com.follow.clash.common.QuickAction
import com.follow.clash.common.action
import com.follow.clash.common.intent
import com.follow.clash.common.mode
import com.follow.clash.plugins.AppPlugin
import kotlinx.coroutines.launch

class QuickActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (val quickAction = QuickAction.entries.firstOrNull { it.action == intent.action }) {
            QuickAction.START -> GlobalState.launch { ServiceState.handleStartAction() }
            QuickAction.STOP -> GlobalState.launch { ServiceState.handleStopAction() }
            QuickAction.TOGGLE -> {
                ShortcutManagerCompat.reportShortcutUsed(this, SHORTCUT_ID)
                GlobalState.launch { ServiceState.handleToggleAction() }
            }
            QuickAction.MODE_RULE,
            QuickAction.MODE_GLOBAL,
            QuickAction.MODE_DIRECT -> {
                val mode = quickAction?.mode ?: return finish()
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
            null -> Unit
        }
        if (intent.action == ACTION_SELECT_PROFILE) {
            val id = intent.getIntExtra(EXTRA_PROFILE_ID, -1)
            if (id >= 0 && !AppPlugin.selectProfile(id)) {
                ModeRequest.pendingProfileId = id
                startActivity(
                    Components.mainActivity.intent.apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    },
                )
            }
        }
        finish()
    }

    private companion object {
        const val SHORTCUT_ID = "toggle"
        const val ACTION_SELECT_PROFILE = "com.follow.clash.action.SELECT_PROFILE"
        const val EXTRA_PROFILE_ID = "profile_id"
    }
}
