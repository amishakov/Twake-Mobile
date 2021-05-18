import 'package:flutter/cupertino.dart';
import 'package:meta/meta.dart';
import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:twake/blocs/add_channel_bloc/add_channel_bloc.dart';
import 'package:twake/blocs/add_channel_bloc/add_channel_state.dart';
import 'package:twake/blocs/edit_channel_cubit/edit_channel_cubit.dart';
import 'package:twake/blocs/edit_channel_cubit/edit_channel_state.dart';
import 'package:twake/blocs/member_cubit/member_cubit.dart';
import 'package:twake/blocs/sheet_bloc/sheet_bloc.dart';
import 'package:twake/blocs/channels_bloc/channels_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:twake/models/channel.dart';
import 'package:twake/models/member.dart';
import 'package:twake/repositories/edit_channel_repository.dart';
import 'package:twake/utils/extensions.dart';
import 'package:twake/repositories/sheet_repository.dart';
import 'package:twake/widgets/common/cupertino_warning.dart';
import 'package:twake/widgets/common/rich_text_span.dart';
import 'package:twake/widgets/common/selectable_avatar.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:twake/widgets/common/button_field.dart';
import 'package:twake/widgets/sheets/draggable_scrollable.dart';
import 'package:twake/widgets/sheets/hint_line.dart';
import 'package:twake/widgets/sheets/sheet_text_field.dart';
import 'package:flutter_emoji_keyboard/flutter_emoji_keyboard.dart';

class EditChannel extends StatefulWidget {
  final Channel? channel;
  final List<Member>? members;

  const EditChannel({Key? key, this.channel, this.members}) : super(key: key);

  @override
  _EditChannelState createState() => _EditChannelState();
}

