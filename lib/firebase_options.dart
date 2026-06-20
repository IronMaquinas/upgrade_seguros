import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyClT8YegIloRniaYoV15dkZZvAR8SMBFC4',
    appId: '1:42121837662:web:0b31003128497adc0b08cf',
    messagingSenderId: '42121837662',
    projectId: 'upgrade-seguros',
    authDomain: 'upgrade-seguros.firebaseapp.com',
    storageBucket: 'upgrade-seguros.appspot.com',
    measurementId: 'G-5SF7VHGESR',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'SUA_API_KEY_ANDROID',
    appId: 'SEU_APP_ID_ANDROID',
    messagingSenderId: 'SEU_MESSAGING_SENDER_ID',
    projectId: 'upgrade-seguros',
    storageBucket: 'upgrade-seguros.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'SUA_API_KEY_IOS',
    appId: 'SEU_APP_ID_IOS',
    messagingSenderId: 'SEU_MESSAGING_SENDER_ID',
    projectId: 'upgrade-seguros',
    storageBucket: 'upgrade-seguros.appspot.com',
    iosBundleId: 'SEU_BUNDLE_ID',
  );
}