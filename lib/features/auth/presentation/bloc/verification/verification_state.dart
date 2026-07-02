import 'package:equatable/equatable.dart';

sealed class VerificationState extends Equatable {
  const VerificationState();

  @override
  List<Object?> get props => [];
}

class VerificationInitial extends VerificationState {
  const VerificationInitial();
}

class VerificationLoading extends VerificationState {
  const VerificationLoading();
}

class VerificationEmailSent extends VerificationState {
  const VerificationEmailSent();
}

class VerificationSuccess extends VerificationState {
  const VerificationSuccess();
}

class VerificationFailure extends VerificationState {
  final String message;

  const VerificationFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
