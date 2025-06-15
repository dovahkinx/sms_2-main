package com.dovahkin.sms_guard

import android.annotation.SuppressLint
import android.app.*
import android.app.role.RoleManager
import android.content.*
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import android.util.Log
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.google.mediapipe.tasks.core.BaseOptions



class MainActivity: FlutterActivity() {

    private val CHANNEL = "com.dovahkin.sms_guard"
    private val SMS_EVENT_CHANNEL = "com.dovahkin.sms_guard/sms"
    // Track the SMS receiver instance
    private var smsReceiver: SMSReciver? = null

    @SuppressLint("SuspiciousIndentation")
    @RequiresApi(Build.VERSION_CODES.Q)
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "bert" -> {
                    showDefaultSmsDialog(this)
                    result.success("Success")
                }
                "check" -> {
                    val data = call.arguments as? Map<String, Any>
                    val address = data?.get("address") as? String
                    val message = data?.get("body") as? String
                    SmsManager.saveToSentBox(this, address, message)
                    result.success("mesaj kutusuna kaydeddildi")
                }
                "sendSms" -> {
                    try {
                        val data = call.arguments as? Map<String, Any>
                        val address = data?.get("address") as? String
                        val message = data?.get("body") as? String
                        
                        if (address != null && message != null) {
                            // Yeni SmsManager sınıfımızı kullan
                            val smsResult = SmsManager.sendSms(this, address, message)
                            if (smsResult["success"] as Boolean) {
                                result.success(smsResult["message"])
                            } else {
                                result.error("SEND_FAILED", smsResult["message"] as String, null)
                            }
                        } else {
                            result.error("INVALID_ARGUMENTS", "Geçersiz adres veya mesaj", null)
                        }
                    } catch (e: Exception) {
                        result.error("EXCEPTION", "SMS gönderme hatası: ${e.message}", null)
                    }
                }
                "removeSms" -> {
                    try {
                        val data = call.arguments as? Map<String, Any>
                        val id = data?.get("id") as? String
                        val threadId = data?.get("threadId") as? String
                        
                        Log.d("SMS_GUARD", "Flutter'dan silme talebi alındı: id=$id, threadId=$threadId")
                        
                        if (id == null || threadId == null) {
                            Log.e("SMS_GUARD", "Null id veya threadId: id=$id, threadId=$threadId")
                            result.error("INVALID_ARGS", "ID veya threadId geçersiz", null)
                            return@setMethodCallHandler
                        }
                        
                        Log.d("SMS_GUARD", "SmsManager.deleteSms çağrılıyor: id=$id, threadId=$threadId")
                        val deleted = SmsManager.deleteSms(this, id, threadId)
                        
                        if (deleted > 0) {
                            Log.d("SMS_GUARD", "Mesaj başarıyla silindi, silinen satır sayısı: $deleted");
                            result.success("Mesaj başarıyla silindi ($deleted adet)")
                        } else {
                            Log.w("SMS_GUARD", "Mesaj silinemedi (0 satır)")
                            result.success("Mesaj silinemedi, lütfen tekrar deneyin.")
                        }
                    } catch (e: Exception) {
                        Log.e("SMS_GUARD", "SMS silme hatası: ${e.message}", e)
                        result.error("EXCEPTION", "SMS silme hatası: ${e.message}", e.toString())
                    }
                }
                "markThreadAsRead" -> {
                    try {
                        val data = call.arguments as? Map<String, Any>
                        val threadId = data?.get("threadId") as? String
                        
                        Log.d("SMS_GUARD", "Flutter'dan okundu talebi alındı: threadId=$threadId")
                        
                        if (threadId == null) {
                            Log.e("SMS_GUARD", "Null threadId: threadId=$threadId")
                            result.error("INVALID_ARGS", "threadId geçersiz", null)
                            return@setMethodCallHandler
                        }
                        
                        val updatedRows = SmsManager.markThreadAsRead(this, threadId)
                        
                        if (updatedRows > 0) {
                            Log.d("SMS_GUARD", "Mesajlar okundu olarak işaretlendi, güncellenen satır sayısı: $updatedRows")
                            result.success("$updatedRows mesaj okundu olarak işaretlendi")
                        } else {
                            Log.w("SMS_GUARD", "Hiçbir mesaj işaretlenmedi (0 satır)")
                            result.success("Güncellenecek okunmamış mesaj bulunamadı")
                        }
                    } catch (e: Exception) {
                        Log.e("SMS_GUARD", "Mesajları okundu olarak işaretleme hatası: ${e.message}", e)
                        result.error("EXCEPTION", "Okundu işaretleme hatası: ${e.message}", e.toString())
                    }
                }
                "isThreadRead" -> {
                    try {
                        val data = call.arguments as? Map<String, Any>
                        val threadId = data?.get("threadId") as? String
                        
                        Log.d("SMS_GUARD", "Flutter'dan okunma durumu sorgusu alındı: threadId=$threadId")
                        
                        if (threadId == null) {
                            Log.e("SMS_GUARD", "Null threadId: threadId=$threadId")
                            result.error("INVALID_ARGS", "threadId geçersiz", null)
                            return@setMethodCallHandler
                        }
                        
                        val isRead = SmsManager.isThreadRead(this, threadId)
                        
                        Log.d("SMS_GUARD", "Thread $threadId okunma durumu: ${if (isRead) "okundu" else "okunmadı"}")
                        result.success(isRead)
                    } catch (e: Exception) {
                        Log.e("SMS_GUARD", "Okunma durumu sorgulama hatası: ${e.message}", e)
                        result.error("EXCEPTION", "Okunma durumu sorgulama hatası: ${e.message}", e.toString())
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        val eventchannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_EVENT_CHANNEL)
        eventchannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                try {
                    val filter = IntentFilter("android.provider.Telephony.SMS_RECEIVED")
                    // Create and store the receiver instance
                    smsReceiver = SMSReciver(events)
                    registerReceiver(smsReceiver, filter)
                    println("SMS Listener registered successfully")
                } catch (e: Exception) {
                    println("Error registering SMS receiver: ${e.message}")
                    e.printStackTrace()
                }
            }

            override fun onCancel(arguments: Any?) {
                try {
                    // Only unregister if we have a valid receiver
                    if (smsReceiver != null) {
                  unregisterReceiver(smsReceiver)
                              smsReceiver = null
                        println("SMS Listener unregistered successfully")
                    } else {
                        println("No SMS Listener to unregister")
                    }
                } catch (e: IllegalArgumentException) {
                    println("Error unregistering receiver: ${e.message}")
                    e.printStackTrace()
                } catch (e: Exception) {
                    println("Unknown error in onCancel: ${e.message}")
                    e.printStackTrace()
                }
            }
        })
    }
    
    fun showDefaultSmsDialog(context: Activity) {
        if (intent.getBooleanExtra(Telephony.Sms.Intents.EXTRA_IS_DEFAULT_SMS_APP, false)) {
            println("Default SMS app")
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val roleManager = context.getSystemService(RoleManager::class.java) as RoleManager
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_SMS)
                context.startActivityForResult(intent, 42389)
            } else {
                val intent = Intent(Telephony.Sms.Intents.ACTION_CHANGE_DEFAULT)
                intent.putExtra(Telephony.Sms.Intents.EXTRA_PACKAGE_NAME, context.packageName)
                context.startActivity(intent)
            }
        }
    }
}






