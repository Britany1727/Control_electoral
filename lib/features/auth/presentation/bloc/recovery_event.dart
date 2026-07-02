import 'package:equatable/equatable.dart';

sealed class RecoveryEvent extends Equatable {
  const RecoveryEvent();

  @override
  List<Object?> get props => [];
}

class SendRecoveryRequested extends RecoveryEvent {
  final String email;

  const SendRecoveryRequested({required this.email});

  @override
  List<Object?> get props => [email];
}

class ConfirmRecoveryRequested extends RecoveryEvent {
  final String userId;
  final String secret;
  final String newPassword;

  const ConfirmRecoveryRequested({
    required this.userId,
    required this.secret,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [userId, secret, newPassword];
}

class ResetRecoveryState extends RecoveryEvent {
  const ResetRecoveryState();
}
