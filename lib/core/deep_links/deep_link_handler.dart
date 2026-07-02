import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/bloc/verification/verification_bloc.dart';
import '../../features/auth/presentation/bloc/verification/verification_event.dart';

class DeepLinkHandler {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  void init(BuildContext context) {
    _appLinks.getInitialLink().then((Uri? initialUri) {
      if (initialUri != null) {
        _handleUri(context, initialUri);
      }
    });

    _subscription = _appLinks.uriLinkStream.listen((Uri uri) {
      _handleUri(context, uri);
    });
  }

  void _handleUri(BuildContext context, Uri uri) {
    debugPrint('[DEEP_LINK] URI recibido: $uri');

    final path = uri.host.isNotEmpty ? uri.host : uri.path.replaceFirst('/', '');
    final userId = uri.queryParameters['userId'];
    final secret = uri.queryParameters['secret'];

    if (userId == null || secret == null) {
      debugPrint('[DEEP_LINK] Faltan parámetros userId o secret');
      return;
    }

    if (path == 'verify' || path == 'verificar') {
      debugPrint('[DEEP_LINK] Verificación de correo detectada');
      context.read<VerificationBloc>().add(
            ConfirmVerificationRequested(
              userId: userId,
              secret: secret,
            ),
          );
    } else if (path == 'recovery' || path == 'reset-password') {
      debugPrint('[DEEP_LINK] Recuperación de contraseña detectada');
      context.go(
        '/reset-password?userId=$userId&secret=$secret',
      );
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}
