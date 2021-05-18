import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:twake/blocs/auth_bloc/auth_bloc.dart';
import 'package:twake/blocs/connection_bloc/connection_bloc.dart' as cb;
import 'package:twake/config/styles_config.dart';
import 'package:twake/config/dimensions_config.dart' show Dim;
// import 'package:twake/utils/navigation.dart';

class AuthForm extends StatefulWidget {
  final Function? onConfigurationOpen;

  const AuthForm({Key? key, this.onConfigurationOpen}) : super(key: key);

  @override
  _AuthFormState createState() => _AuthFormState();
}

class _AuthFormState extends State<AuthForm> {
  String _username = '';
  String _password = '';
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  final GlobalKey<FormState> formKey = GlobalKey();

  /// Closure to store the username from form field
  void onUsernameSaved() {
    _username = _usernameController.text;
    // triggering ui rebuild
    setState(() {});
  }

  /// Closure to store the password from form field
  void onPasswordSaved() {
    _password = _passwordController.text;
    // triggering ui rebuild
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(onUsernameSaved);
    _passwordController.addListener(onPasswordSaved);
    final AuthState state = BlocProvider.of<AuthBloc>(context).state;
    if (state is Unauthenticated) {
      _usernameController.text = state.username!;
      _passwordController.text = state.password!;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  String? validateUsername(String value) {
    if (value.isEmpty) {
      return 'Username cannot be empty';
    }
    return null;
  }

  String? validatePassword(String value) {
    if (value.isEmpty) {
      return 'Password cannot be empty';
    }
    return null;
  }

  void onSubmit() {
    BlocProvider.of<AuthBloc>(context).add(
      Authenticate(
        _username,
        _password,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        width: Dim.widthPercent(87),
        height: Dim.heightPercent(67),
        child: Padding(
          padding: EdgeInsets.only(
            left: Dim.wm4,
            right: Dim.wm4,
            top: Dim.hm3,
            bottom: Dim.hm2,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.fitWidth,
                  child: Text(
                    'Let\'s get started!',
                    style: Theme.of(context).textTheme.headline1,
                  ),
                ),
                SizedBox(height: Dim.heightMultiplier),
                Center(
                  child: Text(
                    'Sign in to continue',
                    style: Theme.of(context).textTheme.headline4,
                  ),
                ),
                Spacer(),
                _AuthTextForm(
                  label: 'Email',
                  validator: validateUsername,
                  // onSaved: onUsernameSaved,
                  controller: _usernameController,
                  focusNode: _usernameFocusNode,
                ),
                SizedBox(height: Dim.hm3),
                _AuthTextForm(
                  label: 'Password',
                  obscured: true,
                  validator: validatePassword,
                  // onSaved: onPasswordSaved,
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                ),
                SizedBox(height: Dim.heightMultiplier),
                BlocBuilder<AuthBloc, AuthState>(
                  buildWhen: (_, current) =>
                      current is WrongCredentials ||
                      current is AuthenticationError,
                  builder: (ctx, state) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (state is WrongCredentials)
                          Text(
                            'Incorrect email or password',
                            style: TextStyle(color: Colors.red, fontSize: 13.0),
                          ),
                        if (state is AuthenticationError)
                          Text(
                            'Server is unavailable',
                            style: TextStyle(color: Colors.red, fontSize: 13.0),
                          ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: BlocBuilder<cb.ConnectionBloc,
                                cb.ConnectionState>(
                              builder: (context, state) => TextButton(
                                onPressed: state is cb.ConnectionLost
                                    ? null
                                    : () {
                                        context
                                            .read<AuthBloc>()
                                            .add(ResetPassword());
                                      },
                                child: Text(
                                  'Forgot password?',
                                  style: state is cb.ConnectionLost
                                      ? StylesConfig.disabled
                                      : StylesConfig.miniPurple,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: BlocBuilder<cb.ConnectionBloc, cb.ConnectionState>(
                    builder: (context, state) => RaisedButton(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: Dim.wm4,
                        vertical: Dim.tm2(decimal: -.2),
                      ),
                      color: Theme.of(context).accentColor,
                      textColor: Colors.white,
                      disabledColor: Color.fromRGBO(238, 238, 238, 1),
                      child: Text(
                        'Login',
                        style: Theme.of(context).textTheme.button,
                      ),
                      onPressed: _username.isNotEmpty &&
                              _password.isNotEmpty &&
                              !(state is cb.ConnectionLost)
                          ? () => onSubmit()
                          : null,
                    ),
                  ),
                ),
                Spacer(),
                Align(
                  alignment: Alignment.center,
                  child: FittedBox(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: widget.onConfigurationOpen as void Function()?,
                          //() => openChooseServer(context),
                          behavior: HitTestBehavior.opaque,
                          child: Text(
                            'Choose the server',
                            style: StylesConfig.miniPurple,
                          ),
                        ),
                        SizedBox(height: 30),
                        Row(
                          children: [
                            Text(
                              'Don\'t have an account? ',
                              style: StylesConfig.miniPurple
                                  .copyWith(color: Colors.black87),
                            ),
                            BlocBuilder<cb.ConnectionBloc, cb.ConnectionState>(
                              builder: (context, state) => FlatButton(
                                onPressed: state is cb.ConnectionLost
                                    ? null
                                    : () {
                                        context
                                            .read<AuthBloc>()
                                            .add(RegistrationInit());
                                      },
                                child: Text(
                                  ' Sign up',
                                  style: state is cb.ConnectionLost
                                      ? StylesConfig.disabled
                                      : StylesConfig.miniPurple,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTextForm extends StatefulWidget {
  final String label;
  final bool obscured;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String? Function(String?)? validator;

  const _AuthTextForm({
    required this.label,
    required this.controller,
    required this.focusNode,
    this.validator,
    this.obscured: false,
  });

  @override
  __AuthTextFormState createState() => __AuthTextFormState();
}

class __AuthTextFormState extends State<_AuthTextForm> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      autocorrect: widget.obscured ? false : true,
      enableSuggestions: widget.obscured ? false : true,
      // style: TextStyle(fontSize: Dim.tm2(decimal: 0.2)),
      obscureText: widget.obscured ? _obscured : false,
      validator: widget.validator,
      controller: widget.controller,
      focusNode: widget.focusNode,
      keyboardType: widget.obscured
          ? TextInputType.visiblePassword
          : TextInputType.emailAddress,
      autofillHints: [
        AutofillHints.email,
        AutofillHints.password,
      ],
      style: Theme.of(context).textTheme.headline2,
      decoration: InputDecoration(
        fillColor: Color.fromRGBO(239, 239, 245, 1),
        filled: true,
        labelText: widget.label,
        labelStyle: TextStyle(fontSize: Dim.tm2(decimal: .1), height: 0.9),
        contentPadding: EdgeInsets.fromLTRB(
          Dim.wm3,
          Dim.heightMultiplier,
          Dim.wm3,
          Dim.heightMultiplier,
        ),
        suffixIcon: widget.obscured
            ? IconButton(
                icon: Icon(
                  Icons.remove_red_eye_outlined,
                  color: _obscured ? Colors.grey : Colors.blue,
                ),
                onPressed: () {
                  setState(() {
                    _obscured = !_obscured;
                  });
                })
            : null,
        border: UnderlineInputBorder(
          borderSide: BorderSide(
            width: 0.0,
            style: BorderStyle.none,
          ),
          borderRadius: BorderRadius.circular(7.0),
        ),
      ),
    );
  }
}
