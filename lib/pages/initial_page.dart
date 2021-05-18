import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_segment/flutter_segment.dart';
import 'package:lottie/lottie.dart';
import 'package:twake/blocs/account_cubit/account_cubit.dart';
import 'package:twake/blocs/add_workspace_cubit/add_workspace_cubit.dart';
import 'package:twake/blocs/auth_bloc/auth_bloc.dart';
import 'package:twake/blocs/channels_bloc/channels_bloc.dart';
import 'package:twake/blocs/companies_bloc/companies_bloc.dart';
import 'package:twake/blocs/connection_bloc/connection_bloc.dart';
import 'package:twake/blocs/directs_bloc/directs_bloc.dart';
import 'package:twake/blocs/draft_bloc/draft_bloc.dart';
import 'package:twake/blocs/edit_channel_cubit/edit_channel_cubit.dart';
import 'package:twake/blocs/fields_cubit/fields_cubit.dart';
import 'package:twake/blocs/file_upload_bloc/file_upload_bloc.dart';
import 'package:twake/blocs/member_cubit/member_cubit.dart';
import 'package:twake/blocs/mentions_cubit/mentions_cubit.dart';
import 'package:twake/blocs/messages_bloc/messages_bloc.dart';
import 'package:twake/blocs/notification_bloc/notification_bloc.dart';
import 'package:twake/blocs/profile_bloc/profile_bloc.dart';
import 'package:twake/blocs/sheet_bloc/sheet_bloc.dart';
import 'package:twake/blocs/threads_bloc/threads_bloc.dart';
import 'package:twake/blocs/workspaces_bloc/workspaces_bloc.dart';
import 'package:twake/blocs/add_channel_bloc/add_channel_bloc.dart';
import 'package:twake/config/dimensions_config.dart';
import 'package:twake/pages/auth_page.dart';
import 'package:twake/pages/routes.dart';
import 'package:twake/pages/web_auth_page.dart';
import 'package:twake/widgets/common/network_status_bar.dart';
import 'package:twake/blocs/connection_bloc/connection_bloc.dart' as cb;

class InitialPage extends StatefulWidget {
  @override
  _InitialPageState createState() => _InitialPageState();
}

