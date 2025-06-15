// ignore_for_file: use_build_context_synchronously, deprecated_member_use, unrelated_type_equality_checks

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_sms_inbox/flutter_sms_inbox.dart' show SmsMessage, SmsMessageKind;
import 'package:sms_guard/services/sms_remover.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_chat_bubble/chat_bubble.dart';

import '../cubit/sms_cubit.dart';
import '../widgets/bottom_send_messages.dart';

class MessageScreen extends StatefulWidget {
  final String name;
  final String address;
  
  const MessageScreen({super.key, required this.name, required this.address});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isRefreshing = false;
  
  @override
  void initState() {
    super.initState();
    // Açılışta mesajları taze olarak yükle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshMessages();
    });
  }
  
  @override
  void dispose() {
    textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // Mesajları yenile
  Future<void> _refreshMessages() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    if (context.mounted) {
      await BlocProvider.of<SmsCubit>(context).forceRefresh();
      await BlocProvider.of<SmsCubit>(context).filterMessageForAdress(widget.address);
      
      // Scroll to bottom after frame is drawn
      if (_scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
    _isRefreshing = false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SmsCubit, SmsState>(
      listener: (context, state) {},
      builder: (context, state) {
        // Mesajları kontrol et
        if (state.filtingMessages.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFFF5F5F5),
            appBar: _appbar(context),
            body: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.message_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Mesaj bulunamadı",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _refreshMessages,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: const Text("Yenile"),
                        ),
                      ],
                    ),
                  ),
                ),
                SendingMessageBox(
                  textController: textController,
                  address: widget.address,
                ),
              ],
            ),
          );
        }
        
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: _appbar(context),
          body: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshMessages,
                  color: Theme.of(context).colorScheme.primary,
                  child: ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    itemCount: state.filtingMessages.length,
                    itemBuilder: (BuildContext context, int index) {
                      var message = state.filtingMessages[index];
                      
                      // Zaman damgası ekleyelim
                      final bool showDate = index == state.filtingMessages.length - 1 || 
                        _shouldShowDate(state.filtingMessages[index], 
                                       index < state.filtingMessages.length - 1 
                                         ? state.filtingMessages[index + 1] 
                                         : null);
                      
                      return Column(
                        children: [
                          if (showDate) _dateHeader(message),
                          _chatBubble(message, context),
                        ],
                      );
                    },
                  ),
                ),
              ),
              SendingMessageBox(
                textController: textController,
                address: widget.address,
              ),
            ],
          ),
        );
      },
    );
  }

  AppBar _appbar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      leadingWidth: 40,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      title: Row(
        children: [
          Hero(
            tag: "avatar_${widget.address}",
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: _getAvatarIcon(widget.name, widget.address),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.name.isEmpty ? widget.address : widget.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (_shouldShowAddress(widget.name, widget.address))
                  Text(
                    widget.address,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.phone_outlined, color: Colors.blue),
          tooltip: "Ara",
          onPressed: () {
            launchUrl(Uri.parse('tel:${widget.address}'));
          },
        ),
        IconButton(
          icon: Icon(
            Icons.more_vert,
            color: Colors.grey[800],
          ),
          tooltip: "Daha Fazla",
          onPressed: () {
            _showMessageOptions(context);
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          thickness: 1,
          color: Colors.grey[200],
        ),
      ),
    );
  }

  // Mesaj seçeneklerini göster
  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: widget.name.startsWith(RegExp(r'[0-9]')) || widget.name.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : Text(
                      widget.name.isNotEmpty ? widget.name[0].toUpperCase() : "?",
                      style: const TextStyle(color: Colors.white),
                    ),
              ),
              title: Text(
                widget.name.isEmpty ? widget.address : widget.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(widget.address),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.phone_outlined, color: Theme.of(context).colorScheme.primary),
              title: const Text("Ara"),
              onTap: () {
                Navigator.pop(context);
                launchUrl(Uri.parse('tel:${widget.address}'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy_outlined, color: Colors.blue),
              title: const Text("Numarayı Kopyala"),
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.address));
                Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Numara kopyalandı'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.block_outlined, color: Colors.red[700]),
              title: const Text("Spam Olarak İşaretle"),
              onTap: () {
                Navigator.pop(context);
                // Spam işleme fonksiyonu
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Tüm Mesajları Sil"),
              onTap: () {
                Navigator.pop(context);
                // Tüm mesajları silme fonksiyonu
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  // Helper function to parse dates safely
  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) {
      return DateTime.now();
    }
    
    // First try to parse as integer timestamp
    try {
      if (dateValue is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateValue);
      }
      
      String dateStr = dateValue.toString();
      
      // Check if the string contains a date-time format
      if (dateStr.contains('-') && dateStr.contains(':')) {
        try {
          return DateTime.parse(dateStr);
        } catch (_) {
          // If parsing as DateTime fails, continue to other methods
        }
      }
      
      // Try to parse as integer timestamp
      try {
        int timestamp = int.parse(dateStr);
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      } catch (_) {
        // If all parsing fails, return current time
        return DateTime.now();
      }
    } catch (_) {
      return DateTime.now();
    }
  }
  
  // Tarih başlığını göster
  Widget _dateHeader(SmsMessage message) {
    final date = _parseDate(message.date);
    final now = DateTime.now();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    
    String dateText;
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      dateText = "Bugün";
    } else if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      dateText = "Dün";
    } else {
      dateText = DateFormat('d MMMM y', 'tr_TR').format(date);
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
  
  // İki mesaj arasında tarih farkı varsa tarih başlığını göstermaya karar ver
  bool _shouldShowDate(SmsMessage current, SmsMessage? previous) {
    if (previous == null) return true;
    
    final currentDate = _parseDate(current.date);
    final previousDate = _parseDate(previous.date);
    
    return currentDate.year != previousDate.year || 
           currentDate.month != previousDate.month || 
           currentDate.day != previousDate.day;
  }

  Widget _chatBubble(SmsMessage message, BuildContext context) {
    var position = Offset.zero;
    
    // Mesaj türünü belirle - flutter_sms_inbox kütüphanesindeki SmsMessageKind enum'una göre
    // SmsMessageKind enum'u sadece sent, received ve draft değerlerini içerir
    log("Mesaj türü: ${message.kind.toString()}, Adres: ${message.address}");
    
    // Gönderilen mesajları tespit et - SmsMessageKind.sent ise gönderilen mesajdır
    bool isSent = message.kind == SmsMessageKind.sent;
    
    // Mesaj saati - Güvenli şekilde tarihi ayrıştır
    final messageTime = _parseDate(message.date);
    final formattedTime = DateFormat('HH:mm').format(messageTime);
    
    // Renk ayarları
    final primaryColor = Theme.of(context).colorScheme.primary;
    final sentColor = primaryColor.withOpacity(0.15);
    final receivedColor = Colors.white;
    final sentTextColor = Colors.black87;
    final receivedTextColor = Colors.black87;
    
    return GestureDetector(
      onLongPressStart: (LongPressStartDetails details) {
        position = details.globalPosition;
      },
      onLongPress: () => _showMessageActionsMenu(context, message, position),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment: isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isSent) // Sol taraftaki avatar (gelen mesaj ise)
              Container(
                margin: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: _getNameColor(widget.name),
                  child: Text(
                    widget.name.isNotEmpty ? widget.name[0].toUpperCase() : "?",
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              
            Flexible(
              child: ChatBubble(
                clipper: ChatBubbleClipper6(
                  type: isSent ? BubbleType.sendBubble : BubbleType.receiverBubble,
                  radius: 16,
                  nipSize: 8,
                ),
                alignment: isSent ? Alignment.topRight : Alignment.topLeft,
                margin: EdgeInsets.zero,
                backGroundColor: isSent ? sentColor : receivedColor,
                elevation: 0.5,
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Linkify(
                        onOpen: (link) {
                          launchUrl(Uri.parse(link.url));
                        },
                        text: message.body ?? "",
                        style: TextStyle(
                          color: isSent ? sentTextColor : receivedTextColor,
                          fontSize: 15,
                          height: 1.3,
                        ),
                        linkStyle: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // Mesaj zaman bilgisi ve durumu
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Zaman bilgisi
                          Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSent ? primaryColor : Colors.grey[600],
                            ),
                          ),
                          
                          // Okundu işareti - Sadece gönderilen mesajlarda
                          if (isSent) 
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Icon(
                                Icons.done_all,
                                size: 12,
                                color: primaryColor.withOpacity(0.7),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mesaj işlemleri menüsünü göster
  void _showMessageActionsMenu(BuildContext context, SmsMessage message, Offset position) {
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Mesaj içeriği önizleme
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: const Icon(Icons.message, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "Mesaj İçeriği",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.body ?? "",
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            const Divider(),
            
            ListTile(
              leading: const Icon(Icons.content_copy_outlined, color: Colors.blue),
              title: const Text("Mesajı Kopyala"),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.body ?? ""));
                Navigator.pop(context);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Mesaj kopyalandı'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined, color: Colors.green),
              title: const Text("Mesajı Paylaş"),
              onTap: () {
                Navigator.pop(context);
                // Paylaşım işlevi
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Mesajı Sil"),
              onTap: () async {
                Navigator.pop(context);
                // Silme işlemi onayı
                final shouldDelete = await _confirmDelete(context);
                if (shouldDelete && context.mounted) {
                  _deleteMessage(context, message);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // Silme işlemi onayı
  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mesajı Sil'),
        content: const Text('Bu mesajı silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'İPTAL',
              style: TextStyle(
                color: Colors.grey[700],
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'SİL',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  // Mesajı silme
  Future<void> _deleteMessage(BuildContext context, SmsMessage message) async {
    try {
      final result = await SmsRemover().removeSmsById(
        message.id!.toString(), 
        message.threadId!.toString()
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          )
        );
        await _refreshMessages();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("SMS silme hatası: $e"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
  }

  // İsme göre renk üretme
  Color _getNameColor(String name) {
    if (name.isEmpty) return const Color(0xFF607D8B); // Default color
    
    final int hash = name.codeUnits.fold(0, (prev, element) => prev + element);
    final List<Color> colors = [
      const Color(0xFF009688), // Teal
      const Color(0xFF2196F3), // Blue
      const Color(0xFF673AB7), // Deep Purple
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF607D8B), // Blue Grey
    ];
    
    return colors[hash % colors.length];
  }
  
  // Avatar ikonu getir
  Widget _getAvatarIcon(String name, String address) {
    // Eğer isim boşsa address'i kullan
    String displayText = name.isEmpty ? address : name;
    
    if (displayText.isEmpty) {
      return const Icon(Icons.question_mark, color: Colors.white, size: 20);
    }
    
    // Eğer telefon numarası ise person ikonu göster
    if (displayText.startsWith(RegExp(r'[0-9+]'))) {
      return const Icon(Icons.person, color: Colors.white, size: 20);
    } else {
      // Kurumsal gönderen veya kişi adı - ilk harfi göster
      return Text(
        displayText[0].toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
      );
    }
  }
  
  // Address'in gösterilip gösterilmeyeceğini kontrol et
  bool _shouldShowAddress(String name, String address) {
    // Eğer isim boşsa address zaten yukarıda gösteriliyor
    if (name.isEmpty) return false;
    
    // Eğer isim telefon numarası ise address'i gösterme (aynı şey)
    if (name.startsWith(RegExp(r'[0-9+]'))) return false;
    
    // Eğer isim kurumsal gönderen ise ve address farklıysa göster
    return name != address;
  }
}
