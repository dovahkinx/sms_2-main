package com.dovahkin.sms_guard

 import android.app.*
 import android.content.Context
 import android.content.Intent
 import android.content.IntentFilter
 import android.os.Build
 import android.os.IBinder
 import androidx.core.app.NotificationCompat


 class MyService : Service() {
     private val notificationId = 1
     private lateinit var notificationManager: NotificationManager
     private lateinit var receiver:  SMSReciver

     override fun onCreate() {
         println("Service created")
         super.onCreate()
         notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
         receiver = SMSReciver(null)
     }

     override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
         println("Service started")
         val notification = createNotification()
         // startForeground(-1, notification)

         val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
         registerReceiver(receiver, filter)

         return START_STICKY
     }

     override fun onDestroy() {
         println("Service destroyed")
         super.onDestroy()
         unregisterReceiver(receiver)
     }

     override fun onBind(intent: Intent): IBinder? {
         println(    "Service bound")
         return null
     }

     private fun createNotification(): Notification {
         println("Service notification created")
         val notificationChannelId = "channel_id"
         val notificationTitle = "My Service"
         val notificationText = "Service is running in foreground"
         val notificationChannel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
             NotificationChannel(
                 notificationChannelId,
                 "My Service",
                 NotificationManager.IMPORTANCE_HIGH
             )
         } else {
             TODO("VERSION.SDK_INT < O")
         }
         notificationManager.createNotificationChannel(notificationChannel)
         
         val notificationIntent = Intent(this, MainActivity::class.java)
         
         // Add FLAG_IMMUTABLE to address security warning
         val pendingIntentFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
             PendingIntent.FLAG_IMMUTABLE
         } else {
             0
         }
         
         val pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent, pendingIntentFlag)
         
         return NotificationCompat.Builder(this, notificationChannelId)
             .setContentTitle(notificationTitle)
             .setContentText(notificationText)
             .setSmallIcon(R.drawable.launch_background)
             .setContentIntent(pendingIntent)
             .setAutoCancel(true)
             .build()
     }


 }