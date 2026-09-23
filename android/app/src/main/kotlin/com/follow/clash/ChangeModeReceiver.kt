package com.follow.clash

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.follow.clash.common.Components
import com.follow.clash.common.QuickAction
import com.follow.clash.common.action
import com.follow.clash.common.intent

/**
 * Changes the outbound mode (rule / global / direct) from external automation —
 * Samsung Modes and Routines, Tasker, or `adb shell am broadcast` — without
 * bringing up any UI. The receiver only relays the request to [QuickActionActivity],
 * which owns the single execution path shared with app shortcuts and QS tiles;
 * the actual mode change happens on the Flutter side (AppPlugin.changeMode).
 */
class ChangeModeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val mode = intent.getStringExtra(EXTRA_MODE) ?: return
        val action = when (mode) {
            "rule" -> QuickAction.MODE_RULE
            "global" -> QuickAction.MODE_GLOBAL
            "direct" -> QuickAction.MODE_DIRECT
            else -> return
        }
        val startIntent = Components.quickActionActivity.intent.apply {
            this.action = action.action
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_MULTIPLE_TASK)
            putExtra(EXTRA_MODE, mode)
        }
        context.startActivity(startIntent)
    }

    companion object {
        const val EXTRA_MODE = "mode"
    }
}

