import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/veedor_bloc.dart';
import '../bloc/veedor_event.dart';
import '../bloc/veedor_state.dart';
import 'corregir_acta_page.dart';

class MisMesasPage extends StatefulWidget {
  const MisMesasPage({super.key});

  @override
  State<MisMesasPage> createState() => _MisMesasPageState();
}

class _MisMesasPageState extends State<MisMesasPage> {
  @override
  void initState() {
    super.initState();
    _loadMesas();
  }

  void _loadMesas() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context
          .read<VeedorBloc>()
          .add(LoadMesasVeedor(veedorId: authState.usuario.id));
    }
  }

  void _navegarCorregir(Map<String, dynamic> acta) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<VeedorBloc>(),
          child: CorregirActaPage(
            actaId: acta['id'] as String,
            mesaId: acta['mesa_id'] as String,
            dignidad: acta['dignidad'] as String,
            totalSufragantes: acta['total_sufragantes'] as int,
            votosNulos: acta['votos_nulos'] as int,
            votosBlancos: acta['votos_blancos'] as int,
            fotoUrl: acta['foto_url'] as String?,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Mesas')),
      body: BlocBuilder<VeedorBloc, VeedorState>(
        builder: (context, state) {
          if (state is VeedorLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is VeedorError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadMesas,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (state is MesasVeedorLoaded) {
            if (state.mesas.isEmpty) {
              return const Center(
                child: Text('No tienes mesas asignadas'),
              );
            }
            return RefreshIndicator(
              onRefresh: () async => _loadMesas(),
              child: ListView.builder(
                itemCount: state.mesas.length,
                itemBuilder: (context, index) {
                  final item = state.mesas[index];
                  final mesa = item['mesa'] as Map<String, dynamic>;
                  final recinto =
                      item['recinto'] as Map<String, dynamic>;
                  final actas = item['actas'] as List;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ExpansionTile(
                      title: Text('JRV ${mesa['numero_jrv']}'),
                      subtitle: Text(recinto['nombre'] as String),
                      children: [
                        if (actas.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'Sin actas registradas',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          ...actas.map(
                            (actaRaw) {
                              final acta =
                                  actaRaw as Map<String, dynamic>;
                              return ListTile(
                                title: Text(
                                    'Acta: ${acta['dignidad']}'),
                                subtitle: Text(
                                  'Total: ${acta['total_sufragantes']}',
                                ),
                                trailing: TextButton.icon(
                                  onPressed: () =>
                                      _navegarCorregir(acta),
                                  icon: const Icon(Icons.edit,
                                      size: 18),
                                  label: const Text('Corregir'),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
