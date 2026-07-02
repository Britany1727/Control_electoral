import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/provincial_bloc.dart';
import '../bloc/provincial_event.dart';
import '../bloc/provincial_state.dart';
import 'avance_recinto_page.dart';

class RecintosListPage extends StatefulWidget {
  const RecintosListPage({super.key});

  @override
  State<RecintosListPage> createState() => _RecintosListPageState();
}

class _RecintosListPageState extends State<RecintosListPage> {
  @override
  void initState() {
    super.initState();
    context.read<ProvincialBloc>().add(const LoadRecintos());
  }

  Future<void> _confirmarEliminacion(String recintoId, String recintoNombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Recinto'),
        content: Text(
          '¿Estás seguro de eliminar "$recintoNombre"?\n\n'
          'Se eliminarán también todas las mesas asociadas. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      context.read<ProvincialBloc>().add(DeleteRecinto(recintoId: recintoId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recintos')),
      body: BlocConsumer<ProvincialBloc, ProvincialState>(
        listener: (context, state) {
          if (state is RecintoDeleted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recinto eliminado correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            context.read<ProvincialBloc>().add(const LoadRecintos());
          }
        },
        builder: (context, state) {
          if (state is ProvincialLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ProvincialError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ProvincialBloc>().add(const LoadRecintos());
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          if (state is RecintosLoaded) {
            if (state.recintos.isEmpty) {
              return const Center(
                child: Text('No hay recintos registrados'),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                context.read<ProvincialBloc>().add(const LoadRecintos());
              },
              child: ListView.builder(
                itemCount: state.recintos.length,
                itemBuilder: (context, index) {
                  final recinto = state.recintos[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      title: Text(recinto.nombre),
                      subtitle: Text(
                        '${recinto.canton} - ${recinto.parroquia}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _confirmarEliminacion(
                              recinto.id,
                              recinto.nombre,
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<ProvincialBloc>(),
                              child: AvanceRecintoPage(
                                recintoId: recinto.id,
                                recintoNombre: recinto.nombre,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            );
          }
          if (state is! ProvincialInitial) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                context.read<ProvincialBloc>().add(const LoadRecintos());
              }
            });
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
