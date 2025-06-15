import 'dart:async';

import 'package:another_telephony/telephony.dart' show Telephony;
import 'package:equatable/equatable.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show Cubit;
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart' show SmsMessage, SmsQuery, SmsQueryKind;

import 'package:sms_guard/model/my_message_model.dart';

import 'package:sqflite/sqflite.dart';


import '../../model/search_sms_model.dart';
import '../../model/spam_model.dart';

part 'sms_state.dart';

class SmsCubit extends Cubit<SmsState> {
  SmsCubit() : super(SmsState()) {
    Telephony.instance.listenIncomingSms(onNewMessage: onNewMessage, listenInBackground: false);

    onInit();
  }

  // Flags to prevent concurrent operations
  bool _gettingMessages = false;
  bool _gettingContacts = false;
  
  void onInit() async {
    emit(state.copyWith(isLoading: true));
    SmsQuery query = SmsQuery();
    var messages = await query.getAllSms;
    
    // Get contacts once at startup
    await getContactsIfNeeded();
    
    emit(state.copyWith(messages: messages));
    await getSpam();
    await getMessages();

    emit(state.copyWith(isLoading: false));
  }

  // Helper to avoid concurrent contact fetching
  Future<List<Contact>> getContactsIfNeeded() async {
    if (_gettingContacts) {
      return state.contactList;
    }

    if (state.contactList.isNotEmpty) {
      return state.contactList;
    }

    _gettingContacts = true;
    try {
      final List<Contact> contacts = await FastContacts.getAllContacts();
      emit(state.copyWith(contactList: contacts));
      return contacts;
    } catch (e) {
      print("Error getting contacts: $e");
      return [];
    } finally {
      _gettingContacts = false;
    }
  }

  void prinnt(text) {
    emit(state.copyWith(text: text));
  }

  void resultContactWithTextEditingController(text) async {
    List<Contact> result = [];
    if (text == "") {
      emit(state.copyWith(sendResult: []));
    } else {
      for (var item in state.contactList) {
        if (item.displayName.toLowerCase().contains(text.toLowerCase())) {
          if (item.phones.isNotEmpty) {
            result.add(item);
          } else {
            print("telefon yok");
          }
        }
      }
    }

    emit(state.copyWith(sendResult: result));
  }

  void onNewMessage(dynamic message) async {
    print("Yeni mesaj alındı: $message");

    try {
      emit(state.copyWith(isLoading: true));

      if (message is String) {
        print("String mesaj alındı: $message");
        // Sadece ilgili mesajı ekle
        // await _forceRefreshMessages();
        emit(state.copyWith(
            isLoading: false, timestamp: DateTime.now().millisecondsSinceEpoch));
      } else if (message is Map) {
        print("Mesaj Map formatında alındı: $message");

        String body = message['body']?.toString() ?? '';
        String address = message['address']?.toString() ?? '';
        int timestamp = (message['date'] is num)
            ? (message['date'] as num).toInt()
            : DateTime.now().millisecondsSinceEpoch;
        int? threadId = (message['thread_id'] is num)
            ? (message['thread_id'] as num).toInt()
            : null;

        DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

        final tempMessage = MyMessage(
            name: address,
            lastMessage: body,
            address: address,
            date: dateTime,
            threadId: threadId);

        List<MyMessage> updatedMessages = List.from(state.myMessages);
        bool threadExists = false;

        for (int i = 0; i < updatedMessages.length; i++) {
          if (updatedMessages[i].address == address ||
              updatedMessages[i].threadId == threadId) {
            updatedMessages[i].lastMessage = body;
            updatedMessages[i].date = dateTime;
            threadExists = true;
            break;
          }
        }

        if (!threadExists) {
          updatedMessages.add(tempMessage);
        }

        updatedMessages.sort((a, b) => b.date!.compareTo(a.date!));

        emit(state.copyWith(
            myMessages: updatedMessages,
            timestamp: DateTime.now().millisecondsSinceEpoch));

        // await _forceRefreshMessages();
      }

      emit(state.copyWith(
          isLoading: false,
          isInit: true,
          timestamp: DateTime.now().millisecondsSinceEpoch));
    } catch (e) {
      print("SMS güncelleme hatası: $e");
      emit(state.copyWith(isLoading: false));
      // _forceRefreshMessages();
    }
  }

