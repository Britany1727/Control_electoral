import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

class ConfirmEmailVerificationUseCase
    implements UseCase<void, ConfirmEmailVerificationParams> {
  final AuthRepository repository;

  ConfirmEmailVerificationUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(ConfirmEmailVerificationParams params) {
    return repository.confirmEmailVerification(
      userId: params.userId,
      secret: params.secret,
    );
  }
}

class ConfirmEmailVerificationParams extends Equatable {
  final String userId;
  final String secret;

  const ConfirmEmailVerificationParams({
    required this.userId,
    required this.secret,
  });

  @override
  List<Object?> get props => [userId, secret];
}
