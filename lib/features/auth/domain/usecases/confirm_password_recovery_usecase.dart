import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

class ConfirmPasswordRecoveryUseCase
    implements UseCase<void, ConfirmPasswordRecoveryParams> {
  final AuthRepository repository;

  ConfirmPasswordRecoveryUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(ConfirmPasswordRecoveryParams params) {
    return repository.confirmPasswordRecovery(
      userId: params.userId,
      secret: params.secret,
      newPassword: params.newPassword,
    );
  }
}

class ConfirmPasswordRecoveryParams extends Equatable {
  final String userId;
  final String secret;
  final String newPassword;

  const ConfirmPasswordRecoveryParams({
    required this.userId,
    required this.secret,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [userId, secret, newPassword];
}
