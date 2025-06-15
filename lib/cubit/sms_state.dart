// ignore_for_file: must_be_immutable

part of 'sms_cubit.dart';

class SmsState extends Equatable {
  bool isInit;
  List<SmsMessage> messages;
  bool isLoading;
  String? search;
  List<SearchSmsMessageModel> searchResult;
  List<MyMessage> myMessages;
  List<Spam> spam;
  List<SmsMessage> filtingMessages;
  String? address;
  List<Contact> contactList;
  TextEditingController? controller;
  List<Contact> sendResult;
  String? text;
  String? name;
  int? timestamp;

  SmsState({
    this.isInit = false,
    this.messages = const [],
    this.isLoading = false,
    this.search = "",
    this.searchResult = const [],
    this.myMessages = const [],
    this.spam = const [],
    this.filtingMessages = const [],
    this.address,
    this.contactList = const [],
    this.sendResult = const [],
    this.text = "",
    this.controller,
    this.name = "",
    this.timestamp,
  });

  SmsState copyWith({
    bool? isInit,
    List<SmsMessage>? messages,
    bool? isLoading,
    String? search,
    List<SearchSmsMessageModel>? searchResult,
    List<MyMessage>? myMessages,
    List<Spam>? spam,
    List<SmsMessage>? filtingMessages,
    String? address,
    List<Contact>? contactList,
    List<Contact>? sendResult,
    String? text,
    TextEditingController? controller,
    String? name,
    int? timestamp,
  }) {
    return SmsState(
      isInit: isInit ?? this.isInit,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      search: search ?? this.search,
      searchResult: searchResult ?? this.searchResult,
      myMessages: myMessages ?? this.myMessages,
      spam: spam ?? this.spam,
      filtingMessages: filtingMessages ?? this.filtingMessages,
      address: address ?? this.address,
      contactList: contactList ?? this.contactList,
      sendResult: sendResult ?? this.sendResult,
      text: text ?? this.text,
      controller: controller ?? this.controller,
      name: name ?? this.name,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [
        isInit,
        messages,
        isLoading,
        search,
        searchResult,
        myMessages,
        spam,
        filtingMessages,
        address,
        contactList,
        sendResult,
        text,
        controller,
        name,
        timestamp,
      ];
}
