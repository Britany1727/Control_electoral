import 'package:equatable/equatable.dart';

sealed class ProvincialEvent extends Equatable {
  const ProvincialEvent();

  @override
  List<Object?> get props => [];
}

class LoadRecintos extends ProvincialEvent {
  const LoadRecintos();
}

class CreateRecinto extends ProvincialEvent {
  final String canton;
  final String parroquia;
  final String nombre;
  final String? numeroJrv;

  const CreateRecinto({
    required this.canton,
    required this.parroquia,
    required this.nombre,
    this.numeroJrv,
  });

  @override
  List<Object?> get props => [canton, parroquia, nombre, numeroJrv];
}

class CreateCoordinadorRecinto extends ProvincialEvent {
  final String recintoId;
  final String cedula;
  final String nombres;
  final String apellidos;
  final String telefono;
  final String correo;
  final String creadoPor;
  final String password;

  const CreateCoordinadorRecinto({
    required this.recintoId,
    required this.cedula,
    required this.nombres,
    required this.apellidos,
    required this.telefono,
    required this.correo,
    required this.creadoPor,
    this.password = 'Ecuador2026',
  });

  @override
  List<Object?> get props => [
        recintoId,
        cedula,
        nombres,
        apellidos,
        telefono,
        correo,
        creadoPor,
        password,
      ];
}

class LoadAvanceRecinto extends ProvincialEvent {
  final String recintoId;

  const LoadAvanceRecinto({required this.recintoId});

  @override
  List<Object?> get props => [recintoId];
}

class LoadRecintosSinCoordinador extends ProvincialEvent {
  const LoadRecintosSinCoordinador();
}

class LoadVotosConsolidados extends ProvincialEvent {
  final String? recintoId;

  const LoadVotosConsolidados({this.recintoId});

  @override
  List<Object?> get props => [recintoId];
}

class LoadActasPorRecinto extends ProvincialEvent {
  final String recintoId;

  const LoadActasPorRecinto({required this.recintoId});

  @override
  List<Object?> get props => [recintoId];
}

class LoadResumenGlobal extends ProvincialEvent {
  const LoadResumenGlobal();

  @override
  List<Object?> get props => [];
}

class LoadDetalleActa extends ProvincialEvent {
  final String actaId;
  final String mesaId;

  const LoadDetalleActa({
    required this.actaId,
    required this.mesaId,
  });

  @override
  List<Object?> get props => [actaId, mesaId];
}
