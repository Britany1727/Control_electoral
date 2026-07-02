import 'package:equatable/equatable.dart';

sealed class RecoveryState extends Equatable {
  const RecoveryState();

  @override
  List<Object?> get props => [];
}

class RecoveryInitial extends RecoveryState {
  const RecoveryInitial();
}

class RecoveryLoading extends RecoveryState {
  const RecoveryLoading();
}

class RecoveryEmailSent extends RecoveryState {
  const RecoveryEmailSent();
}

class RecoverySuccess extends RecoveryState {
  const RecoverySuccess();
}

class RecoveryFailure extends RecoveryState {
  final String message;

  const RecoveryFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
