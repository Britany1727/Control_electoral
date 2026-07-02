import 'package:equatable/equatable.dart';

sealed class VerificationEvent extends Equatable {
  const VerificationEvent();

  @override
  List<Object?> get props => [];
}

class SendVerificationRequested extends VerificationEvent {
  const SendVerificationRequested();

  @override
  List<Object?> get props => [];
}

class ConfirmVerificationRequested extends VerificationEvent {
  final String userId;
  final String secret;

  const ConfirmVerificationRequested({
    required this.userId,
    required this.secret,
  });

  @override
  List<Object?> get props => [userId, secret];
}

class ResetVerificationState extends VerificationEvent {
  const ResetVerificationState();
}
