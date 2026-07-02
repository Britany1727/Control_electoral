import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/veedor_repository.dart';

class GetVotosPorActaUseCase
    implements UseCase<Map<String, int>, GetVotosPorActaParams> {
  final VeedorRepository repository;

  GetVotosPorActaUseCase(this.repository);

  @override
  Future<Either<Failure, Map<String, int>>> call(GetVotosPorActaParams params) {
    return repository.getVotosPorActa(params.actaId);
  }
}

class GetVotosPorActaParams extends Equatable {
  final String actaId;

  const GetVotosPorActaParams({required this.actaId});

  @override
  List<Object?> get props => [actaId];
}
