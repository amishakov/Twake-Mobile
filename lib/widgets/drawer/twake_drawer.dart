import 'package:badges/badges.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:twake/blocs/auth_bloc/auth_bloc.dart';
import 'package:twake/blocs/companies_bloc/companies_bloc.dart';
import 'package:twake/blocs/profile_bloc/profile_bloc.dart';
import 'package:twake/blocs/sheet_bloc/sheet_bloc.dart';
import 'package:twake/blocs/workspaces_bloc/workspaces_bloc.dart';
import 'package:twake/config/dimensions_config.dart' show Dim;
import 'package:twake/models/company.dart';
import 'package:twake/repositories/sheet_repository.dart';
import 'package:twake/utils/navigation.dart';
import 'package:twake/widgets/common/warning_dialog.dart';
import 'package:twake/widgets/common/image_avatar.dart';

const double ICON_SIZE_MULTIPLIER = 4.5;

class TwakeDrawer extends StatefulWidget {
  @override
  _TwakeDrawerState createState() => _TwakeDrawerState();
}

class _TwakeDrawerState extends State<TwakeDrawer> {
  var _companiesHidden = true;
  var _canCreateWorkspace = false;
  List<Company?>? _companies = <Company>[];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Dim.widthPercent(80),
      child: Drawer(
        child: SafeArea(
          child: BlocBuilder<CompaniesBloc, CompaniesState>(
              buildWhen: (_, current) => current is CompaniesLoaded,
              builder: (context, state) {
                if (state is CompaniesLoaded) {
                  _companies = state.companies;

                  final selectedCompany = state.selected!;
                  final permissions = selectedCompany.permissions!;
                  if (permissions.length > 0 &&
                      permissions.contains('CREATE_WORKSPACES')) {
                    _canCreateWorkspace = true;
                  } else {
                    _canCreateWorkspace = false;
                  }
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15.0),
                      child: Row(
                        children: [
                          Text(
                            _companiesHidden ? 'Workspaces' : 'Choose company',
                            style: TextStyle(
                              fontSize: 18.0,
                              fontWeight: FontWeight.bold,
                              color: Color(0xff444444),
                            ),
                          ),
                          Spacer(),
                          if (_canCreateWorkspace)
                            IconButton(
                              icon: Icon(
                                Icons.add,
                                size: Dim.tm3(decimal: .3),
                                color: Colors.black,
                              ),
                              onPressed: () {
                                final isDrawerOpen =
                                    Scaffold.of(context).isDrawerOpen;
                                if (isDrawerOpen) {
                                  Navigator.pop(context); // close the drawer
                                  context.read<SheetBloc>()
                                    ..add(SetFlow(flow: SheetFlow.addWorkspace))
                                    ..add(OpenSheet());
                                }
                              },
                            ),
                          IconButton(
                            color: Color(0xff444444),
                            onPressed: () {
                              setState(() {
                                _companiesHidden = false;
                              });
                            },
                            iconSize: Dim.tm4(),
                            icon: Icon(
                              Icons.loop,
                              color: Color(0xff444444),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      thickness: 2.0,
                      height: 2.0,
                      color: Color(0xffEEEEEE),
                    ),
                    SizedBox(height: Dim.hm2),
                    if (_companiesHidden)
                      Expanded(
                        child: BlocBuilder<WorkspacesBloc, WorkspaceState>(
                          builder: (ctx, state) {
                            return state is WorkspacesLoaded
                                ? ListView.builder(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 15),
                                    itemCount: state.workspaces!.length,
                                    itemBuilder: (ctx, i) => InkWell(
                                          onTap: () {
                                            BlocProvider.of<WorkspacesBloc>(ctx)
                                                .add(ChangeSelectedWorkspace(
                                                    state.workspaces![i]!.id));
                                            BlocProvider.of<ProfileBloc>(ctx)
                                                .add(UpdateBadges());
                                            Navigator.of(context).pop();
                                          },
                                          child: SizedBox(
                                            height: 62,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                ImageAvatar(
                                                  state.workspaces![i]!.logo,
                                                  width: 30,
                                                  height: 30,
                                                ),
                                                SizedBox(width: 15),
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      SizedBox(height: 12),
                                                      Text(
                                                        state
                                                            .workspaces![i]!.name!,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 16.0,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Color(0xff444444),
                                                        ),
                                                      ),
                                                      SizedBox(height: 4),
                                                      Text(
                                                        '${state.workspaces![i]!.totalMembers} members',
                                                        style: TextStyle(
                                                          fontSize: 12.0,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                          color:
                                                              Color(0xff444444),
                                                        ),
                                                      ),
                                                      SizedBox(height: 12),
                                                    ],
                                                  ),
                                                ),
                                                BlocBuilder<ProfileBloc,
                                                    ProfileState>(
                                                  buildWhen: (prev, curr) =>
                                                      curr is ProfileLoaded,
                                                  builder: (ctx, pstate) {
                                                    final count = (pstate
                                                            as ProfileLoaded)
                                                        .getBadgeForWorkspace(
                                                            state.workspaces![i]!
                                                                .id);
                                                    if (count > 0)
                                                      return Badge(
                                                        shape:
                                                            BadgeShape.square,
                                                        borderRadius:
                                                            BorderRadius.all(
                                                                Radius.circular(
                                                                    5)),
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                          horizontal: 5,
                                                          vertical: 2,
                                                        ),
                                                        badgeContent: Text(
                                                          '$count',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: Dim.tm2(),
                                                          ),
                                                        ),
                                                      );
                                                    else
                                                      return Container();
                                                  },
                                                )
                                              ],
                                            ),
                                          ),
                                        ))
                                : Center(child: CircularProgressIndicator());
                          },
                        ),
                      ),
                    if (!_companiesHidden)
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 15),
                          itemCount: _companies!.length,
                          itemBuilder: (ctx, i) => InkWell(
                            onTap: () {
                              BlocProvider.of<CompaniesBloc>(ctx)
                                  .add(ChangeSelectedCompany(_companies![i]!.id));
                              BlocProvider.of<ProfileBloc>(ctx)
                                  .add(UpdateBadges());
                              setState(() {
                                _companiesHidden = true;
                              });
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ImageAvatar(
                                  _companies![i]!.logo,
                                  width: 30,
                                  height: 30,
                                ),
                                SizedBox(width: 15),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(height: 12),
                                    Text(
                                      _companies![i]!.name!,
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xff444444),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    if (_companies![i]!.totalMembers != null)
                                      Text(
                                        '${_companies![i]!.totalMembers} members',
                                        style: TextStyle(
                                          fontSize: 12.0,
                                          fontWeight: FontWeight.w400,
                                          color: Color(0xff444444),
                                        ),
                                      ),
                                    SizedBox(height: 12),
                                  ],
                                ),
                                Spacer(),
                                BlocBuilder<ProfileBloc, ProfileState>(
                                  buildWhen: (prev, curr) =>
                                      curr is ProfileLoaded,
                                  builder: (ctx, pstate) {
                                    final count = (pstate as ProfileLoaded)
                                        .getBadgeForCompany(_companies![i]!.id);
                                    if (count > 0)
                                      return Badge(
                                        shape: BadgeShape.square,
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(5)),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        badgeContent: Text(
                                          '$count',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: Dim.tm2(),
                                          ),
                                        ),
                                      );
                                    else
                                      return Container();
                                  },
                                )
                              ],
                            ),
                          ),
                        ),
                      ),
                    Divider(
                      thickness: 2.0,
                      height: 2.0,
                      color: Color(0xffEEEEEE),
                    ),
                    BlocBuilder<ProfileBloc, ProfileState>(
                      builder: (ctx, state) => state is ProfileLoaded
                          ? GestureDetector(
                              onTap: () => openSettings(context),
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                height: 52,
                                padding: EdgeInsets.symmetric(horizontal: 15.0),
                                child: Row(
                                  children: [
                                    ImageAvatar(
                                      state.thumbnail,
                                      width: 30,
                                      height: 30,
                                    ),
                                    SizedBox(width: 15),
                                    Text(
                                      '${state.firstName} ${state.lastName}',
                                      style: TextStyle(
                                        fontSize: 16.0,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xff444444),
                                      ),
                                    ),
                                    Spacer(),
                                    InkWell(
                                      onTap: () => _handleLogout(context),
                                      child: Icon(
                                        Icons.logout,
                                        color: Color(0xff444444),
                                        size: 30,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Center(child: CircularProgressIndicator()),
                    ),
                  ],
                );
              }),
        ),
      ),
    );
  }

  void _handleLogout(BuildContext parentContext) async {
    showDialog(
      context: parentContext,
      builder: (BuildContext context) {
        return WarningDialog(
          title: 'Are you sure you want to log out of your account?',
          leadingActionTitle: 'Cancel',
          trailingActionTitle: 'Log out',
          trailingAction: () async {
            BlocProvider.of<AuthBloc>(parentContext).add(ResetAuthentication());
            Navigator.of(context).pop();
          },
        );
      },
    );
  }
}
