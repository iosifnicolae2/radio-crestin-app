import 'package:fast_cached_network_image/fast_cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:radio_crestin/pages/HomePage.dart';
import 'package:radio_crestin/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'appAudioHandler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'globals.dart' as globals;
import 'dart:developer' as developer;

final getIt = GetIt.instance;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // NotificationSettings settings = await messaging.requestPermission(
  //   alert: true,
  //   announcement: true,
  //   badge: true,
  //   carPlay: false,
  //   criticalAlert: true,
  //   provisional: true,
  //   sound: true,
  // );
  // developer.log('User granted permission: ${settings.authorizationStatus}');

  String? fcmToken = await messaging.getToken(
    vapidKey: "BFYrRk168C5k4q9h4-01z1tr6rQxplERMVolnqqSMXjLNIEnCTA_oL2Lb1OI5kOu9C_tLyWd0jorBgt7ChW3Lxg",
  );
  globals.fcmToken = fcmToken ?? "";
  developer.log('fcmToken: $fcmToken');
  final prefs = await SharedPreferences.getInstance();
  if(prefs.getBool('_notificationsEnabled') ?? true) {
    await FirebaseAnalytics.instance.setUserProperty(name: 'personalized_n', value: 'true');
  }

  final remoteConfig = FirebaseRemoteConfig.instance;
  await remoteConfig.setConfigSettings(RemoteConfigSettings(
    fetchTimeout: const Duration(minutes: 1),
    minimumFetchInterval: const Duration(hours: 1),
  ));

  await remoteConfig.fetchAndActivate();

  await FastCachedImageConfig.init(clearCacheAfter: const Duration(days: 30));

  // We're using HiveStore for persistence,
  // so we need to initialize Hive.
  await initHiveForFlutter();

  final HttpLink httpLink = HttpLink(
    CONSTANTS.GRAPHQL_ENDPOINT,
  );

  final AuthLink authLink = AuthLink(
    getToken: () async => CONSTANTS.GRAPHQL_AUTH,
  );

  final Link graphqlLink = authLink.concat(httpLink);

  // The default store is the InMemoryStore, which does NOT persist to disk
  final graphQlCache = GraphQLCache(store: HiveStore());

  GraphQLClient graphqlClient = GraphQLClient(
    link: graphqlLink,
    cache: graphQlCache,
  );

  getIt.registerSingleton<AppAudioHandler>(await initAudioService(graphqlClient: graphqlClient));

  // // Only call clearSavedSettings() during testing to reset internal values.
  // await Upgrader.clearSavedSettings(); // REMOVE this for release builds

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(
          create: (_) => getIt<AppAudioHandler>()),
    ],
    child: const RadioCrestinApp(),
  ));

}

class RadioCrestinApp extends StatelessWidget {
  const RadioCrestinApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radio Crestin',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: const HomePage(),
    );
  }
}
