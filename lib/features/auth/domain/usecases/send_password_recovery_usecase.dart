import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/auth_repository.dart';

class SendPasswordRecoveryUseCase
    implements UseCase<void, SendPasswordRecoveryParams> {
  final AuthRepository repository;

  SendPasswordRecoveryUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(SendPasswordRecoveryParams params) {
    return repository.sendPasswordRecovery(email: params.email);
  }
}

class SendPasswordRecoveryParams extends Equatable {
  final String email;

  const SendPasswordRecoveryParams({required this.email});

  @override
  List<Object?> get props => [email];
}
