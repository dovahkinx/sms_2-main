import 'package:flutter/services.dart';
import 'dart:developer';
import 'package:url_launcher/url_launcher.dart';

/// SMS gönderme ve yönetme işlemleri için servis sınıfı.
/// Bu sınıf, native Kotlin kodu ile iletişim kurarak SMS işlemlerini gerçekleştirir.
class SmsService {
  static const MethodChannel _channel = MethodChannel('com.dovahkin.sms_guard');
  
  /// Singleton yapı
  SmsService._privateConstructor();
  static final SmsService instance = SmsService._privateConstructor();
  
  /// SMS gönderir ve sonucu döndürür.
  /// 
  /// [phoneNumber]: SMS gönderilecek telefon numarası
  /// [message]: Gönderilecek mesaj içeriği
  /// [formatNumber]: Telefon numarasını otomatik formatla
  Future<String> sendSms({
    required String phoneNumber, 
    required String message,
    bool formatNumber = true
  }) async {
    try {
      // Telefon numarasını formatlama (opsiyonel)
      String formattedNumber = phoneNumber;
      if (formatNumber) {
        formattedNumber = _formatPhoneNumber(phoneNumber);
      }
      
      log('SMS gönderiliyor: $formattedNumber -> $message');
      
      try {
        // İlk olarak native kodu çağır
        final result = await _channel.invokeMethod('sendSms', {
          'address': formattedNumber,
          'body': message,
        });
        
        log('SMS gönderme sonucu: $result');
        return result.toString();
      } on PlatformException catch (e) {
        // Native kod hata verirse alternatif yöntemi dene
        log('Native SMS gönderme hatası: ${e.message}, alternatif yöntem deneniyor...');
        
        // Mesajı SMS URI şemasıyla gönder
        final success = await _sendSmsViaUri(formattedNumber, message);
        if (success) {
          // Başarılı ise Sent mesajlar klasörüne kaydetmeyi dene
          try {
            await _channel.invokeMethod('check', {
              'address': formattedNumber,
              'body': message,
            });
          } catch (e) {
            log('Gönderilen mesajı kaydetme hatası: $e');
            // Bu hatayı yok sayabiliriz çünkü mesaj yine de gönderilmiş olacak
          }
          return "Mesaj başarıyla gönderildi.";
        } else {
          return 'SMS gönderme hatası: SMS uygulaması açılamadı';
        }
      }
    } catch (e) {
      log('Beklenmeyen hata: $e');
      return 'Beklenmeyen hata: $e';
    }
  }
  
  /// SMS URI şeması kullanarak varsayılan SMS uygulamasını açar
  Future<bool> _sendSmsViaUri(String phoneNumber, String message) async {
    // SMS URI şeması
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': message},
    );
    
    log('SMS URI açılıyor: $smsUri');
    
    try {
      // URI'yi aç ve sonucu döndür
      return await launchUrl(smsUri);
    } catch (e) {
      log('SMS URI açılırken hata: $e');
      return false;
    }
  }
  
  /// SMS kaydet (gönderilmiş gibi)
  Future<String> saveSmsToSent({
    required String phoneNumber,
    required String message,
    bool formatNumber = true
  }) async {
    try {
      String formattedNumber = phoneNumber;
      if (formatNumber) {
        formattedNumber = _formatPhoneNumber(phoneNumber);
      }
      
      final result = await _channel.invokeMethod('check', {
        'address': formattedNumber,
        'body': message,
      });
      
      return result.toString();
    } catch (e) {
      log('SMS kaydetme hatası: $e');
      return 'SMS kaydetme hatası: $e';
    }
  }
  
  /// SMS silme
  Future<String> deleteSms(String id, String threadId) async {
    try {
      final result = await _channel.invokeMethod('removeSms', {
        'id': id,
        'threadId': threadId,
      });
      
      return result.toString();
    } catch (e) {
      log('SMS silme hatası: $e');
      return 'SMS silme hatası: $e';
    }
  }
  
  /// Bir konuşmadaki tüm okunmamış mesajları okundu olarak işaretler
  /// 
  /// [threadId]: Okundu olarak işaretlenecek konuşmanın thread ID'si
  /// Returns: İşaretlenen mesaj sayısı veya hata mesajı
  Future<String> markThreadAsRead(String threadId) async {
    try {
      log('Mesajlar okundu olarak işaretleniyor: threadId=$threadId');
      
      final result = await _channel.invokeMethod('markThreadAsRead', {
        'threadId': threadId,
      });
      
      log('Okundu işaretleme sonucu: $result');
      return result.toString();
    } catch (e) {
      log('Mesajları okundu olarak işaretleme hatası: $e');
      return 'Okundu işaretleme hatası: $e';
    }
  }
  
  /// Bir konuşmanın okunma durumunu Kotlin tarafında kontrol eder
  /// 
  /// [threadId]: Kontrol edilecek konuşmanın thread ID'si
  /// Returns: true: okunmuş, false: okunmamış
  Future<bool> isThreadRead(String threadId) async {
    try {
      log('Thread okunma durumu sorgulanıyor: threadId=$threadId');
      
      final result = await _channel.invokeMethod('isThreadRead', {
        'threadId': threadId,
      });
      
      log('Thread okunma durumu: ${result ? "okundu" : "okunmadı"}');
      return result ?? true; // Eğer null gelirse varsayılan olarak okunmuş kabul et
    } catch (e) {
      log('Thread okunma durumu sorgulama hatası: $e');
      return true; // Hata durumunda varsayılan olarak okunmuş kabul et
    }
  }
  
  /// Telefon numarasını Türkiye formatına çevirir
  String _formatPhoneNumber(String phoneNumber) {
    // Boşlukları ve özel karakterleri temizle
    String number = phoneNumber
        .trim()
        .replaceAll(" ", "")
        .replaceAll("-", "")
        .replaceAll("(", "")
        .replaceAll(")", "");
    
    // Türkiye telefon formatlaması
    if (number.startsWith("0")) {
      number = number.replaceFirst("0", "+90");
    }
    else if (number.startsWith("90")) {
      number = number.replaceFirst("90", "+90");
    }
    else if (number.startsWith("5")) {
      number = "+90$number";
    }
    
    return number;
  }
}