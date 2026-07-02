import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/usecases/send_password_recovery_usecase.dart';
import '../../domain/usecases/confirm_password_recovery_usecase.dart';
import 'recovery_event.dart';
import 'recovery_state.dart';

class RecoveryBloc extends Bloc<RecoveryEvent, RecoveryState> {
  final SendPasswordRecoveryUseCase sendPasswordRecoveryUseCase;
  final ConfirmPasswordRecoveryUseCase confirmPasswordRecoveryUseCase;

  RecoveryBloc({
    required this.sendPasswordRecoveryUseCase,
    required this.confirmPasswordRecoveryUseCase,
  }) : super(const RecoveryInitial()) {
    on<SendRecoveryRequested>(_onSendRecovery);
    on<ConfirmRecoveryRequested>(_onConfirmRecovery);
    on<ResetRecoveryState>(_onResetRecoveryState);
  }

  Future<void> _onSendRecovery(
    SendRecoveryRequested event,
    Emitter<RecoveryState> emit,
  ) async {
    emit(const RecoveryLoading());
    final result = await sendPasswordRecoveryUseCase(
      SendPasswordRecoveryParams(email: event.email),
    );
    result.fold(
      (failure) => emit(RecoveryFailure(message: failure.message)),
      (_) => emit(const RecoveryEmailSent()),
    );
  }

  Future<void> _onConfirmRecovery(
    ConfirmRecoveryRequested event,
    Emitter<RecoveryState> emit,
  ) async {
    emit(const RecoveryLoading());
    final result = await confirmPasswordRecoveryUseCase(
      ConfirmPasswordRecoveryParams(
        userId: event.userId,
        secret: event.secret,
        newPassword: event.newPassword,
      ),
    );
    result.fold(
      (failure) => emit(RecoveryFailure(message: failure.message)),
      (_) => emit(const RecoverySuccess()),
    );
  }

  void _onResetRecoveryState(
    ResetRecoveryState event,
    Emitter<RecoveryState> emit,
  ) {
    emit(const RecoveryInitial());
  }
}
