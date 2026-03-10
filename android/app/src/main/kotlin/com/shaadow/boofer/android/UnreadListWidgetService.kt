package com.shaadow.boofer.android

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

private const val TAG = "BooferWidget"

class UnreadListWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        Log.d(TAG, "onGetViewFactory called for intent: ${intent.data}")
        return UnreadListWidgetFactory(applicationContext)
    }
}

class UnreadListWidgetFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var messages: JSONArray = JSONArray()

    private fun loadData() {
        val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonStr = prefs.getString("unread_messages_json", "[]")
        Log.d(TAG, "loadData: raw JSON from SharedPrefs = $jsonStr")
        messages = try {
            val arr = JSONArray(jsonStr ?: "[]")
            Log.d(TAG, "loadData: parsed ${arr.length()} messages")
            arr
        } catch (e: Exception) {
            Log.e(TAG, "loadData: JSON parse error: ${e.message}")
            JSONArray()
        }
    }

    override fun onCreate() {
        Log.d(TAG, "Factory onCreate")
        loadData()
    }

    override fun onDataSetChanged() {
        Log.d(TAG, "onDataSetChanged triggered")
        loadData()
        Log.d(TAG, "onDataSetChanged done, count=${messages.length()}")
    }

    override fun onDestroy() {
        Log.d(TAG, "Factory onDestroy")
    }

    override fun getCount(): Int {
        Log.d(TAG, "getCount = ${messages.length()}")
        return messages.length()
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.unread_list_item)
        if (position >= messages.length()) {
            Log.w(TAG, "getViewAt: position $position >= count ${messages.length()}")
            return views
        }
        try {
            val msg = messages.getJSONObject(position)
            val name = msg.optString("name", "")
            val handle = msg.optString("handle", "")
            val content = msg.optString("content", "")
            val time = msg.optString("time", "")

            Log.d(TAG, "getViewAt[$position]: name=$name handle=$handle content=$content")

            views.setTextViewText(R.id.item_name, name)
            views.setTextViewText(R.id.item_message, content)
            views.setTextViewText(R.id.item_time, time)

            if (handle.equals("boofer", ignoreCase = true) || name.equals("Boofer", ignoreCase = true)) {
                views.setViewVisibility(R.id.item_avatar, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.item_avatar, android.view.View.GONE)
            }

            val fillInIntent = Intent().apply {
                data = Uri.parse("https://booferapp.github.io/c/$handle")
            }
            views.setOnClickFillInIntent(R.id.widget_item_root, fillInIntent)
        } catch (e: Exception) {
            Log.e(TAG, "getViewAt[$position] error: ${e.message}")
        }
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false
}
