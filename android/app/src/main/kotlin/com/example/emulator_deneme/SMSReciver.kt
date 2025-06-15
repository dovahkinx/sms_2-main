package com.dovahkin.sms_guard

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.ContactsContract
import android.provider.Telephony
import android.telephony.SmsMessage
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.core.Delegate
import com.google.mediapipe.tasks.text.textclassifier.TextClassifier
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.ConcurrentHashMap

// BroadcastReceiver olarak tanımlanmış SMS alıcısı
class SMSReciver(private val eventSink: EventChannel.EventSink?) : BroadcastReceiver() {

    // companion object: Sınıfın statik üyelerini (sabitler, statik metotlar) barındırır.
    companion object {
        private const val TAG = "SMSReciver" // Log için etiket
        const val NOTIFICATION_CHANNEL_ID = "sms_notification_channel"
        const val NOTIFICATION_CHANNEL_HIGH_ID = "sms_notification_high_channel" // Yüksek öncelikli kanal

        // Son 5 saniye içinde gösterilen bildirimleri izlemek için bir cache
        private val recentNotifications = ConcurrentHashMap<String, Long>()

        // Bildirimlerin tekrarlanmasını engellemek için kullanılan süre (milisaniye)
        private const val NOTIFICATION_DEBOUNCE_TIME = 5000L // 5 saniye

        /**
         * Belirtilen bildirim anahtarının son 'NOTIFICATION_DEBOUNCE_TIME' içinde gösterilip gösterilmediğini kontrol eder.
         */
        fun shouldShowNotification(uniqueKey: String): Boolean {
            val now = System.currentTimeMillis()
            val lastShown = recentNotifications[uniqueKey]

            if (lastShown == null || now - lastShown > NOTIFICATION_DEBOUNCE_TIME) {
                recentNotifications[uniqueKey] = now
                Log.d(TAG, "Allowing notification for key: $uniqueKey.")
                return true
            }
            Log.d(TAG, "Skipping notification for key: $uniqueKey due to debounce.")
            return false
        }

        // Bildirim sesi çalmak için MediaPlayer örneği
        @SuppressLint("StaticFieldLeak")
        private var mediaPlayer: MediaPlayer? = null

        /**
         * Varsayılan bildirim sesini çalar ve titreşim verir.
         */
        fun playNotificationSound(context: Context) {
            try {
                stopNotificationSound()
                val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

                mediaPlayer = MediaPlayer().apply {
                    setDataSource(context.applicationContext, soundUri)
                    setAudioAttributes(
                        AudioAttributes.Builder()
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                            .build()
                    )
                    setOnCompletionListener { mp -> mp.release() }
                    prepare()
                    start()
                }
                vibrate(context)
                Log.d(TAG, "Notification sound played successfully.")
            } catch (e: Exception) {
                Log.e(TAG, "Error playing notification sound: ${e.message}", e)
            }
        }

        /**
         * Çalmakta olan bildirim sesini durdurur ve MediaPlayer'ı serbest bırakır.
         */
        fun stopNotificationSound() {
            try {
                mediaPlayer?.let {
                    if (it.isPlaying) {
                        it.stop()
                    }
                    it.release()
                }
                mediaPlayer = null
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping notification sound: ${e.message}", e)
            }
        }

        /**
         * Cihaza titreşim verir.
         */
        fun vibrate(context: Context) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                    val vibrator = vibratorManager.defaultVibrator
                    vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(500)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error during vibration: ${e.message}", e)
            }
        }
    }

    // Sistem tarafından çağrılacak varsayılan yapıcı
    constructor() : this(null)

    /**
     * BroadcastReceiver'ın ana alım metodu. Yeni SMS mesajları burada işlenir.
     */
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "SMS received in SMSReciver. Action: ${intent.action}")

        // BroadcastReceiver'ın hızlıca dönmesini sağlamak için goAsync() çağırın.
        // Bu, sistemin bu receiver'ın arka planda iş yapmaya devam ettiğini bilmesini sağlar.
        val pendingResult: PendingResult = goAsync()

        // Sadece SMS_RECEIVED_ACTION eylemini işle
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            // Arka plan iş parçacığında çalışacak CoroutineScope
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    intent.extras?.let {
                        val pdus = it.get("pdus") as Array<*>
                        val msgs = arrayOfNulls<SmsMessage>(pdus.size)
                        val strBuilder = StringBuilder()

                        for (i in msgs.indices) {
                            msgs[i] = SmsMessage.createFromPdu(pdus[i] as ByteArray)
                            strBuilder.append(msgs[i]?.messageBody)
                        }

                        val msgText = strBuilder.toString()
                        val msgFrom = msgs[0]?.originatingAddress

                        if (!msgFrom.isNullOrBlank() && !msgText.isNullOrBlank()) {
                            Log.d(TAG, "Processing SMS: from=$msgFrom, message=$msgText")

                            try {
                                val classificationCategories = bertClassifier(msgText, context)

                                if (classificationCategories != null && classificationCategories.isNotEmpty()) {
                                    Log.d(TAG, "Classification result: $classificationCategories")

                                    // Parse classification results by finding specific labels
                                    val hamCategory = classificationCategories.find { 
                                        (it["label"] as? String)?.trim() == "DEĞIL" 
                                    }
                                    val spamCategory = classificationCategories.find { 
                                        (it["label"] as? String)?.trim() == "BAHIS" 
                                    }
                                    
                                    val hamScore = hamCategory?.let { category ->
                                        val scoreValue = category["score"]
                                        when (scoreValue) {
                                            is Double -> scoreValue
                                            is Float -> scoreValue.toDouble()
                                            is Number -> scoreValue.toDouble()
                                            else -> 0.0
                                        }
                                    } ?: 0.0
                                    
                                    val spamScore = spamCategory?.let { category ->
                                        val scoreValue = category["score"]
                                        when (scoreValue) {
                                            is Double -> scoreValue
                                            is Float -> scoreValue.toDouble()
                                            is Number -> scoreValue.toDouble()
                                            else -> 0.0
                                        }
                                    } ?: 0.0

                                    Log.d(TAG, "Spam score: $spamScore, Ham score: $hamScore")

                                    if (spamScore > hamScore && spamScore > 0.5) {
                                        Log.i(TAG, "Spam message detected with score: $spamScore")
                                        val db = DBHelper(context)
                                        db.insertData(msgText, msgFrom)
                                        
                                        // Flutter'a spam mesajını gönder (ses çalmadan)
                                        withContext(Dispatchers.Main) {
                                            eventSink?.success(messageToMap(msgFrom, msgText))
                                        }
                                    } else {
                                        Log.d(TAG, "Normal message detected (Spam score: $spamScore, Ham score: $hamScore)")
                                        val contactName = getContactName(context, msgFrom)
                                        val displayName = if (contactName.isNotEmpty()) contactName else msgFrom
                                        val notificationKey = "$msgFrom:${msgText.hashCode()}"

                                        // Normal mesajlar için bildirim sesi çal ve Flutter'a gönder
                                        withContext(Dispatchers.Main) {
                                            playNotificationSound(context)
                                            eventSink?.success(messageToMap(msgFrom, msgText))
                                        }

                                        if (shouldShowNotification(notificationKey)) {
                                            // Bildirimi gösterme UI ile ilgili olduğundan Main thread'e geçiş
                                            withContext(Dispatchers.Main) {
                                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                                    createNotificationChannel(context)
                                                }
                                                showNotification(context, displayName, msgText)
                                            }
                                        } else {
                                            Log.d(TAG, "Skipping duplicate notification for: $displayName - $msgText")
                                        }
                                        saveInbox(context, msgFrom, msgText)
                                    }
                                } else {
                                    Log.w(TAG, "BERT classification returned null or empty result. Treating as normal message.")
                                    val contactName = getContactName(context, msgFrom)
                                    val displayName = if (contactName.isNotEmpty()) contactName else msgFrom
                                    val notificationKey = "$msgFrom:${msgText.hashCode()}"
                                    
                                    // BERT başarısız olduğunda normal mesaj olarak işle (ses çal)
                                    withContext(Dispatchers.Main) {
                                        playNotificationSound(context)
                                        eventSink?.success(messageToMap(msgFrom, msgText))
                                    }
                                    
                                    if (shouldShowNotification(notificationKey)) {
                                        withContext(Dispatchers.Main) {
                                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                                createNotificationChannel(context)
                                            }
                                            showNotification(context, displayName, msgText)
                                        }
                                    }
                                    saveInbox(context, msgFrom, msgText)
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "Error during BERT classification or processing message: ${e.message}", e)
                                val contactName = getContactName(context, msgFrom)
                                val displayName = if (contactName.isNotEmpty()) contactName else msgFrom
                                val notificationKey = "$msgFrom:${msgText.hashCode()}"
                                
                                // Hata durumunda normal mesaj olarak işle (ses çal)
                                withContext(Dispatchers.Main) {
                                    playNotificationSound(context)
                                    eventSink?.success(messageToMap(msgFrom, msgText))
                                }
                                
                                if (shouldShowNotification(notificationKey)) {
                                    withContext(Dispatchers.Main) {
                                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                            createNotificationChannel(context)
                                        }
                                        showNotification(context, displayName, msgText)
                                    }
                                }
                                saveInbox(context, msgFrom, msgText)
                            }
                        } else {
                            Log.w(TAG, "Received SMS with empty sender or message body. Skipping.")
                        }
                    } ?: Log.w(TAG, "Intent extras were null, cannot process SMS.")
                } catch (e: Exception) {
                    Log.e(TAG, "Error parsing SMS PDUs or message content: ${e.message}", e)
                } finally {
                    // İş bittiğinde pendingResult.finish() çağırılmalı!
                    pendingResult.finish()
                    Log.d(TAG, "SMS processing finished for pendingResult.")
                }
            }
        } else {
            // Eğer intent.action SMS_RECEIVED_ACTION değilse, yine de finish() çağırın
            pendingResult.finish()
            Log.d(TAG, "Ignoring non-SMS_RECEIVED_ACTION intent. Finishing pendingResult.")
        }
    }

    /**
     * Flutter'a gönderilecek mesaj formatını HashMap olarak hazırlar.
     */
    private fun messageToMap(address: String, body: String): Map<String, Any?> {
        return mapOf(
            "body" to body,
            "address" to address,
            "date" to System.currentTimeMillis(),
            "thread_id" to "0",
            "read" to "0",
            "kind" to "inbox"
        )
    }

    /**
     * Bildirim kanallarını oluşturur (Android 8.0 Oreo ve sonrası için gereklidir).
     */
    @RequiresApi(Build.VERSION_CODES.O)
    private fun createNotificationChannel(context: Context) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (notificationManager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) == null) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "SMS Bildirimleri",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "SMS mesaj bildirimleri"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableVibration(true)
                enableLights(true)
                val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build()
                setSound(soundUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created: $NOTIFICATION_CHANNEL_ID")
        }

        if (notificationManager.getNotificationChannel(NOTIFICATION_CHANNEL_HIGH_ID) == null) {
            val highChannel = NotificationChannel(
                NOTIFICATION_CHANNEL_HIGH_ID,
                "Acil SMS Bildirimleri",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Önemli SMS mesaj bildirimleri"
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500)
                enableLights(true)
                val alarmSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()
                setSound(alarmSoundUri, audioAttributes)
            }
            notificationManager.createNotificationChannel(highChannel)
            Log.d(TAG, "High priority notification channel created: $NOTIFICATION_CHANNEL_HIGH_ID")
        }
    }

    /**
     * Kullanıcıya bir bildirim gösterir.
     */
    private fun showNotification(context: Context, title: String, message: String) {
        Log.d(TAG, "Preparing to show notification: $title - $message")

        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingIntentFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        val pendingIntent = PendingIntent.getActivity(context, 0, intent, pendingIntentFlag)

        val notificationId = title.hashCode()
        val channelId = if (message.length < 30) {
            NOTIFICATION_CHANNEL_ID
        } else {
            NOTIFICATION_CHANNEL_HIGH_ID
        }

        val soundUri = if (channelId == NOTIFICATION_CHANNEL_HIGH_ID) {
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        } else {
            RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        }

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentTitle(title)
            .setContentText(message)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_MESSAGE)
            .setSound(soundUri)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        try {
            val notificationManager = NotificationManagerCompat.from(context)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (ActivityCompat.checkSelfPermission(
                        context,
                        android.Manifest.permission.POST_NOTIFICATIONS
                    ) == PackageManager.PERMISSION_GRANTED
                ) {
                    notificationManager.notify(notificationId, builder.build())
                    Log.d(TAG, "Notification posted with ID: $notificationId (Android 13+).")
                } else {
                    Log.w(TAG, "POST_NOTIFICATIONS permission not granted. Cannot show notification directly.")
                }
            } else {
                notificationManager.notify(notificationId, builder.build())
                Log.d(TAG, "Notification posted with ID: $notificationId (Pre-Android 13).")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show notification: ${e.message}", e)
        }
    }

    /**
     * Gelen SMS'i Android'in varsayılan SMS gelen kutusuna kaydeder.
     */
    fun saveInbox(context: Context, number: String, message: String): Uri? {
        Log.d(TAG, "Attempting to save SMS to inbox: from=$number, message=$message")

        val cursor = context.contentResolver.query(
            Uri.parse("content://sms/inbox"),
            arrayOf(Telephony.Sms._ID),
            "${Telephony.Sms.ADDRESS} = ? AND ${Telephony.Sms.BODY} = ? AND ${Telephony.Sms.DATE} > ?",
            arrayOf(number, message, (System.currentTimeMillis() - NOTIFICATION_DEBOUNCE_TIME).toString()), // Son 5 saniyede aynı mesajı kontrol et
            null
        )

        val alreadyExists = (cursor != null && cursor.count > 0)
        cursor?.close()

        if (alreadyExists) {
            Log.d(TAG, "SMS already exists in inbox (likely duplicated by system), skipping insertion.")
            return null
        }

        val smsValues = ContentValues().apply {
            put(Telephony.Sms.ADDRESS, number)
            put(Telephony.Sms.BODY, message)
            put(Telephony.Sms.DATE, System.currentTimeMillis())
            put(Telephony.Sms.READ, 0)
            put(Telephony.Sms.SEEN, 0)
            put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_INBOX)
        }

        var uri: Uri? = null
        try {
            uri = context.contentResolver.insert(Uri.parse("content://sms/inbox"), smsValues)
            Log.i(TAG, "SMS saved to inbox successfully: $uri")
            return uri
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save SMS to inbox: ${e.message}", e)
            return null
        }
    }

    /**
     * Verilen telefon numarasına ait kişi adını rehberden alır.
     */
    @SuppressLint("Range")
    fun getContactName(context: Context, number: String): String {
        val uri = Uri.withAppendedPath(
            ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(
                number
            )
        )
        val projection = arrayOf(ContactsContract.PhoneLookup.DISPLAY_NAME)
        var contactName = ""
        var cursor: Cursor? = null

        try {
            cursor = context.contentResolver.query(uri, projection, null, null, null)
            if (cursor != null && cursor.moveToFirst()) {
                contactName = cursor.getString(cursor.getColumnIndex(ContactsContract.PhoneLookup.DISPLAY_NAME))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error getting contact name for number $number: ${e.message}", e)
        } finally {
            cursor?.close()
        }
        return contactName
    }

    /**
     * SmsMessage nesnesini bir HashMap'e dönüştürür.
     */
    fun SmsMessage.toMap(): HashMap<String, Any?> {
        val smsMap = HashMap<String, Any?>()
        this.apply {
            smsMap["message_body"] = messageBody
            smsMap["timestamp"] = timestampMillis.toString()
            smsMap["originating_address"] = originatingAddress
            smsMap["status"] = status.toString()
            smsMap["service_center"] = serviceCenterAddress
        }
        return smsMap
    }

    /**
     * BERT modelini kullanarak bir mesajı sınıflandırır.
     */
    fun bertClassifier(message: String, context: Context): MutableList<Map<String, Any>>? {
        var classifier: TextClassifier? = null
        try {
            val modelAssetPath = "aaa.tflite"

            val baseOptions = BaseOptions.builder()
                .setModelAssetPath(modelAssetPath)
                .setDelegate(Delegate.CPU)
                .build()

            val options = TextClassifier.TextClassifierOptions.builder()
                .setBaseOptions(baseOptions)
                .build()

            classifier = TextClassifier.createFromOptions(context, options)
            val result = classifier.classify(message)

            val categories = mutableListOf<Map<String, Any>>()
            val classificationResult = result.classificationResult()
            if (classificationResult != null && classificationResult.classifications().isNotEmpty()) {
                val firstClassification = classificationResult.classifications()[0]
                firstClassification.categories().forEach { category ->
                    categories.add(
                        mapOf(
                            "label" to category.categoryName(),
                            "score" to category.score()
                        )
                    )
                }
            }

            Log.d(TAG, "BERT classification successful for message: '$message'. Result: $categories")
            Log.d(TAG, "Classification categories: $categories")
            return categories
        } catch (e: Exception) {
            Log.e(TAG, "Error in BERT text classification for message: '$message'. Error: ${e.message}", e)
            return null
        } finally {
            classifier?.close()
        }
    }
}
