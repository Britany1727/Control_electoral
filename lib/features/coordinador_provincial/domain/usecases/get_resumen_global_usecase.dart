import 'package:dartz/dartz.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/provincial_repository.dart';

class GetResumenGlobalUseCase
    implements UseCase<Map<String, dynamic>, NoParams> {
  final ProvincialRepository repository;

  GetResumenGlobalUseCase(this.repository);

  @override
  Future<Either<Failure, Map<String, dynamic>>> call(NoParams params) {
    return repository.getResumenGlobal();
  }
}