  Future<void> _forceRefreshMessages({String? address, int? threadId}) async {
    _gettingMessages = false;
    // Sadece ilgili thread/adres için veri çek
    await Future.wait([
      getMessages(),
      getSpam(),
    ]);
    if (address != null) {
      await filterMessageForAdress(address);
    } else if (state.address != null) {
      await filterMessageForAdress(state.address!);
    }
  }

  Future<void> forceRefresh({String? address, int? threadId}) async {
    emit(state.copyWith(isLoading: true));
    _gettingMessages = false;
    await _forceRefreshMessages(address: address, threadId: threadId);
    emit(state.copyWith(
        isLoading: false,
        isInit: true,
        timestamp: DateTime.now().millisecondsSinceEpoch));
  }

  Future<void> filterMessageForAdress(String address) async {
    emit(state.copyWith(address: address));
    SmsQuery query = SmsQuery();
    try {
      print("Belirli adres için mesajlar alınıyor: $address");
      List<SmsMessage> messages = [];
      // Sadece tek bir sorgu ile threadId/address'e göre filtrele
      final normalizedAddress = cleanPhoneNumber(address);
      var phoneMessages = await query.querySms(
          address: normalizedAddress, kinds: [SmsQueryKind.inbox, SmsQueryKind.sent]);
      messages.addAll(phoneMessages);
      // Eğer kurumsal ise threadId ile sorgula
      if (messages.isEmpty) {
        var allMessages = await query.getAllSms;
        int? targetThreadId;
        for (var message in allMessages) {
          if (message.address == address) {
            targetThreadId = message.threadId;
            break;
          }
        }
        if (targetThreadId != null) {
          messages = await query.querySms(
              threadId: targetThreadId, kinds: [SmsQueryKind.inbox, SmsQueryKind.sent]);
        }
      }
      print("Toplam \\${messages.length} mesaj bulundu");
      // Mesajlar sıralı geliyorsa tekrar sort etme
      emit(state.copyWith(filtingMessages: messages.reversed.toList()));
    } catch (e) {
      print("Konuşma filtreleme hatası: $e");
      emit(state.copyWith(filtingMessages: []));
    }
  }

  Future<void> getMessages() async {
    if (_gettingMessages) {
      print("getMessages already in progress - skipping");
      return;
    }
    _gettingMessages = true;
    try {
      var fonksiyonBaslangic = DateTime.now();
      final Telephony telephony = Telephony.instance;
      final bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
      if (permissionsGranted != true) {
        print("SMS permissions not granted");
        emit(state.copyWith(myMessages: [], messages: []));
        return;
      }
      print("Fetching all SMS messages...");
      var messages = await SmsQuery().getAllSms;
      print("Found \\${messages.length} SMS messages");
      Map<int?, SmsMessage> threadMap = {};
      for (var message in messages) {
        if (message.threadId == null) continue;
        if (!threadMap.containsKey(message.threadId) ||
            (message.date != null &&
                threadMap[message.threadId]!.date != null &&
                message.date!.isAfter(threadMap[message.threadId]!.date!))) {
          threadMap[message.threadId] = message;
        }
      }
      List<MyMessage> list = threadMap.values.map((sms) {
        String displayName = sms.address ?? '';
        if (RegExp(r'^[\\+\\d\\s\\-\\(\\)]+$').hasMatch(displayName)) {
          displayName = '';
        }
        return MyMessage(
            name: displayName,
            lastMessage: sms.body,
            address: sms.address,
            date: sms.date,
            threadId: sms.threadId);
      }).toList();
      if (list.isEmpty) {
        emit(state.copyWith(myMessages: [], messages: messages));
        return;
      }
      try {
        final contacts = await getContactsIfNeeded();
        // Rehber eşleştirmesini Map ile yap
        final Map<String, String> phoneToName = {};
        for (var element in contacts) {
          if (element.phones.isNotEmpty) {
            for (var phone in element.phones) {
              final normalized = cleanPhoneNumber(phone.number);
              if (normalized.isNotEmpty) {
                phoneToName[normalized] = element.displayName;
              }
            }
          }
        }
        for (var item in list) {
          if (item.address != null) {
            final normalized = cleanPhoneNumber(item.address!);
            if (phoneToName.containsKey(normalized)) {
              item.name = phoneToName[normalized]!;
            }
          }
        }
      } catch (e) {
        print("Error matching contacts: $e");
      }
      list.sort((a, b) => b.date!.compareTo(a.date!));
      emit(state.copyWith(
          myMessages: list,
          messages: messages,
          timestamp: DateTime.now().millisecondsSinceEpoch));
      print(
          "Function completion time: \\${DateTime.now().difference(fonksiyonBaslangic).inMilliseconds}ms");
    } catch (e) {
      print("Error in getMessages: $e");
      emit(state.copyWith(myMessages: [], messages: []));
    } finally {
      _gettingMessages = false;
    }
  }

