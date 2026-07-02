import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../../../../core/constants/appwrite_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../features/veedor/data/models/acta_model.dart';
import '../../../../features/veedor/domain/entities/acta.dart';
import '../../domain/entities/detalle_acta_completo.dart';
import '../../domain/entities/votos_consolidados.dart';
import '../models/recinto_model.dart';

abstract class ProvincialRemoteDatasource {
  Future<List<RecintoModel>> getRecintos();
  Future<List<RecintoModel>> getRecintosSinCoordinador();
  Future<RecintoModel> createRecinto(
    String canton,
    String parroquia,
    String nombre,
    String? numeroJrv,
  );
  Future<void> createCoordinadorRecinto(
    String recintoId,
    String cedula,
    String nombres,
    String apellidos,
    String telefono,
    String correo,
    String creadoPor,
    String password,
  );
  Future<Map<String, int>> getAvanceRecinto(String recintoId);
  Future<Map<String, dynamic>> getResumenGlobal();
  Future<List<ActaModel>> getActasPorRecinto(String recintoId);
  Future<List<VotosConsolidados>> getVotosConsolidados(String? recintoId);
  Future<DetalleActaCompleto> getDetalleActa(String actaId, String mesaId);
  Future<void> deleteRecinto(String recintoId);
}

class ProvincialRemoteDatasourceImpl implements ProvincialRemoteDatasource {
  final Databases databases;
  final Account account;
  final Functions functions;

  ProvincialRemoteDatasourceImpl({
    required this.databases,
    required this.account,
    required this.functions,
  });

