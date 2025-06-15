import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/sms_cubit.dart';

class SpamScreen extends StatelessWidget {
  const SpamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(context),
      body: BlocConsumer<SmsCubit, SmsState>(
        listener: (context, state) {},
        builder: (context, state) {
          if (state.spam.isEmpty) {
            return _buildEmptyState();
          } else {
            return _buildSpamList(context, state);
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showFilterOptions(context);
        },
        icon: const Icon(Icons.shield_outlined),
        label: const Text("Filtreler"),
        tooltip: "Spam filtrelerini ayarla",
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
  
  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.block_outlined,
              color: Colors.red,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            "Spam SMS'ler",
            style: TextStyle(
              color: Colors.grey[800],
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ],
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        onPressed: () {
          Navigator.pop(context);
        },
      ),
      actions: [
        IconButton(
          onPressed: () {
            _showSpamInfo(context);
          },
          icon: Icon(
            Icons.info_outline,
            color: Colors.grey[700],
          ),
          tooltip: "Spam SMS'ler Hakkında",
        ),
        const SizedBox(width: 8),
      ],
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.no_sim_outlined,  // Veya Icons.block_outlined da uygun olabilir
            size: 120,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            "Hiç Spam SMS Bulunamadı",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              "Engellenen spam mesajlar burada görüntülenecektir",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Spam filtre ayarları sayfasına gitme işlemi
            },
            icon: const Icon(Icons.filter_list),
            label: const Text("Spam Filtreleri Ayarla"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSpamList(BuildContext context, SmsState state) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: state.spam.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        var spam = state.spam[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.red.shade100,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        spam.address,
                        style: const TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _confirmDelete(context, spam);
                      },
                      icon: Icon(
                        Icons.delete_outline,
                        color: Colors.red[300],
                      ),
                      tooltip: "Spam kaydını sil",
                    ),
                  ],
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Text(
                    spam.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton.icon(
                    onPressed: () {
                      // SMS'i beyaz listeye alma işlemi burada yapılabilir
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text("Güvenli Olarak İşaretle"),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.green,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  void _confirmDelete(BuildContext context, var spam) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Spam Kaydını Sil'),
        content: const Text('Bu spam kaydını silmek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'İPTAL',
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              BlocProvider.of<SmsCubit>(context).deleteSpam(spam, context);
            },
            child: const Text(
              'SİL',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
  
  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.block_outlined, color: Colors.red),
              title: Text("Otomatik Spam Filtreleri"),
              subtitle: Text("Sistem tarafından tanınan spam mesajları otomatik engelle"),
              trailing: Switch(value: true, onChanged: null),
            ),
            const ListTile(
              leading: Icon(Icons.filter_list, color: Colors.orange),
              title: Text("Kelime Bazlı Filtreler"),
              subtitle: Text("Belirli kelimeleri içeren mesajları engelle"),
            ),
            const ListTile(
              leading: Icon(Icons.texture, color: Colors.blue),
              title: Text("Örüntü Bazlı Filtreler"),
              subtitle: Text("Belirli mesaj örüntülerini engelle"),
            ),
            const ListTile(
              leading: Icon(Icons.history, color: Colors.green),
              title: Text("Spam Geçmişi"),
              subtitle: Text("Engellenen spam mesajların geçmişini görüntüle"),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showSpamInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 10),
            const Text('Spam SMS\'ler Hakkında'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SMS Guard, çeşitli yöntemlerle spam SMS\'leri tespit eder ve engeller:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• Bilinen spam göndericileri otomatik engeller'),
              Text('• Şüpheli mesaj içeriklerini analiz eder'),
              Text('• Kullanıcıların bildirdiği spam mesajları kaydeder'),
              Text('• Kara liste ve beyaz liste filtreleri uygular'),
              SizedBox(height: 12),
              Text(
                'Yanlışlıkla spam olarak işaretlenen mesajları "Güvenli Olarak İşaretle" seçeneği ile beyaz listeye ekleyebilirsiniz.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ANLADIM'),
          ),
        ],
      ),
    );
  }
}
