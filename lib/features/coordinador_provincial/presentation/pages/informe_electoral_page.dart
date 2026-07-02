import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/recinto.dart';
import '../../domain/entities/votos_consolidados.dart';
import '../bloc/provincial_bloc.dart';
import '../bloc/provincial_event.dart';
import '../bloc/provincial_state.dart';
import 'avance_recinto_page.dart';

class InformeElectoralPage extends StatefulWidget {
  const InformeElectoralPage({super.key});

  @override
  State<InformeElectoralPage> createState() => _InformeElectoralPageState();
}

class _InformeElectoralPageState extends State<InformeElectoralPage> {
  Map<String, dynamic>? _resumen;
  List<VotosConsolidados> _votos = [];
  List<Recinto> _recintos = [];
  String? _selectedRecintoId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() => _loading = true);
    context.read<ProvincialBloc>().add(const LoadResumenGlobal());
  }

  void _loadRecintos() {
    context.read<ProvincialBloc>().add(const LoadRecintos());
  }

  void _loadVotos() {
    context.read<ProvincialBloc>().add(
          LoadVotosConsolidados(recintoId: _selectedRecintoId),
        );
  }

  void _onRecintoChanged(String? recintoId) {
    setState(() => _selectedRecintoId = recintoId);
    context.read<ProvincialBloc>().add(
          LoadVotosConsolidados(recintoId: recintoId),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informe Electoral')),
      body: BlocListener<ProvincialBloc, ProvincialState>(
        listener: (context, state) {
          if (state is ResumenGlobalLoaded) {
            setState(() {
              _resumen = {
                'total_recintos': state.totalRecintos,
                'total_mesas': state.totalMesas,
                'actas_registradas': state.actasRegistradas,
              };
              _loading = false;
            });
            _loadRecintos();
            return;
          }
          if (state is RecintosLoaded) {
            setState(() {
              _recintos = state.recintos;
              _loading = false;
            });
            _loadVotos();
            return;
          }
          if (state is VotosConsolidadosLoaded) {
            setState(() {
              _votos = state.votos;
              _loading = false;
            });
            return;
          }
          if (state is ProvincialInitial) {
            _loadData();
            return;
          }
          if (state is ProvincialError) {
            setState(() => _loading = false);
          }
        },
        child: _loading && _resumen == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async => _loadData(),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildResumenCard(),
                    const SizedBox(height: 16),
                    _buildFiltroRecinto(),
                    const SizedBox(height: 16),
                    _buildVotosConsolidados(),
                    const SizedBox(height: 16),
                    _buildListaRecintos(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildResumenCard() {
    final totalMesas = _resumen?['total_mesas'] ?? 0;
    final actasReg = _resumen?['actas_registradas'] ?? 0;
    final totalRecintos = _resumen?['total_recintos'] ?? 0;
    final pendientes = totalMesas - actasReg;
    final porcentaje =
        totalMesas > 0 ? (actasReg / totalMesas * 100) : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.dashboard, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Resumen General',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatBadge(
                  icon: Icons.business,
                  label: 'Recintos',
                  value: totalRecintos.toString(),
                  color: Colors.blue,
                ),
                _StatBadge(
                  icon: Icons.table_chart,
                  label: 'Mesas',
                  value: totalMesas.toString(),
                  color: Colors.teal,
                ),
                _StatBadge(
                  icon: Icons.check_circle,
                  label: 'Actas',
                  value: actasReg.toString(),
                  color: Colors.green,
                ),
                _StatBadge(
                  icon: Icons.pending,
                  label: 'Pendientes',
                  value: pendientes.toString(),
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: porcentaje / 100,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${porcentaje.toStringAsFixed(1)}% de avance general',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroRecinto() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.filter_list, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Filtrar por Recinto',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedRecintoId,
              decoration: const InputDecoration(
                labelText: 'Recinto',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Todos los recintos'),
                ),
                ..._recintos.map(
                  (r) => DropdownMenuItem(
                    value: r.id,
                    child: Text(r.nombre),
                  ),
                ),
              ],
              onChanged: _onRecintoChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVotosConsolidados() {
    if (_votos.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.pie_chart, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Votos Consolidados',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                _selectedRecintoId != null
                    ? 'No hay votos registrados en este recinto'
                    : 'No hay votos registrados',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.pie_chart, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Votos Consolidados',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_selectedRecintoId != null)
                Chip(
                  label: Text(
                    _recintos
                            .where((r) => r.id == _selectedRecintoId)
                            .firstOrNull
                            ?.nombre ??
                        'Filtrado',
                    style: const TextStyle(fontSize: 12),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
        ..._votos.map((grupo) => _buildGrupoVotos(grupo)),
      ],
    );
  }

  Widget _buildGrupoVotos(VotosConsolidados grupo) {
    final total = grupo.resultados.fold(0, (sum, r) => sum + r.totalVotos);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              grupo.dignidad.toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const Divider(),
            ...grupo.resultados.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.nombreOrganizacion,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          if (r.candidato.isNotEmpty)
                            Text(
                              r.candidato,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        r.totalVotos.toString(),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  total.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListaRecintos() {
    if (_recintos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.list, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'Avance por Recinto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        ..._recintos.map(
          (r) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.business, color: Colors.blue),
              title: Text(r.nombre),
              subtitle: Text('${r.canton} - ${r.parroquia}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: context.read<ProvincialBloc>(),
                      child: AvanceRecintoPage(
                        recintoId: r.id,
                        recintoNombre: r.nombre,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 28, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
