import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../domain/usecases/confirm_email_verification_usecase.dart';
import '../../../domain/usecases/send_email_verification_usecase.dart';
import 'verification_event.dart';
import 'verification_state.dart';

class VerificationBloc extends Bloc<VerificationEvent, VerificationState> {
  final SendEmailVerificationUseCase sendEmailVerificationUseCase;
  final ConfirmEmailVerificationUseCase confirmEmailVerificationUseCase;

  VerificationBloc({
    required this.sendEmailVerificationUseCase,
    required this.confirmEmailVerificationUseCase,
  }) : super(const VerificationInitial()) {
    on<SendVerificationRequested>(_onSendVerification);
    on<ConfirmVerificationRequested>(_onConfirmVerification);
    on<ResetVerificationState>(_onReset);
  }

  Future<void> _onSendVerification(
    SendVerificationRequested event,
    Emitter<VerificationState> emit,
  ) async {
    emit(const VerificationLoading());
    final result = await sendEmailVerificationUseCase(const NoParams());
    result.fold(
      (failure) => emit(VerificationFailure(message: failure.message)),
      (_) => emit(const VerificationEmailSent()),
    );
  }

  Future<void> _onConfirmVerification(
    ConfirmVerificationRequested event,
    Emitter<VerificationState> emit,
  ) async {
    emit(const VerificationLoading());
    final result = await confirmEmailVerificationUseCase(
      ConfirmEmailVerificationParams(
        userId: event.userId,
        secret: event.secret,
      ),
    );
    result.fold(
      (failure) => emit(VerificationFailure(message: failure.message)),
      (_) => emit(const VerificationSuccess()),
    );
  }

  void _onReset(
    ResetVerificationState event,
    Emitter<VerificationState> emit,
  ) {
    emit(const VerificationInitial());
  }
}
