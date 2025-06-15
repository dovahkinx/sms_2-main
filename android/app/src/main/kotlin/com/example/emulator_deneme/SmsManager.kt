package com.dovahkin.sms_guard

import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Telephony
import android.util.Log

/**
 * Bu sınıf SMS gönderme ve yönetme işlemlerini native olarak gerçekleştirir.
 * Flutter tarafından Method Channel üzerinden çağrılır.
 */
class SmsManager {
    companion object {
        private const val TAG = "SmsManager"
        
        /**
         * SMS gönderir ve sonucu döndürür.
         * @param context Uygulama context'i
         * @param phoneNumber SMS gönderilecek telefon numarası
         * @param message Gönderilecek mesaj içeriği
         * @return Gönderim sonucunu içeren Map
         */
        fun sendSms(context: Context, phoneNumber: String, message: String): Map<String, Any> {
            val resultMap = mutableMapOf<String, Any>()
            
            try {
                // İzin kontrolü
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                    context.checkSelfPermission(android.Manifest.permission.SEND_SMS) != PackageManager.PERMISSION_GRANTED) {
                    Log.e(TAG, "SMS permission not granted")
                    resultMap["success"] = false
                    resultMap["message"] = "SMS izni verilmedi"
                    return resultMap
                }
                
                // Android versiyonuna göre SmsManager alınması
                val androidSmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    context.getSystemService(android.telephony.SmsManager::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    android.telephony.SmsManager.getDefault()
                }
                
                // Uzun mesajları parçalama ve gönderme
                if (message.length > 160) {
                    val messageParts = androidSmsManager.divideMessage(message)
                    androidSmsManager.sendMultipartTextMessage(
                        phoneNumber,
                        null,
                        messageParts,
                        null,
                        null
                    )
                } else {
                    // Kısa mesajları doğrudan gönderme
                    androidSmsManager.sendTextMessage(phoneNumber, null, message, null, null)
                }
                
                // Gönderilen mesajı cihaz SMS veritabanına kaydetme
                saveToSentBox(context, phoneNumber, message)
                
                Log.i(TAG, "SMS sent successfully to $phoneNumber")
                resultMap["success"] = true
                resultMap["message"] = "SMS başarıyla gönderildi"
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send SMS: ${e.message}")
                e.printStackTrace()
                resultMap["success"] = false
                resultMap["message"] = "SMS gönderme hatası: ${e.message}"
            }
            
            return resultMap
        }
        
        /**
         * Gönderilen mesajı cihaz SMS veritabanına kaydeder
         */
        fun saveToSentBox(context: Context, address: String?, message: String?) {
            try {
                val smsValues = ContentValues().apply {
                    put(Telephony.Sms.ADDRESS, address)
                    put(Telephony.Sms.BODY, message)
                    put(Telephony.Sms.DATE, System.currentTimeMillis())
                    put(Telephony.Sms.READ, 1)
                    put(Telephony.Sms.TYPE, Telephony.Sms.MESSAGE_TYPE_SENT)
                }
                
                context.contentResolver.insert(Uri.parse("content://sms/sent"), smsValues)
                Log.i(TAG, "SMS saved to sent box")
            } catch (e: Exception) {
                Log.e(TAG, "Error saving SMS to sent box: ${e.message}")
                e.printStackTrace()
            }
        }
        
        /**
         * SMS'i siler (gelen veya gönderilmiş)
         */
        fun deleteSms(context: Context, id: String?, threadId: String?): Int {
            if (id == null || threadId == null) {
                Log.e(TAG, "Cannot delete SMS: id or threadId is null")
                return 0
            }
            
            // İzin kontrolü
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (context.checkSelfPermission(android.Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED ) {
                    Log.e(TAG, "SMS read/write permissions not granted")
                    return 0
                }
            }
            
            // Default SMS App kontrolü
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                val defaultSmsPackage = Telephony.Sms.getDefaultSmsPackage(context)
                if (defaultSmsPackage != context.packageName) {
                    Log.w(TAG, "App is not default SMS app. Current default: $defaultSmsPackage")
                    // Android 4.4+ sürümlerde varsayılan SMS uygulaması olmak gerekiyor
                    // Ancak yine de silmeyi deneyelim
                }
            }
            
            var totalDeletedRows = 0
            
