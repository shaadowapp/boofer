package com.shaadow.boofer.android

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

private const val TAG = "BooferWidget"

class UnreadListWidgetReceiver : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        Log.d(TAG, "onUpdate: ${appWidgetIds.size} widget(s)")
        // Log what data is currently in SharedPrefs (from Flutter)
        val json = widgetData.getString("unread_messages_json", "NOT SET")
        Log.d(TAG, "onUpdate: SharedPrefs unread_messages_json = $json")
        updateAllWidgets(context, appWidgetManager, appWidgetIds)
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "onReceive: action=${intent.action}")
        super.onReceive(context, intent)
        if (intent.action == "es.antonborri.home_widget.action.UPDATE" ||
            intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, UnreadListWidgetReceiver::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)
            Log.d(TAG, "onReceive: triggering full update for ${appWidgetIds.size} widget(s) in 200ms...")
            
            // DELAY: Fixes the 'showing previous/stale message' bug by giving OS 
            // a moment to flush the SharedPreferences written by Flutter.
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                updateAllWidgets(context, appWidgetManager, appWidgetIds)
            }, 200)
        }
    }

    companion object {
        fun updateAllWidgets(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray
        ) {
            for (appWidgetId in appWidgetIds) {
                Log.d(TAG, "updateAllWidgets: updating widget $appWidgetId")
                val views = RemoteViews(context.packageName, R.layout.unread_list_layout)

                val ts = System.currentTimeMillis()
                val serviceIntent = Intent(context, UnreadListWidgetService::class.java).apply {
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                    data = Uri.parse("boofer://widget/unread/$appWidgetId?t=$ts")
                }
                Log.d(TAG, "updateAllWidgets: serviceIntent URI = boofer://widget/unread/$appWidgetId?t=$ts")

                views.setRemoteAdapter(R.id.unread_list_view, serviceIntent)
                views.setEmptyView(R.id.unread_list_view, R.id.empty_unread_text)

                val clickIntent = Intent(Intent.ACTION_VIEW).apply {
                    setPackage(context.packageName)
                }
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    clickIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                )
                views.setPendingIntentTemplate(R.id.unread_list_view, pendingIntent)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.unread_list_view)
                Log.d(TAG, "updateAllWidgets: done for widget $appWidgetId")
            }
        }
    }
}
