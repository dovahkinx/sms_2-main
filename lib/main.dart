import 'dart:async';
import 'dart:io';

import 'package:another_telephony/telephony.dart' show Telephony;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:get_it/get_it.dart';
import 'package:permission_handler/permission_handler.dart';

import 'cubit/sms_cubit.dart';
import 'view/home_view.dart';

// Global erişim için GetIt örneği
final getIt = GetIt.instance;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);

  // SmsCubit'in kaydı
  final smsCubit = SmsCubit();
  getIt.registerSingleton<SmsCubit>(smsCubit);

  // SMS ve telefon izinleri
  if (await Telephony.instance.requestPhoneAndSmsPermissions == false) {
    await Telephony.instance.requestPhoneAndSmsPermissions;
  }
  
  // Android 13+ için bildirim izni
  if (Platform.isAndroid) {
    // Bildirim iznini sorgula
    final notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      // Bildirim izni yoksa iste
      await Permission.notification.request();
      print("Bildirim izni durumu: ${await Permission.notification.status}");
    }
  }

  // Method channel işlemleri
  var channel = const MethodChannel('com.dovahkin.sms_guard');
  await channel.invokeMethod('bert').then((value) => print("value: $value"));
  
  // Event channel ile SMS alımı - Doğrudan native'den bildirim almak için
  const EventChannel eventChannel = EventChannel('com.dovahkin.sms_guard/sms');
  eventChannel.receiveBroadcastStream().listen((dynamic message) {
    print("EventChannel'dan SMS alındı: $message");
    
    // SMS'i SmsCubit'e iletiyoruz
    getIt<SmsCubit>().onNewMessage(message);
    
  }, onError: (dynamic error) {
    print("EventChannel hatası: $error");
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SmsCubit>(
          create: (context) => getIt<SmsCubit>(),
        ),
      ],
      child: MaterialApp(
        title: 'SMS Guard',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF009688), // Teal renk tonu
            brightness: Brightness.light,
            primary: const Color(0xFF009688),
            secondary: const Color(0xFF00897B),
            background: const Color(0xFFF5F7FA),
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 28, 
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
            titleLarge: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
            ),
            titleMedium: TextStyle(
              fontSize: 16, 
              fontWeight: FontWeight.w500,
              letterSpacing: 0.15,
            ),
            bodyLarge: TextStyle(
              fontSize: 16, 
              letterSpacing: 0.5,
            ),
            bodyMedium: TextStyle(
              fontSize: 14, 
              letterSpacing: 0.25,
            ),
            labelLarge: TextStyle(
              fontSize: 14, 
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
            systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
            ),
            iconTheme: const IconThemeData(color: Color(0xFF009688)),
            titleTextStyle: const TextStyle(
              color: Color(0xFF212121), 
              fontSize: 18, 
              fontWeight: FontWeight.w600,
              letterSpacing: 0.15,
            ),
          ),
          cardTheme: CardTheme(
            elevation: 0.5,
            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.grey.withOpacity(0.1), width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF009688),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF009688),
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          dividerTheme: DividerTheme.of(context).copyWith(
            space: 1,
            thickness: 0.5,
            color: Colors.grey.withOpacity(0.2),
          ),
          listTileTheme: const ListTileThemeData(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            tileColor: Colors.white,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF009688)),
            ),
          ),
        ),
        debugShowCheckedModeBanner: false,
        home: const HomeScreen(),
      ),
    );
  }
}