class _EditChannelState extends State<EditChannel> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  final _nameFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();

  final PanelController _panelController = PanelController();

  List<Member>? _members = <Member>[];
  var _canSave = false;
  var _emojiVisible = false;
  var _canDelete = false;

  Channel? _channel;
  String? _channelId;
  String? _icon;
  String? _channelName;
  String? _channelDescription;

  List<String?>? _participants = [];

  @override
  void initState() {
    super.initState();

    if (widget.channel != null) {
      _channel = widget.channel;
      _channelId = widget.channel!.id;
      _nameController.text = _channel!.name!;
      _channelName = _channel!.name;
      _descriptionController.text = _channel!.description!;
      _channelDescription = _channel!.description;
      _icon = _channel!.icon ?? '';
      _batchUpdateState(channelId: _channelId);
    }

    if (widget.members != null) {
      _members = widget.members;
    }

    _nameController.addListener(() {
      final channelName = _nameController.text;
      _batchUpdateState(name: channelName);
      if (channelName.isNotReallyEmpty &&
          !_canSave &&
          _channelName != channelName) {
        setState(() {
          _channelName = channelName;
          _canSave = true;
        });
      } else if (channelName.isReallyEmpty && _canSave) {
        setState(() {
          _canSave = false;
        });
      }
    });

    _descriptionController.addListener(() {
      final channelDescription = _descriptionController.text;
      _batchUpdateState(description: _descriptionController.text);
      if (_channelDescription != channelDescription) {
        setState(() {
          _canSave = true;
        });
      }
    });

    WidgetsBinding.instance!.addPostFrameCallback((_) {
      context.read<SheetBloc>().add(SetFlow(flow: SheetFlow.editChannel));
    });

    _nameFocusNode.addListener(() {
      if (_nameFocusNode.hasFocus) {
        _closeKeyboards(context, both: false);
      }
    });

    _descriptionFocusNode.addListener(() {
      if (_descriptionFocusNode.hasFocus) {
        _closeKeyboards(context, both: false);
      }
    });

    final permissions = _channel!.permissions!;
    _canDelete = permissions.contains('DELETE_CHANNEL');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _nameFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EditChannel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channel != widget.channel) {
      setState(() {
        _channel = widget.channel;
        _channelId = widget.channel!.id;
        _icon = widget.channel!.icon;
      });
    }
    if (oldWidget.members != widget.members) {
      setState(() {
        _members = widget.members;
      });
    }
  }

  void _batchUpdateState({
    String? channelId,
    String? icon,
    String? name,
    String? description,
  }) {
    context.read<EditChannelCubit>().update(
          channelId: channelId ?? _channelId,
          icon: icon ?? _icon,
          name: name ?? _nameController.text,
          description: description ?? _descriptionController.text,
        );
  }

  void _save() {
    context.read<EditChannelCubit>().save();
    if (_participants != null && _participants!.length > 0) {
      context
          .read<MemberCubit>()
          .addMembers(channelId: _channelId, members: _participants);
    }
  }

  void _delete(BuildContext channelContext) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoWarning(
          icon: _channel!.icon,
          title: <RichTextSpan>[
            RichTextSpan(
              text: 'Are you sure you want to delete\n',
              isBold: false,
            ),
            RichTextSpan(
              text: '${_channel!.name}',
              isBold: true,
            ),
            RichTextSpan(
              text: ' channel?',
              isBold: false,
            ),
          ],
          cancelTitle: 'Cancel',
          confirmTitle: 'Delete',
          confirmAction: () async {
            channelContext.read<EditChannelCubit>().delete();
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void _onPanelSlide(double position) {
    if (position < 0.4 && _panelController.isPanelAnimating) {
      FocusScope.of(context).requestFocus(FocusNode());
    }
  }

  void _openManagement(BuildContext context) {
    context.read<MemberCubit>().fetchMembers(channelId: _channelId);
    context.read<EditChannelCubit>().setFlowStage(EditFlowStage.manage);
    _panelController.open();
  }

  void _openAdd(BuildContext context) {
    context.read<EditChannelCubit>().setFlowStage(EditFlowStage.add);
    _panelController.open();
  }

  Future<void> _toggleEmojiBoard() async {
    FocusScope.of(context).requestFocus(FocusNode());
    await Future.delayed(Duration(milliseconds: 150));
    setState(() {
      _emojiVisible = !_emojiVisible;
    });
  }

  Widget _buildEmojiBoard() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: EmojiKeyboard(
        onEmojiSelected: (emoji) async {
          _canSave = true;
          _icon = emoji.text;
          _batchUpdateState(icon: _icon);
          await _toggleEmojiBoard();
        },
        height: MediaQuery.of(context).size.height * 0.35,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xffefeef3),
      resizeToAvoidBottomInset: false,
      body: SlidingUpPanel(
        controller: _panelController,
        onPanelOpened: () => context.read<SheetBloc>().add(SetOpened()),
        onPanelClosed: () => context.read<SheetBloc>().add(SetClosed()),
        onPanelSlide: _onPanelSlide,
        minHeight: 0,
        maxHeight: MediaQuery.of(context).size.height * 0.9,
        backdropEnabled: true,
        renderPanelSheet: false,
        panel: BlocConsumer<SheetBloc, SheetState>(
          listenWhen: (_, current) =>
              current is SheetShouldOpen || current is SheetShouldClose,
          listener: (context, state) {
            // print('Strange state: $state');
            _closeKeyboards(context);

            if (state is SheetShouldOpen) {
              if (_panelController.isPanelClosed) {
                _panelController.open();
              }
            } else if (state is SheetShouldClose) {
              if (_panelController.isPanelOpen) {
                _panelController.close();
              }
            }
          },
          buildWhen: (_, current) => current is FlowUpdated,
          builder: (context, state) {
            var sheetFlow = SheetFlow.editChannel;
            if (state is FlowUpdated) {
              sheetFlow = state.flow;
              return DraggableScrollable(flow: sheetFlow);
            } else {
              return SizedBox();
            }
          },
        ),
        body: SafeArea(
          bottom: false,
          child: BlocListener<AddChannelBloc, AddChannelState>(
            listener: (context ,state) {
              if (state is Updated) {
                _participants = state.repository?.members;
                if (_participants != null && _participants!.length > 0) {
                  setState(() {
                    _canSave = true;
                  });
                }
              }
            },
            child: BlocListener<EditChannelCubit, EditChannelState>(
                listenWhen: (_, current) =>
                current is EditChannelSaved || current is EditChannelDeleted,
                listener: (context, state) {
                  if (state is EditChannelSaved || state is EditChannelDeleted) {
                    context
                        .read<ChannelsBloc>()
                        .add(ReloadChannels(forceFromApi: true));
                    Navigator.of(context).pop([state]);
                  }
                },
                child: Column(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _closeKeyboards(context),
                        behavior: HitTestBehavior.opaque,
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(16.0, 17.0, 16.0, 20.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (_emojiVisible) {
                                          setState(() {
                                            _emojiVisible = false;
                                          });
                                        } else {
                                          Navigator.of(context).pop();
                                        }
                                      },
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: Color(0xff3840f7),
                                          fontSize: 17.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        SelectableAvatar(
                                          size: 74.0,
                                          icon: _icon,
                                          onTap: () => _toggleEmojiBoard(),
                                        ),
                                        SizedBox(height: 4.0),
                                        GestureDetector(
                                          onTap: () => _toggleEmojiBoard(),
                                          child: Text('Change avatar',
                                              style: TextStyle(
                                                color: Color(0xff3840f7),
                                                fontSize: 13.0,
                                                fontWeight: FontWeight.w400,
                                              )),
                                        ),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: _canSave ? () => _save() : null,
                                      child: Text(
                                        'Save',
                                        style: TextStyle(
                                          color: _canSave
                                              ? Color(0xff3840f7)
                                              : Color(0xffa2a2a2),
                                          fontSize: 17.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  RoundedBoxButton(
                                    cover: Image.asset('assets/images/add_new_member.png'),
                                    title: 'add',
                                    onTap: () => _openAdd(context),
                                  ),
                                  SizedBox(width: _canDelete ? 10.0 : 0.0),
                                  if (_canDelete)
                                    RoundedBoxButton(
                                      cover: Image.asset('assets/images/delete.png'),
                                      title: 'delete',
                                      color: Color(0xfff04820),
                                      onTap: () => _delete(context),
                                    ),
                                ],
                              ),
                              SizedBox(height: 24.0),
                              HintLine(text: 'CHANNEL INFORMATION', isLarge: true),
                              SizedBox(height: 12.0),
                              Divider(
                                thickness: 0.5,
                                height: 0.5,
                                color: Colors.black.withOpacity(0.2),
                              ),
                              SheetTextField(
                                hint: 'Channel name',
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                maxLength: 30,
                              ),
                              Divider(
                                thickness: 0.5,
                                height: 0.5,
                                color: Colors.black.withOpacity(0.2),
                              ),
                              SheetTextField(
                                hint: 'Description',
                                controller: _descriptionController,
                                focusNode: _descriptionFocusNode,
                              ),
                              Divider(
                                thickness: 0.5,
                                height: 0.5,
                                color: Colors.black.withOpacity(0.2),
                              ),
                              // ButtonField(
                              //   title: 'Channel type',
                              //   trailingTitle: 'Public',
                              //   hasArrow: true,
                              // ),
                              SizedBox(height: 32.0),
                              HintLine(text: 'MEMBERS', isLarge: true),
                              SizedBox(height: 12.0),
                              Divider(
                                thickness: 0.5,
                                height: 0.5,
                                color: Colors.black.withOpacity(0.2),
                              ),
                              ButtonField(
                                title: 'Member management',
                                trailingTitle: 'Manage',
                                hasArrow: true,
                                onTap: () => _openManagement(context),
                              ),
                              Divider(
                                thickness: 0.5,
                                height: 0.5,
                                color: Colors.black.withOpacity(0.2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _emojiVisible ? _buildEmojiBoard() : Container(),
                  ],
                ),
              ),
          ),
        ),
      ),
    );
  }

  void _closeKeyboards(BuildContext context, {bool both = true}) {
    if (both) {
      FocusScope.of(context).requestFocus(FocusNode());
    }
    if (_emojiVisible) {
      setState(() {
        _emojiVisible = false;
      });
    }
  }
}

class RoundedBoxButton extends StatelessWidget {
  final Widget cover;
  final String title;
  final Color? color;
  final Function onTap;

  const RoundedBoxButton({
    Key? key,
    required this.cover,
    required this.title,
    required this.onTap,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap?.call(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.fromLTRB(18.0, 13.0, 18.0, 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
        ),
        child: SizedBox(
          width: 45.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              cover,
              SizedBox(height: 5.0),
              AutoSizeText(
                title,
                minFontSize: 10.0,
                maxFontSize: 13.0,
                maxLines: 1,
                style: TextStyle(
                  color: color ?? Color(0xff3840f7),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
