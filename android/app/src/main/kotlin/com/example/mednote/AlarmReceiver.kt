package com.example.mednote

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val args = intent.getSerializableExtra("args") as? HashMap<*, *> ?: return
        NotificationHelper.showDoseNotification(context, args)
    }
}
