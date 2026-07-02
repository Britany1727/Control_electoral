import 'package:dartz/dartz.dart';
import '../../../../core/constants/appwrite_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/usuario.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/create_user_usecase.dart';
import '../../domain/usecases/login_usecase.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource remoteDatasource;

  AuthRepositoryImpl(this.remoteDatasource);

  @override
  Future<Either<Failure, Usuario>> login(LoginParams params) async {
    try {
      final usuario = await remoteDatasource.login(
        params.cedula,
        params.email,
        params.password,
      );
      return Right(usuario);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(AuthFailure('Error inesperado: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Usuario>> createUser(CreateUserParams params) async {
    try {
      final usuario = await remoteDatasource.createUser(
        cedula: params.cedula,
        nombres: params.nombres,
        apellidos: params.apellidos,
        telefono: params.telefono,
        correo: params.correo,
        rol: params.rol,
        creadoPor: params.creadoPor,
        recintoId: params.recintoId,
      );
      return Right(usuario);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Null>> logout() async {
    try {
      await remoteDatasource.logout();
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Usuario>> getCurrentUser() async {
    try {
      final usuario = await remoteDatasource.getCurrentUser();
      return Right(usuario);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Null>> changePassword(
      String currentPassword, String newPassword) async {
    try {
      await remoteDatasource.changePassword(currentPassword, newPassword);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Null>> recoverPassword(String email) async {
    try {
      await remoteDatasource.recoverPassword(email);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, String>> requestPasswordReset(String cedula) async {
    try {
      final email = await remoteDatasource.requestPasswordReset(
        cedula,
        '${AppwriteConstants.recoveryBaseUrl}/reset-password',
      );
      return Right(email);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Null>> completePasswordReset(
      String userId, String secret, String newPassword) async {
    try {
      await remoteDatasource.completePasswordReset(
          userId, secret, newPassword);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> sendEmailVerification() async {
    try {
      await remoteDatasource.sendEmailVerification();
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Error inesperado: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> confirmEmailVerification({
    required String userId,
    required String secret,
  }) async {
    try {
      await remoteDatasource.confirmEmailVerification(userId, secret);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Error inesperado: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> sendPasswordRecovery({
    required String email,
  }) async {
    try {
      await remoteDatasource.sendPasswordRecovery(email);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Error inesperado: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> confirmPasswordRecovery({
    required String userId,
    required String secret,
    required String newPassword,
  }) async {
    try {
      await remoteDatasource.confirmPasswordRecovery(
          userId, secret, newPassword);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Error inesperado: ${e.toString()}'));
    }
  }
}
