import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/provincial_repository.dart';

class DeleteRecintoUseCase
    implements UseCase<Null, DeleteRecintoParams> {
  final ProvincialRepository repository;

  DeleteRecintoUseCase(this.repository);

  @override
  Future<Either<Failure, Null>> call(DeleteRecintoParams params) {
    return repository.deleteRecinto(params.recintoId);
  }
}

class DeleteRecintoParams extends Equatable {
  final String recintoId;

  const DeleteRecintoParams({required this.recintoId});

  @override
  List<Object?> get props => [recintoId];
}