            try {
                // Detaylı log ekleyelim
                Log.d(TAG, "Attempting to delete SMS with id=$id, threadId=$threadId")
                
                // 1. Önce ID ve threadId kombinasyonu ile silme deneyelim
                val generalUri = Uri.parse("content://sms")
                var selection = "${Telephony.Sms._ID} = ? AND ${Telephony.Sms.THREAD_ID} = ?"
                var selectionArgs = arrayOf(id, threadId)
                
                var deletedRows = context.contentResolver.delete(generalUri, selection, selectionArgs)
                totalDeletedRows += deletedRows
                Log.d(TAG, "1. Deleted $deletedRows rows from general SMS URI with ID+threadId")
                
                // 2. Sadece ID ile tekrar deneyelim
                if (deletedRows == 0) {
                    selection = "${Telephony.Sms._ID} = ?"
                    selectionArgs = arrayOf(id)
                    deletedRows = context.contentResolver.delete(generalUri, selection, selectionArgs)
                    totalDeletedRows += deletedRows
                    Log.d(TAG, "2. Deleted $deletedRows rows from general SMS URI with only ID")
                }
                
                // 3. Gönderilmiş mesajlar için URI ile deneyelim
                val sentUri = Uri.parse("content://sms/sent")
                selection = "${Telephony.Sms._ID} = ?"
                selectionArgs = arrayOf(id)
                deletedRows = context.contentResolver.delete(sentUri, selection, selectionArgs)
                totalDeletedRows += deletedRows
                Log.d(TAG, "3. Deleted $deletedRows rows from sent SMS URI")
                
                // 4. Taslaklar için URI ile deneyelim
                val draftUri = Uri.parse("content://sms/draft")
                deletedRows = context.contentResolver.delete(draftUri, selection, selectionArgs)
                totalDeletedRows += deletedRows
                Log.d(TAG, "4. Deleted $deletedRows rows from draft SMS URI")
                
                // 5. Inbox için URI ile deneyelim
                val inboxUri = Uri.parse("content://sms/inbox")
                deletedRows = context.contentResolver.delete(inboxUri, selection, selectionArgs)
                totalDeletedRows += deletedRows
                Log.d(TAG, "5. Deleted $deletedRows rows from inbox SMS URI")
                
                // 6. Son çare: Sadece thread ID ile silme
                if (totalDeletedRows == 0) {
                    selection = "${Telephony.Sms.THREAD_ID} = ?"
                    selectionArgs = arrayOf(threadId)
                    
                    // Genel URI'den
                    deletedRows = context.contentResolver.delete(generalUri, selection, selectionArgs)
                    totalDeletedRows += deletedRows
                    Log.d(TAG, "6. Deleted $deletedRows rows by threadId from general URI")
                    
                    // Sent URI'den 
                    deletedRows = context.contentResolver.delete(sentUri, selection, selectionArgs)
                    totalDeletedRows += deletedRows
                    Log.d(TAG, "7. Deleted $deletedRows rows by threadId from sent URI")
                    
                    // Inbox URI'den
                    deletedRows = context.contentResolver.delete(inboxUri, selection, selectionArgs)
                    totalDeletedRows += deletedRows
                    Log.d(TAG, "8. Deleted $deletedRows rows by threadId from inbox URI")
                }
                
                // 7. Hiçbir satır silinemediyse, bir de yalnızca thread ID ile deneyelim
                if (totalDeletedRows == 0) {
                    try {
                        // threadId ile ilgili tüm mesajları silmeye çalış
                        val threadDeleteUri = Uri.parse("content://sms/conversations/$threadId")
                        deletedRows = context.contentResolver.delete(threadDeleteUri, null, null)
                        totalDeletedRows += deletedRows
                        Log.d(TAG, "9. Deleted $deletedRows rows using conversation URI")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error deleting by conversation URI: ${e.message}")
                    }
                }
                
                // 8. Content provider'a değişiklik bildir
                if (totalDeletedRows > 0) {
                    try {
                        context.contentResolver.notifyChange(Uri.parse("content://sms"), null)
                        context.contentResolver.notifyChange(Uri.parse("content://sms/conversations"), null)
                        context.contentResolver.notifyChange(Uri.parse("content://sms/sent"), null)
                        context.contentResolver.notifyChange(Uri.parse("content://sms/inbox"), null)
                        Log.d(TAG, "Notified content provider of changes")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error notifying content provider: ${e.message}")
                    }
                }
                
                Log.i(TAG, "Total deleted rows: $totalDeletedRows")
                return totalDeletedRows
            } catch (e: Exception) {
                Log.e(TAG, "Error deleting SMS: ${e.message}")
                e.printStackTrace()
                return totalDeletedRows
            }
        }
        
        /**
         * SMS mesajlarını okundu olarak işaretler
         * @param context Uygulama context'i
         * @param threadId Okundu olarak işaretlenecek mesaj konusunun thread ID'si
         * @return Güncellenen mesaj sayısı
         */
        fun markThreadAsRead(context: Context, threadId: String?): Int {
            if (threadId == null) {
                Log.e(TAG, "Cannot mark thread as read: threadId is null")
                return 0
            }
            
            // İzin kontrolü
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (context.checkSelfPermission(android.Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
                    Log.e(TAG, "SMS read/write permissions not granted")
                    return 0
                }
            }
            
            var updatedRows = 0
            
            try {
                // SMS içeriğini güncelleyecek değerler
                val values = ContentValues().apply {
                    put(Telephony.Sms.READ, 1) // 1 = okundu
                }
                
                // Önce inbox (gelen kutusu) URI'sinde threadId ile eşleşen ve okunmamış olan mesajları güncelle
                val inboxUri = Uri.parse("content://sms/inbox")
                val selection = "${Telephony.Sms.THREAD_ID} = ? AND ${Telephony.Sms.READ} = 0"
                val selectionArgs = arrayOf(threadId)
                
                updatedRows = context.contentResolver.update(inboxUri, values, selection, selectionArgs)
                Log.i(TAG, "Marked $updatedRows messages as read in thread $threadId")
                
                // Content provider'a değişiklik bildir
                if (updatedRows > 0) {
                    context.contentResolver.notifyChange(Uri.parse("content://sms"), null)
                    context.contentResolver.notifyChange(Uri.parse("content://sms/inbox"), null)
                    context.contentResolver.notifyChange(Uri.parse("content://sms/conversations"), null)
                }
                
                return updatedRows
            } catch (e: Exception) {
                Log.e(TAG, "Error marking messages as read: ${e.message}")
                e.printStackTrace()
                return updatedRows
            }
        }
        
        /**
         * Belirli bir SMS thread'inin (konuşma) okunma durumunu kontrol eder
         * @param context Uygulama context'i
         * @param threadId Kontrol edilecek konuşmanın thread ID'si
         * @return Thread'in okunma durumu - true: okunmuş, false: okunmamış
         */
        fun isThreadRead(context: Context, threadId: String?): Boolean {
            if (threadId == null) {
                Log.e(TAG, "Cannot check thread read status: threadId is null")
                return true // Varsayılan olarak okunmuş kabul et
            }
            
            // İzin kontrolü
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (context.checkSelfPermission(android.Manifest.permission.READ_SMS) != PackageManager.PERMISSION_GRANTED) {
                    Log.e(TAG, "SMS read permission not granted")
                    return true // İzin yoksa varsayılan olarak okunmuş kabul et
                }
            }
            
            try {
                // Inbox URI'den threadId ile eşleşen ve okunmamış olan mesajları sor
                val inboxUri = Uri.parse("content://sms/inbox")
                val projection = arrayOf(Telephony.Sms._ID)
                val selection = "${Telephony.Sms.THREAD_ID} = ? AND ${Telephony.Sms.READ} = 0"
                val selectionArgs = arrayOf(threadId)
                
                context.contentResolver.query(
                    inboxUri, 
                    projection, 
                    selection, 
                    selectionArgs, 
                    null
                )?.use { cursor ->
                    // Eğer cursor boş değilse ve en az bir satır varsa, thread okunmamış demektir
                    val hasUnreadMessages = cursor.count > 0
                    Log.d(TAG, "Thread $threadId read status check: ${if (!hasUnreadMessages) "read" else "unread"}, unread count: ${cursor.count}")
                    return !hasUnreadMessages // true = okunmuş (yani okunmamış mesaj yok)
                } ?: run {
                    Log.e(TAG, "Failed to query SMS database for thread $threadId")
                    return true // Sorgulama başarısız olursa varsayılan olarak okunmuş kabul et
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error checking thread read status: ${e.message}")
                e.printStackTrace()
                return true // Hata durumunda varsayılan olarak okunmuş kabul et
            }
        }
    }
}