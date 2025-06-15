// ignore_for_file: must_be_immutable, use_build_context_synchronously

import 'dart:developer';

import 'package:auto_size_text_field/auto_size_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/sms_cubit.dart';

class SendingMessageBox extends StatefulWidget {
  SendingMessageBox({
    super.key,
    required this.textController,
    required this.address,
  });

  TextEditingController textController;
  final String address;

  @override
  State<SendingMessageBox> createState() => _SendingMessageBoxState();
}

class _SendingMessageBoxState extends State<SendingMessageBox> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {}); // Odak değiştiğinde yeniden render et
    });
    
    // TextEditingController için listener ekle
    widget.textController.addListener(() {
      setState(() {}); // Metin değiştiğinde UI'ı güncelle
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    // TextEditingController listener'ını temizle
    widget.textController.removeListener(() {
      setState(() {});
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sol taraftaki emoji butonu
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.add_circle_outline,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),

          // Emoji butonu
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.emoji_emotions_outlined,
              color: Theme.of(context).primaryColor,
              size: 24,
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
          ),

          // Mesaj yazma alanı
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5F5), // Açık yeşil-mavi ton
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF82CFCF), // Turkuaz gibi bir kenar rengi
                  width: 1,
                ),
              ),
              child: AutoSizeTextField(
                focusNode: _focusNode,
                controller: widget.textController,
                decoration: const InputDecoration(
                  hintTextDirection: TextDirection.ltr,
                  hintText: "Mesajınızı yazın...",
                  hintStyle: TextStyle(
                    color: Color(0xFF9EBEBE), // Gri-yeşil ton
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                 
                ),
                minLines: 1,
                maxLines: 5,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          ),

          // Ses mesajı / gönder butonu
          Container(
            margin: const EdgeInsets.only(left: 8),
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF82CFCF), // Turkuaz
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: widget.textController.text.isEmpty 
                ? () {
                    // Metin boşsa mikrofon işlevi
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ses kaydı özelliği yakında!'),
                        duration: Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } 
                : () => _sendMessage(context),
              icon: Icon(
                widget.textController.text.isEmpty ? Icons.mic : Icons.send,
                color: Colors.white,
                size: 20,
              ),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(BuildContext context) async {
    if (widget.textController.text.isEmpty) {
      // Metin boşsa mikrofon işlevi
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ses kaydı özelliği yakında!'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    log("address: ${widget.address}");
    log("text: ${widget.textController.text}");

    // Telefon numarası veya mesaj boş ise işlemi durdur
    if (widget.address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen alıcı numarası girdiğinizden emin olun'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Method Channel ile Kotlin kodunu çağır
      var channel = const MethodChannel('com.dovahkin.sms_guard');

      // SMS gönder
      final result = await channel.invokeMethod('sendSms', {
        "address": widget.address,
        "body": widget.textController.text
      });

      log("SMS gönderme sonucu: $result");

      // Başarılı bildirim göster
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text(result),
              ],
            ),
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Hata durumunda bildirim göster
      log("SMS gönderme hatası: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("SMS gönderme hatası: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return; // Hata durumunda diğer işlemleri yapma
    }

    // SMS'i gönderildikten sonra veritabanına kaydet
    widget.textController.clear();
    if (context.mounted) {
      // Önce mevcut filtrelemeyi yap
      BlocProvider.of<SmsCubit>(context).filterMessageForAdress(widget.address);
      // Tam bir yenileme gerçekleştir - ana ekran ve tüm mesaj listelerini günceller
      await BlocProvider.of<SmsCubit>(context).forceRefresh();
      BlocProvider.of<SmsCubit>(context).state.text = "";
    }
  }
}