  @override
  Future<List<RecintoModel>> getRecintos() async {
    try {
      final documents = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.recintosCollectionId,
      );
      return documents.documents
          .map((doc) => RecintoModel.fromMap(doc.data, doc.$id))
          .toList();
    } on AppwriteException catch (e) {
      throw ServerException(e.message ?? 'Error al obtener recintos');
    }
  }

  @override
  Future<List<RecintoModel>> getRecintosSinCoordinador() async {
    try {
      final documents = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.recintosCollectionId,
        // FIX: el atributo real en Appwrite se llama 'coordinador_recinto_id',
        // no 'coordinador_id'
        queries: [Query.isNull('coordinador_recinto_id')],
      );
      return documents.documents
          .map((doc) => RecintoModel.fromMap(doc.data, doc.$id))
          .toList();
    } on AppwriteException catch (e) {
      throw ServerException(
        e.message ?? 'Error al obtener recintos sin coordinador',
      );
    }
  }

  @override
  Future<RecintoModel> createRecinto(
    String canton,
    String parroquia,
    String nombre,
    String? numeroJrv,
  ) async {
    try {
      final data = <String, dynamic>{
        'canton': canton,
        'parroquia': parroquia,
        'nombre': nombre,
      };

      int? totalMesas;
      if (numeroJrv != null && numeroJrv.trim().isNotEmpty) {
        totalMesas = int.tryParse(numeroJrv.trim());
        if (totalMesas == null) {
          throw ServerException(
            'Número JRV inválido: debe ser un valor numérico',
          );
        }
        data['numero_jrv'] = totalMesas;
      }

      final doc = await databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.recintosCollectionId,
        documentId: ID.unique(),
        data: data,
      );

      if (totalMesas != null && totalMesas > 0) {
        for (var i = 1; i <= totalMesas; i++) {
          await databases.createDocument(
            databaseId: AppwriteConstants.databaseId,
            collectionId: AppwriteConstants.mesasCollectionId,
            documentId: ID.unique(),
            data: {
              'numero_jrv': i.toString(),
              'recinto_id': doc.$id,
            },
          );
        }
      }

      return RecintoModel.fromMap(doc.data, doc.$id);
    } on AppwriteException catch (e) {
      throw ServerException(e.message ?? 'Error al crear recinto');
    }
  }

  @override
  Future<void> createCoordinadorRecinto(
    String recintoId,
    String cedula,
    String nombres,
    String apellidos,
    String telefono,
    String correo,
    String creadoPor,
    String password,
  ) async {
    try {
      final existingUsers = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.usuariosCollectionId,
        queries: [
          Query.or([
            Query.equal('cedula', cedula),
            Query.equal('correo', correo),
          ]),
        ],
      );
      if (existingUsers.documents.isNotEmpty) {
        final existing = existingUsers.documents.first.data;
        if (existing['cedula'] == cedula) {
          throw ServerException('Ya existe un usuario con la cédula $cedula');
        }
        throw ServerException('Ya existe un usuario con el correo $correo');
      }

      // ignore: avoid_print
      print('[DEBUG] Creando coordinador con correo="$correo" cedula="$cedula"');
      try {
        final currentSession = await account.getSession(sessionId: 'current');
        // ignore: avoid_print
        print('[DEBUG] Sesión activa detectada, userId=${currentSession.userId}');
      } catch (_) {
        // ignore: avoid_print
        print('[DEBUG] No hay sesión activa al momento de crear coordinador');
      }

      final execution = await functions.createExecution(
        functionId: AppwriteConstants.createUserFunctionId,
        body: jsonEncode({
          'email': correo,
          'password': password,
          'name': '$nombres $apellidos',
        }),
        xasync: false,
      );

      if (execution.status != 'completed') {
        throw ServerException(
          'Error al crear usuario: ${execution.responseStatusCode}',
        );
      }

      final response = jsonDecode(execution.responseBody) as Map<String, dynamic>;
      if (response['success'] != true) {
        throw ServerException(
          response['error'] as String? ?? 'Error al crear usuario en el servidor',
        );
      }

      final authUserId = response['userId'] as String;

      await databases.createDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.usuariosCollectionId,
        documentId: authUserId,
        data: {
          'cedula': cedula,
          'nombres': nombres,
          'apellidos': apellidos,
          'telefono': telefono,
          'correo': correo,
          'rol': 'coordinador_recinto',
          'primer_login': true,
          'recinto_id': recintoId,
          'creado_por': creadoPor,
        },
      );

      await databases.updateDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.recintosCollectionId,
        documentId: recintoId,
        data: {'coordinador_recinto_id': authUserId},
      );
    } on ServerException {
      rethrow;
    } on AppwriteException catch (e) {
      throw ServerException(
        e.message ?? 'Error al crear coordinador de recinto',
      );
    }
  }

  @override
  Future<Map<String, int>> getAvanceRecinto(String recintoId) async {
    try {
      final mesasDocs = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.mesasCollectionId,
        queries: [Query.equal('recinto_id', recintoId)],
      );

      final totalMesas = mesasDocs.documents.length;

      final mesaIds = mesasDocs.documents.map((d) => d.$id).toList();

      int actasRegistradas = 0;
      if (mesaIds.isNotEmpty) {
        final actasDocs = await databases.listDocuments(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.actasCollectionId,
        );
        actasRegistradas = actasDocs.documents
            .where((doc) =>
                mesaIds.contains(doc.data['mesa_id']) &&
                doc.data['estado'] == 'registrada')
            .length;
      }

      return {
        'total_mesas': totalMesas,
        'actas_registradas': actasRegistradas,
      };
    } on AppwriteException catch (e) {
      throw ServerException(e.message ?? 'Error al obtener avance');
    }
  }

  @override
  Future<Map<String, dynamic>> getResumenGlobal() async {
    try {
      final recintosDocs = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.recintosCollectionId,
      );
      final totalRecintos = recintosDocs.documents.length;

      final mesasDocs = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.mesasCollectionId,
      );
      final totalMesas = mesasDocs.documents.length;

      int actasRegistradas = 0;
      final actasDocs = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.actasCollectionId,
      );
      actasRegistradas = actasDocs.documents
          .where((doc) => doc.data['estado'] == 'registrada')
          .length;

      return {
        'total_recintos': totalRecintos,
        'total_mesas': totalMesas,
        'actas_registradas': actasRegistradas,
      };
    } on AppwriteException catch (e) {
      throw ServerException(e.message ?? 'Error al obtener resumen global');
    }
  }

  @override
  Future<List<ActaModel>> getActasPorRecinto(String recintoId) async {
    try {
      final mesasDocs = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.mesasCollectionId,
        queries: [Query.equal('recinto_id', recintoId)],
      );

      final mesaIds = mesasDocs.documents.map((d) => d.$id).toList();
      if (mesaIds.isEmpty) return [];

      final actasDocs = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.actasCollectionId,
      );

      return actasDocs.documents
          .where((doc) =>
              mesaIds.contains(doc.data['mesa_id']) &&
              doc.data['estado'] == 'registrada')
          .map((doc) => ActaModel.fromMap(doc.data, doc.$id))
          .toList();
    } on AppwriteException catch (e) {
      throw ServerException(e.message ?? 'Error al obtener actas del recinto');
    }
  }

  @override
  Future<List<VotosConsolidados>> getVotosConsolidados(
    String? recintoId,
  ) async {
    try {
      final orgDocs = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.organizacionesCollectionId,
      );
      final organizaciones = <String, Map<String, dynamic>>{};
      for (final doc in orgDocs.documents) {
        organizaciones[doc.$id] = {
          'nombre': doc.data['nombre'] as String,
          'dignidad': doc.data['dignidad'] as String,
          'candidato': doc.data['candidato'] as String,
        };
      }

      List<String> mesasIds;
      if (recintoId != null) {
        final mesasDocs = await databases.listDocuments(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.mesasCollectionId,
          queries: [Query.equal('recinto_id', recintoId)],
        );
        mesasIds = mesasDocs.documents.map((d) => d.$id).toList();
      } else {
        final mesasDocs = await databases.listDocuments(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.mesasCollectionId,
        );
        mesasIds = mesasDocs.documents.map((d) => d.$id).toList();
      }

      if (mesasIds.isEmpty) return [];

      final actasDocs = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.actasCollectionId,
      );

      final actasRegistradas = actasDocs.documents.where((doc) =>
          mesasIds.contains(doc.data['mesa_id']) &&
          doc.data['estado'] == 'registrada');

      if (actasRegistradas.isEmpty) return [];

      final actaIds = actasRegistradas.map((d) => d.$id).toList();
      final actaDignidades = <String, String>{};
      for (final doc in actasRegistradas) {
        actaDignidades[doc.$id] = doc.data['dignidad'] as String;
      }

      final votosDocs = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.votosCollectionId,
        queries: [Query.equal('acta_id', actaIds)],
      );

      final acumulado = <String, Map<String, int>>{};
      for (final doc in votosDocs.documents) {
        final actaId = doc.data['acta_id'] as String;
        final orgId = doc.data['organizacion_id'] as String;
        final cantidad = (doc.data['cantidad_votos'] as num).toInt();
        final dignidad = actaDignidades[actaId] ?? 'general';

        acumulado.putIfAbsent(dignidad, () => {});
        acumulado[dignidad]!.update(
          orgId,
          (v) => v + cantidad,
          ifAbsent: () => cantidad,
        );
      }

      final result = <VotosConsolidados>[];
      for (final entry in acumulado.entries) {
        final resultados = entry.value.entries.map((e) {
          final orgInfo = organizaciones[e.key];
          return ResultadoOrganizacion(
            organizacionId: e.key,
            nombreOrganizacion: orgInfo?['nombre'] as String? ?? 'Desconocido',
            candidato: orgInfo?['candidato'] as String? ?? '',
            totalVotos: e.value,
          );
        }).toList();

        resultados.sort((a, b) => b.totalVotos.compareTo(a.totalVotos));

        result.add(
          VotosConsolidados(dignidad: entry.key, resultados: resultados),
        );
      }

      result.sort((a, b) => a.dignidad.compareTo(b.dignidad));

      return result;
    } on AppwriteException catch (e) {
      throw ServerException(
        e.message ?? 'Error al obtener votos consolidados',
      );
    }
  }

  @override
  Future<DetalleActaCompleto> getDetalleActa(
    String actaId,
    String mesaId,
  ) async {
    try {
      final actaDoc = await databases.getDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.actasCollectionId,
        documentId: actaId,
      );
      final actaData = actaDoc.data;

      String mesaLbl = '';
      try {
        final mesaDoc = await databases.getDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.mesasCollectionId,
          documentId: mesaId,
        );
        // NOTA: numero_jrv en 'mesas' también debe ser integer si sigue el
        // mismo patrón que 'recintos'. Ajustado a num? -> toString() para
        // evitar el mismo error de tipo al leer.
        final numeroJrvMesa = mesaDoc.data['numero_jrv'];
        mesaLbl = numeroJrvMesa != null ? numeroJrvMesa.toString() : mesaId;
      } catch (_) {
        mesaLbl = mesaId;
      }

      final orgDocs = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.organizacionesCollectionId,
      );
      final orgMap = <String, Map<String, String>>{};
      for (final doc in orgDocs.documents) {
        orgMap[doc.$id] = {
          'nombre': doc.data['nombre'] as String? ?? '',
          'candidato': doc.data['candidato'] as String? ?? '',
        };
      }

      final votosDocs = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.votosCollectionId,
        queries: [Query.equal('acta_id', actaId)],
      );

      final votos = votosDocs.documents.map((doc) {
        final orgId = doc.data['organizacion_id'] as String;
        final orgInfo = orgMap[orgId] ?? {};
        return VotoConOrganizacion(
          organizacionId: orgId,
          nombreOrganizacion: orgInfo['nombre'] ?? 'Desconocido',
          candidato: orgInfo['candidato'] ?? '',
          votos: (doc.data['cantidad_votos'] as num).toInt(),
        );
      }).toList();

      return DetalleActaCompleto(
        acta: _mapActa(actaData, actaId),
        mesaNumero: mesaLbl,
        votos: votos,
      );
    } on AppwriteException catch (e) {
      throw ServerException(e.message ?? 'Error al obtener detalle del acta');
    }
  }

  @override
  Future<void> deleteRecinto(String recintoId) async {
    try {
      final mesasDocs = await databases.listDocuments(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.mesasCollectionId,
        queries: [Query.equal('recinto_id', recintoId)],
      );
      for (final mesa in mesasDocs.documents) {
        await databases.deleteDocument(
          databaseId: AppwriteConstants.databaseId,
          collectionId: AppwriteConstants.mesasCollectionId,
          documentId: mesa.$id,
        );
      }
      await databases.deleteDocument(
        databaseId: AppwriteConstants.databaseId,
        collectionId: AppwriteConstants.recintosCollectionId,
        documentId: recintoId,
      );
    } on AppwriteException catch (e) {
      throw ServerException(e.message ?? 'Error al eliminar recinto');
    }
  }

  Acta _mapActa(Map<String, dynamic> data, String id) {
    return Acta(
      id: id,
      mesaId: data['mesa_id'] as String,
      dignidad: data['dignidad'] as String,
      totalSufragantes: data['total_sufragantes'] as int,
      votosNulos: data['votos_nulos'] as int,
      // ATENCIÓN: verifica en Appwrite Console si la columna real en
      // 'actas' se llama 'votos_blancos' o 'votos_blanco'. Este código
      // asume 'votos_blancos' (como estaba en el original). Si no
      // coincide con la consola, tendrás el mismo error de "Missing
      // required attribute" que tuviste con 'numero_jrv'.
      votosBlancos: data['votos_blancos'] as int,
      fotoUrl: data['foto_url'] as String?,
      gpsLatitud: (data['gps_lat'] as num?)?.toDouble(),
      gpsLongitud: (data['gps_lng'] as num?)?.toDouble(),
      registradoPor: data['created_by'] as String,
      estado: data['estado'] as String? ?? 'pendiente',
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse(data['updated_at'] as String)
          : null,
    );
  }
}