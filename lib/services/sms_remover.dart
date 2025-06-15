// ignore_for_file: unintended_html_in_doc_comment

import 'dart:developer' as dev;
import 'package:flutter/services.dart';

class SmsRemover {
  final MethodChannel _channel = const MethodChannel('com.dovahkin.sms_guard');

  /// Removes an SMS message by its ID and thread ID
  /// 
  /// Returns a Future<String> with the result message from the native code
  Future<String> removeSmsById(String id, String threadId) async {
    try {
      dev.log("SMS silme işlemi başlatılıyor - id: $id, threadId: $threadId", name: "SmsRemover");
      
      final result = await _channel.invokeMethod('removeSms', {
        'id': id,
        'threadId': threadId,
      });
      
      dev.log("SMS silme sonucu: $result", name: "SmsRemover");
      return result.toString();
    } catch (e) {
      dev.log("SMS silme hatası: $e", name: "SmsRemover", error: e);
      return "SMS silme işlemi başarısız oldu: $e";
    }
  }
}