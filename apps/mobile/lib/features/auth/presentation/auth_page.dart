import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/network/json_data.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/common.dart';
import '../data/auth_link.dart';

enum AuthMode { login, forgot, reset, invite }

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key, this.mode = AuthMode.login, this.token = ''});
  final AuthMode mode;
  final String token;
  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _link = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  AppError? _error;
  String _message = '';
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final mode = widget.mode;
      if (mode == AuthMode.login) {
        await ref
            .read(authProvider.notifier)
            .login(_email.text, _password.text);
        _password.clear();
        if (mounted) context.go('/dashboard');
      } else {
        final path = mode == AuthMode.forgot
            ? '/auth/forgot-password'
            : mode == AuthMode.reset
            ? '/auth/reset-password'
            : '/auth/accept-invitation';
        final payload = <String, Object?>{};
        if (mode == AuthMode.forgot) {
          payload['email'] = _email.text.trim().toLowerCase();
        } else {
          payload['token'] = tokenFromLink(
            widget.token.isNotEmpty ? widget.token : _link.text,
            ref.read(configProvider),
            mode == AuthMode.reset ? '/reset-password' : '/accept-invitation',
          );
          payload['password'] = _password.text;
          if (mode == AuthMode.invite) payload['name'] = _name.text.trim();
        }
        final result = RecordData(
          await ref.read(apiProvider).authPost(path, payload),
        ).validate(strings: ['message']);
        if (!mounted) return;
        setState(() => _message = result.s('message'));
        _password.clear();
        _link.clear();
      }
    } catch (error) {
      if (mounted) setState(() => _error = AppError.from(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final title = switch (mode) {
      AuthMode.login => 'Selamat datang kembali.',
      AuthMode.forgot => 'Pulihkan akses akun.',
      AuthMode.reset => 'Kata sandi baru.',
      AuthMode.invite => 'Bergabung sebagai Admin.',
    };
    final form = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AKSES PENGELOLA',
                  style: TextStyle(
                    fontSize: 10,
                    color: Tokens.muted,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 12),
                Text(
                  mode == AuthMode.login
                      ? 'Masuk menggunakan akun yang telah dibuat pengelola.'
                      : mode == AuthMode.forgot
                      ? 'Masukkan email akun untuk menerima tautan pengaturan ulang.'
                      : 'Gunakan minimal 12 karakter untuk kata sandi Anda.',
                ),
                const SizedBox(height: 24),
                if (_message.isNotEmpty)
                  Notice(
                    _message,
                    action: TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Ke halaman masuk →'),
                    ),
                  )
                else
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (mode == AuthMode.invite) ...[
                          TextFormField(
                            controller: _name,
                            enabled: !_busy,
                            decoration: const InputDecoration(
                              labelText: 'Nama lengkap',
                            ),
                            maxLength: 200,
                            autofillHints: const [AutofillHints.name],
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Nama lengkap wajib diisi.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (mode == AuthMode.login ||
                            mode == AuthMode.forgot) ...[
                          TextFormField(
                            controller: _email,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              counterText: '',
                            ),
                            maxLength: 254,
                            validator: (v) =>
                                v == null ||
                                    !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch(v.trim())
                                ? 'Email tidak valid.'
                                : null,
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (mode != AuthMode.forgot) ...[
                          TextFormField(
                            controller: _password,
                            enabled: !_busy,
                            obscureText: _obscure,
                            autocorrect: false,
                            enableSuggestions: false,
                            maxLength: 128,
                            autofillHints: [
                              mode == AuthMode.login
                                  ? AutofillHints.password
                                  : AutofillHints.newPassword,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Kata sandi',
                              counterText: '',
                              suffixIcon: IconButton(
                                tooltip: _obscure
                                    ? 'Tampilkan kata sandi'
                                    : 'Sembunyikan kata sandi',
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (v) =>
                                v == null ||
                                    v.length < (mode == AuthMode.login ? 1 : 12)
                                ? mode == AuthMode.login
                                      ? 'Kata sandi wajib diisi.'
                                      : 'Kata sandi minimal 12 karakter.'
                                : null,
                          ),
                          const SizedBox(height: 18),
                        ],
                        if ((mode == AuthMode.invite ||
                                mode == AuthMode.reset) &&
                            widget.token.isEmpty) ...[
                          const Notice(
                            'Tautan tidak lengkap. Gunakan tautan dari email pengelola.',
                          ),
                          TextFormField(
                            controller: _link,
                            enabled: !_busy,
                            autocorrect: false,
                            enableSuggestions: false,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'Tempel tautan dari email',
                            ),
                            validator: (v) {
                              try {
                                tokenFromLink(
                                  v ?? '',
                                  ref.read(configProvider),
                                  mode == AuthMode.reset
                                      ? '/reset-password'
                                      : '/accept-invitation',
                                );
                                return null;
                              } on FormatException catch (error) {
                                return error.message;
                              }
                            },
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (_error != null) ErrorNotice(_error!),
                        if (mode == AuthMode.login &&
                            ref.watch(authProvider).error != null)
                          ErrorNotice(ref.watch(authProvider).error!),
                        ElevatedButton(
                          onPressed: _busy ? null : _submit,
                          child: Text(
                            _busy
                                ? 'Memproses…'
                                : switch (mode) {
                                    AuthMode.login => 'Masuk →',
                                    AuthMode.forgot => 'Kirim tautan →',
                                    AuthMode.reset => 'Perbarui kata sandi →',
                                    AuthMode.invite => 'Aktifkan akun →',
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => context.go(
                          mode == AuthMode.login
                              ? '/forgot-password'
                              : '/login',
                        ),
                  child: Text(
                    mode == AuthMode.login
                        ? 'Lupa kata sandi?'
                        : 'Kembali ke halaman masuk',
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  'Akses akun dikelola oleh pengelola kelompok tani. Belum punya akses? Hubungi pengelola kelompok tani.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: c.maxWidth >= 900
                  ? IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              color: Tokens.pale,
                              padding: const EdgeInsets.all(48),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Brand(),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('RUANG KERJA KELOMPOK TANI'),
                                      const SizedBox(height: 20),
                                      Text(
                                        'Catatan yang rapi.\nLangkah yang pasti.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineLarge,
                                      ),
                                      const SizedBox(height: 20),
                                      const Text(
                                        'Dari panen hingga penjualan, kelola pekerjaan bersama dalam satu tempat.',
                                      ),
                                    ],
                                  ),
                                  const Text('Kelompok Tani Podokoyo'),
                                ],
                              ),
                            ),
                          ),
                          Expanded(child: form),
                        ],
                      ),
                    )
                                    : IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Brand(),
                          ),
                          Expanded(
                            child: form,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
