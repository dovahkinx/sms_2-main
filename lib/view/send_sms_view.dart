// ignore_for_file: use_build_context_synchronously

import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:auto_size_text_field/auto_size_text_field.dart';
import '../cubit/sms_cubit.dart';
import '../services/sms_service.dart';
import 'chat_messages_view.dart';

/// SMS gönderme ekranı
/// 
/// Kişi arama, numara girme ve SMS gönderme işlemlerini yönetir
class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  // Controller ve focus node'lar
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  
  // Durum değişkenleri
  bool _isLoading = false;
  bool _isDirectPhoneInput = false;
  
  // Sabitler
  static const Color primaryColor = Color(0xFF009688);
  
  // SmsService örneği
  final SmsService _smsService = SmsService.instance;
  
  @override
  void initState() {
    super.initState();
    // Alıcı giriş alanı değişikliklerini dinle
    _recipientController.addListener(_handleRecipientInputChange);
  }
  
  @override
  void dispose() {
    // Controllerleri ve listener'ları temizle
    _recipientController.removeListener(_handleRecipientInputChange);
    _recipientController.dispose();
    _messageController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }
  
  // Alıcı giriş alanı değiştiğinde
  void _handleRecipientInputChange() {
    final input = _recipientController.text;
    if (input.isEmpty) {
      if (_isDirectPhoneInput) {
        setState(() => _isDirectPhoneInput = false);
      }
      return;
    }
    
    // Telefon numarası ise doğrudan girişi aktifleştir
    final bool isPhone = _isPhoneNumber(input);
    if (isPhone != _isDirectPhoneInput) {
      setState(() => _isDirectPhoneInput = isPhone);
    }
    
    // State güncellemesi yap
    if (isPhone) {
      context.read<SmsCubit>().prinnt(input);
      context.read<SmsCubit>().state.text = input;
      context.read<SmsCubit>().state.name = input;
    } else {
      context.read<SmsCubit>().prinnt(input);
      context.read<SmsCubit>().resultContactWithTextEditingController(input);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: BlocConsumer<SmsCubit, SmsState>(
        listener: (context, state) {
          // Gerekli state değişikliklerini dinle
        },
        builder: (context, state) {
          return Column(
            children: [
              _buildRecipientInput(),
              
              // Direkt telefon numarası girişi göstergesi
              if (_isDirectPhoneInput && _recipientController.text.isNotEmpty)
                _buildDirectPhoneIndicator(),
              
              // Kişi listesi - arama sonuçları bölümü
              if (state.sendResult.isNotEmpty && !_isDirectPhoneInput)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),
                ),
                
              // Ana içerik alanı
              Expanded(
                child: _buildContentArea(state),
              ),
              
              // Mesaj yazma alanı
              _buildMessageComposer(state),
            ],
          );
        },
      ),
    );
  }
  
  // App bar widget'ı
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        "Mesaj Gönder", 
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
        )
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }
  
  // Alıcı giriş alanı
  Widget _buildRecipientInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
      child: TextField(
        controller: _recipientController,
        keyboardType: TextInputType.text, // TextInputType.phone yerine text kullanarak tüm karakterlere izin veriyoruz
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.person, color: primaryColor),
          hintText: "Alıcı ara veya numara gir",
          hintStyle: TextStyle(color: Colors.grey.shade600),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(30)),
            borderSide: BorderSide(color: primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          // Temizleme butonu
          suffixIcon: _recipientController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.grey),
                  onPressed: () {
                    _recipientController.clear();
                    setState(() => _isDirectPhoneInput = false);
                    context.read<SmsCubit>().resultContactWithTextEditingController("");
                  },
                )
              : null,
        ),
      ),
    );
  }
  
  // Telefon numarası girişi göstergesi
  Widget _buildDirectPhoneIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.phone,
              color: primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Gönderi alıcısı: ${_recipientController.text}",
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _messageFocusNode.requestFocus(),
              child: const Text(
                "Mesaj Yaz",
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Ana içerik alanı - Kişi listesi veya boş alan
  Widget _buildContentArea(SmsState state) {
    // Doğrudan numara girişi durumunda boş alan göster
    if (_isDirectPhoneInput) {
      return const SizedBox();
    }
    
    // Kişi listesi veya boş durum mesajları
    if (state.sendResult.isEmpty) {
      return Center(
        child: _recipientController.text.isEmpty
            ? _buildEmptyInitialState()
            : _buildNoContactsFoundState(),
      );
    }
    
    // Kişi listesi
    return ListView.builder(
      itemCount: state.sendResult.length,
      itemBuilder: (context, index) => _buildContactListItem(state.sendResult[index], state),
    );
  }
  
  // Boş başlangıç durumu
  Widget _buildEmptyInitialState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.search,
          size: 80,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 16),
        Text(
          "Kişi ara veya bir telefon numarası gir",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          "Numara ile mesaj göndermek için en az 3 rakam girin",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  // Kişi bulunamadı durumu
  Widget _buildNoContactsFoundState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.person_off,
          size: 80,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 16),
        Text(
          "Eşleşen kişi bulunamadı",
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
  
  // Kişi listesi öğesi
  Widget _buildContactListItem(contact, SmsState state) {
    final displayName = contact.displayName.isEmpty
        ? contact.phones.first.number
        : contact.displayName;
    final number = contact.phones.first.number;
    
    // Avatar harfi için ilk karakter
    final avatarChar = displayName.isNotEmpty 
        ? displayName[0].toUpperCase() 
        : "?";
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: primaryColor,
        child: Text(
          avatarChar,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        displayName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(number),
      onTap: () => _selectContact(contact, state),
    );
  }
  
  // Kişi seçimi işlemi
  void _selectContact(contact, SmsState state) {
    final displayName = contact.displayName;
    final number = contact.phones.first.number;
    
    // Numarayı temizle
    final cleanedNumber = context.read<SmsCubit>().cleanPhoneNumber(number);
    
    // State'e hem isim hem numara kaydedilir
    state.name = displayName;
    state.text = cleanedNumber;
    
    developer.log("Seçilen kişi: ${displayName.isEmpty ? 'İsimsiz' : displayName} - $number (Temizlenmiş: $cleanedNumber)");
    
    // Önemli değişiklik: Kişi adı yerine telefon numarasını göster
    _recipientController.text = cleanedNumber;
    
    _recipientController.selection = TextSelection.fromPosition(
      TextPosition(offset: _recipientController.text.length)
    );
    
    // Kişi seçilince listeyi temizle
    context.read<SmsCubit>().resultContactWithTextEditingController("");
    
    // Mesaj alanına odaklan
    _messageFocusNode.requestFocus();
  }
  
  // Mesaj yazma alanı
  Widget _buildMessageComposer(SmsState state) {
    final bool canSendMessage = _messageController.text.isNotEmpty && 
                              (_isDirectPhoneInput || state.text != null);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 6,
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: const Color(0xFFF5F5F5),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: AutoSizeTextField(
                    focusNode: _messageFocusNode,
                    controller: _messageController,
                    textAlign: TextAlign.left,
                    style: const TextStyle(fontSize: 16),
                    minLines: 1,
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: "Mesajınızı yazın...",
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                
                // Gönderme butonu
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: primaryColor,
                          ),
                        ),
                      )
                    : Material(
                        color: canSendMessage
                            ? primaryColor
                            : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(25),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(25),
                          onTap: canSendMessage
                              ? () => _sendMessage(state)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            child: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Mesaj gönderme işlemi
  Future<void> _sendMessage(SmsState state) async {
    String? phoneNumber = _isDirectPhoneInput
        ? _recipientController.text
        : state.text;

    if (phoneNumber == null || phoneNumber.isEmpty || _messageController.text.isEmpty) {
      _showCustomSnackBar(
        context: context,
        message: 'Lütfen alıcı numarası ve mesaj girdiğinizden emin olun',
        backgroundColor: Colors.red,
      );
      return;
    }

    // Apply +90 prefix if it's a 10-digit number starting with '5' before sending
    String numberToSend = context.read<SmsCubit>().cleanPhoneNumber(phoneNumber);
    if (numberToSend.length == 10 && numberToSend.startsWith('5')) {
      numberToSend = '+90$numberToSend';
    }
    
    setState(() => _isLoading = true);

    try {
      developer.log("SMS gönderiliyor -> Alıcı: $numberToSend, Mesaj: ${_messageController.text}");

      final result = await _smsService.sendSms(
        phoneNumber: numberToSend,
        message: _messageController.text,
      );
      
      // Yükleme durumunu bitir
      setState(() => _isLoading = false);
      
      // Başarı/hata durumuna göre işlem yap
      if (result.contains("başarıyla")) {
        await _handleSuccessfulSend(phoneNumber, state);
      } else {
        _showCustomSnackBar(
          context: context,
          message: result,
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      // Hata durumunda
      setState(() => _isLoading = false);
      _showCustomSnackBar(
        context: context,
        message: "Mesaj gönderirken hata: $e",
        backgroundColor: Colors.red,
      );
      developer.log("SMS gönderme hatası: $e");
    }
  }
  
  // Başarılı mesaj gönderimi işlemleri
  Future<void> _handleSuccessfulSend(String phoneNumber, SmsState state) async {
    if (!context.mounted) return;

    // Başarı bildirimi göster
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mesaj başarıyla gönderildi'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Mesaj kutusunu temizle
    _messageController.clear();

    if (!context.mounted) return;

    // Verileri yenile
    await BlocProvider.of<SmsCubit>(context).forceRefresh();
    BlocProvider.of<SmsCubit>(context).filterMessageForAdress(phoneNumber);

    developer.log("Mesaj detay sayfasına yönlendiriliyor");

    if (!context.mounted) return;

    // Mesaj detay sayfasına git
    String displayName = phoneNumber; // Default to phone number

    // Ensure the contact list is up-to-date before searching
    final smsCubit = BlocProvider.of<SmsCubit>(context);
    final contacts = await smsCubit.getContactsIfNeeded();

    final normalizedInputPhoneNumber = context.read<SmsCubit>().cleanPhoneNumber(phoneNumber);

    for (var contact in contacts) {
      if (contact.phones.isNotEmpty) {
        final normalizedContactNumber = context.read<SmsCubit>().cleanPhoneNumber(contact.phones.first.number);

        if (normalizedContactNumber == normalizedInputPhoneNumber) {
          displayName = contact.displayName;
          break;
        }
      }
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MessageScreen(
          name: displayName,
          address: phoneNumber,
        ),
      ),
    );

    // State temizleme
    if (!context.mounted) return;

    // State doğrudan değiştirmek yerine Cubit fonksiyonu ile temizle
    BlocProvider.of<SmsCubit>(context).clearTextField();
  }

  // Ortak SnackBar fonksiyonu
  void _showCustomSnackBar({
    required BuildContext context,
    required String message,
    Color? backgroundColor,
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        action: action,
      ),
    );
  }

  // Telefon numarası kontrolü (regex ile güçlendirildi)
  bool _isPhoneNumber(String text) {
    final regex = RegExp(r'^(\+\d{1,3}[- ]?)?\d{10,15} $');
    return regex.hasMatch(text);
  }

  // Telefon numarasını temizleme (sadece rakamları bırakır)
  String _cleanPhoneNumber(String number) {
    return number.replaceAll(RegExp(r'[^0-9]'), '');
  }
}
