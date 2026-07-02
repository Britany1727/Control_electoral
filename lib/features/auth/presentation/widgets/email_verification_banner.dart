import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/usuario.dart';
import '../bloc/verification/verification_bloc.dart';
import '../bloc/verification/verification_event.dart';
import '../bloc/verification/verification_state.dart';

class EmailVerificationBanner extends StatelessWidget {
  final Usuario usuario;

  const EmailVerificationBanner({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    if (usuario.emailVerificado) return const SizedBox.shrink();

    return BlocListener<VerificationBloc, VerificationState>(
      listener: (context, state) {
        if (state is VerificationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
        if (state is VerificationEmailSent) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Correo de verificación enviado. Revisa tu bandeja de entrada.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      child: BlocBuilder<VerificationBloc, VerificationState>(
        builder: (context, state) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.orange.shade100,
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Correo no verificado',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                        ),
                      ),
                      const Text(
                        'Verifica tu correo electrónico para acceder a todas las funcionalidades.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: state is VerificationLoading
                      ? null
                      : () => context.read<VerificationBloc>().add(
                            const SendVerificationRequested(),
                          ),
                  child: state is VerificationLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reenviar'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
