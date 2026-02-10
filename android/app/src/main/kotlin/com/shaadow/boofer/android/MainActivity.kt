package com.shaadow.boofer.android

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.shaadow.boofer/settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Create notification channels for Android 8.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createNotificationChannels()
        }

        // Set up method channel for opening settings
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    openNotificationSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openNotificationSettings() {
        val intent = Intent()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            intent.action = Settings.ACTION_APP_NOTIFICATION_SETTINGS
            intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            intent.action = Settings.ACTION_APPLICATION_DETAILS_SETTINGS
            intent.data = android.net.Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Default sound and vibration attributes
            val defaultSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val audioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            // 1. Messages Channel
            val messagesChannel = NotificationChannel(
                "messages",
                "Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for new direct messages"
                enableLights(true)
                enableVibration(true)
                setSound(defaultSound, audioAttributes)
                setShowBadge(true)
            }

            // 2. Group Messages Channel
            val groupMessagesChannel = NotificationChannel(
                "group_messages",
                "Group Messages",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for group chat messages"
                enableLights(true)
                enableVibration(true)
                setSound(defaultSound, audioAttributes)
                setShowBadge(true)
            }

            // 3. Friend Requests Channel
            val friendRequestsChannel = NotificationChannel(
                "friend_requests",
                "Friend Requests",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for new friend requests and acceptances"
                enableLights(true)
                enableVibration(true)
                setSound(defaultSound, audioAttributes)
                setShowBadge(true)
            }

            // 4. Calls Channel (Highest priority)
            val callsChannel = NotificationChannel(
                "calls",
                "Calls",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for incoming voice and video calls"
                enableLights(true)
                enableVibration(true)
                setSound(defaultSound, audioAttributes)
                setShowBadge(true)
                setBypassDnd(true) // Allow calls to bypass Do Not Disturb
            }

            // 5. Missed Calls Channel
            val missedCallsChannel = NotificationChannel(
                "missed_calls",
                "Missed Calls",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for missed calls"
                enableLights(true)
                enableVibration(false)
                setSound(defaultSound, audioAttributes)
                setShowBadge(true)
            }

            // 6. System Alerts Channel
            val systemAlertsChannel = NotificationChannel(
                "system_alerts",
                "System Alerts",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Important app updates and system notifications"
                enableLights(false)
                enableVibration(false)
                setSound(defaultSound, audioAttributes)
                setShowBadge(false)
            }

            // 7. Security Alerts Channel (Highest priority)
            val securityAlertsChannel = NotificationChannel(
                "security_alerts",
                "Security Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Critical security and privacy notifications"
                enableLights(true)
                enableVibration(true)
                setSound(defaultSound, audioAttributes)
                setShowBadge(true)
                setBypassDnd(true) // Security alerts bypass Do Not Disturb
            }

            // 8. Mentions & Replies Channel
            val mentionsChannel = NotificationChannel(
                "mentions",
                "Mentions & Replies",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "When someone mentions you or replies to your message"
                enableLights(true)
                enableVibration(true)
                setSound(defaultSound, audioAttributes)
                setShowBadge(true)
            }

            // 9. Reactions Channel (Low priority)
            val reactionsChannel = NotificationChannel(
                "reactions",
                "Reactions",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "When someone reacts to your messages"
                enableLights(false)
                enableVibration(false)
                setSound(null, null) // Silent notifications
                setShowBadge(false)
            }

            // 10. General Notifications Channel
            val generalChannel = NotificationChannel(
                "general",
                "General Notifications",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Other app notifications"
                enableLights(false)
                enableVibration(false)
                setSound(defaultSound, audioAttributes)
                setShowBadge(false)
            }

            // Create all channels
            notificationManager.createNotificationChannels(
                listOf(
                    messagesChannel,
                    groupMessagesChannel,
                    friendRequestsChannel,
                    callsChannel,
                    missedCallsChannel,
                    systemAlertsChannel,
                    securityAlertsChannel,
                    mentionsChannel,
                    reactionsChannel,
                    generalChannel
                )
            )
        }
    }
}