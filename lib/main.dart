import 'dart:async';
import 'package:connectivity/connectivity.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:twake/blocs/auth_bloc/auth_bloc.dart';
import 'package:twake/blocs/configuration_cubit/configuration_cubit.dart';
import 'package:twake/blocs/connection_bloc/connection_bloc.dart' as cb;
import 'package:twake/config/dimensions_config.dart' show Dim;
import 'package:twake/config/styles_config.dart';
import 'package:twake/pages/initial_page.dart';
import 'package:twake/repositories/auth_repository.dart';
import 'package:twake/repositories/configuration_repository.dart';
import 'package:twake/services/init.dart';
import 'package:twake/utils/sentry.dart';

void main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    final AuthRepository authRepository = await initAuth();
    final ConfigurationRepository configurationRepository =
        await ConfigurationRepository.load();
    cb.ConnectionState connectionState;
    final res = await Connectivity().checkConnectivity();
    if (res == ConnectivityResult.none) {
      connectionState = cb.ConnectionLost('');
    } else if (res == ConnectivityResult.wifi) {
      connectionState = cb.ConnectionWifi();
    } else if (res == ConnectivityResult.mobile) {
      connectionState = cb.ConnectionCellular();
    }
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    FlutterError.onError = (FlutterErrorDetails details) {
      if (isInDebugMode) {
        // In development mode, simply print to console.
        FlutterError.dumpErrorToConsole(details);
      } else {
        // In production mode, report to the application zone to report to
        // Sentry.
        Zone.current.handleUncaughtError(details.exception, details.stack);
      }
    };
    runApp(TwakeMobileApp(
      authRepository,
      configurationRepository,
      connectionState,
    ));
  }, (Object error, StackTrace stackTrace) {
    // Whenever an error occurs, call the `reportError` function. This sends
    // Dart errors to the dev console or Sentry depending on the environment.
    reportError(error, stackTrace);
  });
}

class TwakeMobileApp extends StatelessWidget {
  final AuthRepository authRepository;
  final ConfigurationRepository configurationRepository;
  final cb.ConnectionState connectionState;

  TwakeMobileApp(
    this.authRepository,
    this.configurationRepository,
    this.connectionState,
  );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => OrientationBuilder(
        builder: (context, orientation) {
          Dim.init(constraints, orientation);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: StylesConfig.lightTheme,
            title: 'Twake',
            home: MultiBlocProvider(
              providers: [
                BlocProvider<cb.ConnectionBloc>(
                  create: (_) => cb.ConnectionBloc(connectionState),
                  lazy: false,
                ),
                BlocProvider<AuthBloc>(
                  create: (context) => AuthBloc(
                      authRepository, context.read<cb.ConnectionBloc>()),
                  lazy: false,
                ),
                BlocProvider<ConfigurationCubit>(
                  create: (context) =>
                      ConfigurationCubit(configurationRepository),
                  lazy: false,
                )
              ],
              child: InitialPage(),
            ),
          );
        },
      ),
    );
  }
}