  void onSearch(String search) {
    List<SearchSmsMessageModel> searchResult = [];
    if (search.isNotEmpty) {
      for (var element in state.messages) {
        for (var item in state.myMessages) {
          if (item.address == element.address) {
            if (item.name != null) {
              if (item.name!.toLowerCase().contains(search) ||
                  item.address!.toLowerCase().contains(search) ||
                  element.body!.toLowerCase().contains(search)) {
                searchResult.add(SearchSmsMessageModel(name: item.name, address: item.address, body: element.body, date: element.date));
              }
            } else {
              if (item.address!.toLowerCase().contains(search) || element.body!.toLowerCase().contains(search)) {
                searchResult.add(SearchSmsMessageModel(name: item.address, address: item.address, body: element.body, date: element.date));
              }
            }
          }
        }
      }
    }

    emit(state.copyWith(search: search, searchResult: searchResult));
  }

  void onClearSearch() {
    emit(state.copyWith(search: null, searchResult: []));
  }

  Future<void> getSpam() async {
    try {
      final Database db = await openDatabase(
        'SpamSMS',
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute(
              'CREATE TABLE Messages (id INTEGER PRIMARY KEY AUTOINCREMENT, address TEXT, message TEXT)');
        });
      
      final List<Map<String, dynamic>> results = await db.query('Messages');
      if (results.isNotEmpty) {
        emit(state.copyWith(spam: results.map((e) => Spam.fromJson(e)).toList().reversed.toList()));
      } else {
        emit(state.copyWith(spam: []));
      }
      await db.close();
    } catch (e) {
      print("Error in getSpam: $e");
      emit(state.copyWith(spam: []));
    }
  }

  void deleteSpam(Spam spam, context) async {
    showDialog(
        context: context,
        builder: (context) {
          return _alert(context, spam);
        });
  }

  _alert(BuildContext context, Spam spam) {
    return AlertDialog(
      title: const Text('Uyarı'),
      content: const Text('Bu mesajı silmek istediğinize emin misiniz?'),
      actions: [
        TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('İptal')),
        TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final Database db = await openDatabase('SpamSMS');
              await db.delete('Messages', where: 'id = ?', whereArgs: [spam.id]);
              getSpam();
            },
            child: const Text('Sil')),
      ],
    );
  }
  // Telefon numarasını temizleme (sadece rakamları bırakır ve Türk formatına göre normalleştirir)
  String cleanPhoneNumber(String number) {
    String cleaned = number.replaceAll(RegExp(r'\D'), ''); // Remove all non-digits

    // If it starts with +90, remove it
    if (cleaned.startsWith('90') && cleaned.length > 10) {
      cleaned = cleaned.substring(2);
    }
    // If it starts with 0 and is 11 digits long (e.g., 05xx...), remove the 0
    if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }

  // Mesaj gönderme ekranı için state temizleme fonksiyonu
  void clearTextField() {
    emit(state.copyWith(text: ""));
    if (state.controller != null) {
      state.controller!.clear();
    }
  }
}
