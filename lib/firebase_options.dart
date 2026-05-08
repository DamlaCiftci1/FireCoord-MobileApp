// ============================================================
//  Bu dosyayı Firebase Console'dan oluşturun:
//  Terminal: flutterfire configure
//  veya Firebase Console > Project Settings > Your Apps
//
//  Adımlar:
//  1. https://console.firebase.google.com adresine gidin
//  2. Yeni proje oluşturun (firecoord)
//  3. Android uygulaması ekleyin (package: com.firecoord.mobile)
//  4. flutterfire configure komutu ile bu dosyayı otomatik oluşturun
// ============================================================

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ios;
    }
    throw UnsupportedError('Bu platform için Firebase yapılandırması yapılmamış.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBdaHQtzyi097rtIH13EScBy17IWNMBLVk',
    appId: '1:988925603140:android:63b805a8f52c2f0d347b11',
    messagingSenderId: '988925603140',
    projectId: 'firecoord-2da06',
    databaseURL: 'https://firecoord-2da06-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'firecoord-2da06.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBdaHQtzyi097rtIH13EScBy17IWNMBLVk',
    appId: '1:988925603140:android:63b805a8f52c2f0d347b11',
    messagingSenderId: '988925603140',
    projectId: 'firecoord-2da06',
    databaseURL: 'https://firecoord-2da06-default-rtdb.europe-west1.firebasedatabase.app',
    storageBucket: 'firecoord-2da06.firebasestorage.app',
    iosBundleId: 'com.firecoord.mobile',
  );
}