class _InitialPageState extends State<InitialPage> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    BlocProvider.of<AuthBloc>(context).add(AuthInitialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(
        Duration(seconds: 2),
        () => BlocProvider.of<ConnectionBloc>(context).add(
          CheckConnectionState(),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  Widget buildSplashScreen() {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: Dim.heightPercent(13),
          height: Dim.heightPercent(13),
          child: Lottie.asset(
            'assets/animations/splash.json',
            animate: true,
            repeat: true,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) Segment.screen(screenName: 'Initial screen');
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (_, current) =>
            current is! HostValidation &&
            current is! HostValidated &&
            current is! HostInvalid,
        builder: (ctx, state) {
          // print("BUILDING INITIAL PAGE");
          if (state is AuthInitializing) {
            return buildSplashScreen();
          }
          if (state is Unauthenticated || state is HostReset) {
            return AuthPage();
            // return WebAuthPage();
          }
          if (state is Registration) {
            return WebAuthPage(state.link);
          }
          if (state is PasswordReset) {
            return WebAuthPage(state.link);
          }
          if (state is Authenticated) {
            return MultiBlocProvider(
              providers: [
                BlocProvider<NotificationBloc>(
                  lazy: false,
                  create: (_) => NotificationBloc(
                    authBloc: BlocProvider.of<AuthBloc>(ctx),
                    connectionBloc: BlocProvider.of<cb.ConnectionBloc>(ctx),
                    navigator: _navigatorKey,
                  )..setSubscriptions(),
                ),
                BlocProvider<ProfileBloc>(
                  create: (ctx) => ProfileBloc(
                    state.initData.profile!,
                    notificationBloc: BlocProvider.of<NotificationBloc>(ctx),
                  ),
                  lazy: false,
                ),
                BlocProvider<CompaniesBloc>(
                  lazy: false,
                  create: (ctx) => CompaniesBloc(
                    state.initData.companies!,
                    BlocProvider.of<NotificationBloc>(ctx),
                  ),
                ),
                BlocProvider<WorkspacesBloc>(
                    lazy: false,
                    create: (ctx) {
                      return WorkspacesBloc(
                        repository: state.initData.workspaces!,
                        companiesBloc: BlocProvider.of<CompaniesBloc>(ctx),
                        notificationBloc:
                            BlocProvider.of<NotificationBloc>(ctx),
                      );
                    }),
                BlocProvider<ChannelsBloc>(create: (ctx) {
                  return ChannelsBloc(
                    repository: state.initData.channels!,
                    workspacesBloc: BlocProvider.of<WorkspacesBloc>(ctx),
                    notificationBloc: BlocProvider.of<NotificationBloc>(ctx),
                  );
                }),
                BlocProvider<DirectsBloc>(create: (ctx) {
                  return DirectsBloc(
                    repository: state.initData.directs!,
                    companiesBloc: BlocProvider.of<CompaniesBloc>(ctx),
                    notificationBloc: BlocProvider.of<NotificationBloc>(ctx),
                  );
                }),
                BlocProvider<MessagesBloc<ChannelsBloc>>(
                  create: (ctx) {
                    return MessagesBloc<ChannelsBloc>(
                      repository: state.initData.messages,
                      channelsBloc: BlocProvider.of<ChannelsBloc>(ctx),
                      notificationBloc: BlocProvider.of<NotificationBloc>(ctx),
                    );
                  },
                  lazy: false,
                ),
                BlocProvider<MessagesBloc<DirectsBloc>>(
                  create: (ctx) {
                    return MessagesBloc<DirectsBloc>(
                      repository: state.initData.messagesDirect,
                      channelsBloc: BlocProvider.of<DirectsBloc>(ctx),
                      notificationBloc: BlocProvider.of<NotificationBloc>(ctx),
                    );
                  },
                  lazy: false,
                ),
                BlocProvider<ThreadsBloc<ChannelsBloc>>(
                  create: (ctx) {
                    return ThreadsBloc<ChannelsBloc>(
                      repository: state.initData.threads,
                      messagesBloc:
                          BlocProvider.of<MessagesBloc<ChannelsBloc>>(ctx),
                      notificationBloc: BlocProvider.of<NotificationBloc>(ctx),
                    );
                  },
                  lazy: false,
                ),
                BlocProvider<ThreadsBloc<DirectsBloc>>(
                  create: (ctx) {
                    return ThreadsBloc<DirectsBloc>(
                      repository: state.initData.threads,
                      messagesBloc:
                          BlocProvider.of<MessagesBloc<DirectsBloc>>(ctx),
                      notificationBloc: BlocProvider.of<NotificationBloc>(ctx),
                    );
                  },
                  lazy: false,
                ),
                BlocProvider<SheetBloc>(
                  create: (_) => SheetBloc(state.initData.sheet!),
                  lazy: false,
                ),
                BlocProvider<AddChannelBloc>(
                  create: (_) => AddChannelBloc(
                    state.initData.addChannel,
                    state.initData.addDirect,
                  ),
                  lazy: false,
                ),
                BlocProvider<DraftBloc>(
                  create: (_) => DraftBloc(state.initData.draft),
                  lazy: false,
                ),
                BlocProvider<AddWorkspaceCubit>(
                  create: (_) => AddWorkspaceCubit(state.initData.addWorkspace),
                  lazy: false,
                ),
                BlocProvider<FieldsCubit>(
                  create: (_) => FieldsCubit(state.initData.fields),
                  lazy: false,
                ),
                BlocProvider<EditChannelCubit>(
                  create: (_) => EditChannelCubit(state.initData.editChannel),
                  lazy: false,
                ),
                BlocProvider<MemberCubit>(
                  create: (_) => MemberCubit(state.initData.channelMembers),
                  lazy: false,
                ),
                BlocProvider<MentionsCubit>(create: (_) => MentionsCubit()),
                BlocProvider<FileUploadBloc>(
                  create: (_) => FileUploadBloc(),
                  lazy: false,
                ),
                BlocProvider<AccountCubit>(
                  create: (context) => AccountCubit(
                    state.initData.account,
                    fileUploadBloc: BlocProvider.of<FileUploadBloc>(context),
                  ),
                  lazy: false,
                ),
              ],
              child: WillPopScope(
                onWillPop: () async =>
                    !await _navigatorKey.currentState!.maybePop(),
                child: Stack(
                  children: [
                    Navigator(
                      key: _navigatorKey,
                      initialRoute: Routes.root,
                      onGenerateRoute: (settings) =>
                          Routes.onGenerateRoute(settings.name),
                    ),
                    Positioned(
                      top: Dim.heightPercent((kToolbarHeight * 0.15).round()) +
                          MediaQuery.of(context).padding.top,
                      child: BlocBuilder<cb.ConnectionBloc, cb.ConnectionState>(
                          builder: (context, state) {
                        // print('Connection state: $state');
                        return AnimatedSwitcher(
                          duration: Duration(milliseconds: 250),
                          switchOutCurve: Threshold(0),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, -1),
                                end: const Offset(0, 0),
                              ).animate(animation),
                              child: child,
                            );
                          },
                          child: state is cb.ConnectionLost
                              ? Container(
                                  key: UniqueKey(),
                                  child: NetworkStatusBar(),
                                )
                              : SizedBox(key: UniqueKey()),
                        );
                        // if (state is cb.ConnectionLost) {
                        //   return Positioned(
                        //     top: Dim.heightPercent(
                        //             (kToolbarHeight * 0.15).round()) +
                        //         MediaQuery.of(context).padding.top,
                        //     child: NetworkStatusBar(),
                        //   );
                        // } else {
                        //   return const SizedBox();
                        // }
                      }),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // Authenticating or some unhandled state
            // print('UNHANDLED STATE: $state');
            return buildSplashScreen();
          }
        },
      ),
    );
  }
}
