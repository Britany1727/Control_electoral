import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/veedor_bloc.dart';
import '../bloc/veedor_event.dart';
import '../bloc/veedor_state.dart';
import 'foto_acta_page.dart';

class CorregirActaPage extends StatefulWidget {
  final String actaId;
  final String mesaId;
  final String dignidad;
  final int totalSufragantes;
  final int votosNulos;
  final int votosBlancos;
  final String? fotoUrl;

  const CorregirActaPage({
    super.key,
    required this.actaId,
    required this.mesaId,
    required this.dignidad,
    required this.totalSufragantes,
    required this.votosNulos,
    required this.votosBlancos,
    this.fotoUrl,
  });

  @override
  State<CorregirActaPage> createState() => _CorregirActaPageState();
}

class _CorregirActaPageState extends State<CorregirActaPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _totalController;
  late final TextEditingController _nulosController;
  late final TextEditingController _blancosController;
  final Map<String, TextEditingController> _orgControllers = {};
  final Map<String, TextEditingController> _orgControllersNuevos = {};

  List<Map<String, dynamic>> _organizaciones = [];
  bool _loadingVotos = true;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _totalController =
        TextEditingController(text: widget.totalSufragantes.toString());
    _nulosController =
        TextEditingController(text: widget.votosNulos.toString());
    _blancosController =
        TextEditingController(text: widget.votosBlancos.toString());

    context.read<VeedorBloc>().add(const LoadOrganizaciones());
    context.read<VeedorBloc>().add(LoadVotosPorActa(actaId: widget.actaId));
  }

  @override
  void dispose() {
    _totalController.dispose();
    _nulosController.dispose();
    _blancosController.dispose();
    for (final c in _orgControllers.values) {
      c.dispose();
    }
    for (final c in _orgControllersNuevos.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _validarActa() {
    final total = int.tryParse(_totalController.text) ?? 0;
    final nulos = int.tryParse(_nulosController.text) ?? 0;
    final blancos = int.tryParse(_blancosController.text) ?? 0;

    int sumaOrg = 0;
    for (final c in _orgControllers.values) {
      sumaOrg += int.tryParse(c.text) ?? 0;
    }
    for (final c in _orgControllersNuevos.values) {
      sumaOrg += int.tryParse(c.text) ?? 0;
    }

    return (sumaOrg + nulos + blancos) == total;
  }

  void _onGuardar() {
    if (!_formKey.currentState!.validate()) return;

    final total = int.tryParse(_totalController.text) ?? 0;
    for (final c in _orgControllers.values) {
      if ((int.tryParse(c.text) ?? 0) > total) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Los votos de un candidato no pueden exceder el total de sufragantes',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (!_validarActa()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La suma de votos debe ser igual al total de sufragantes',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final authState = context.read<AuthBloc>().state;
    String modificadoPor = '';
    if (authState is AuthAuthenticated) {
      modificadoPor = authState.usuario.id;
    }

    final votosPorOrganizacion = <String, int>{};
    for (final entry in _orgControllers.entries) {
      votosPorOrganizacion[entry.key] =
          int.tryParse(entry.value.text) ?? 0;
    }
    for (final entry in _orgControllersNuevos.entries) {
      votosPorOrganizacion[entry.key] =
          int.tryParse(entry.value.text) ?? 0;
    }

    setState(() => _processing = true);
    context.read<VeedorBloc>().add(
          CorregirActaVeedor(
            actaId: widget.actaId,
            totalSufragantes: int.parse(_totalController.text),
            votosNulos: int.parse(_nulosController.text),
            votosBlancos: int.parse(_blancosController.text),
            votosPorOrganizacion: votosPorOrganizacion,
            modificadoPor: modificadoPor,
          ),
        );
  }

  void _retomarFoto() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<VeedorBloc>(),
          child: FotoActaPage(actaId: widget.actaId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Corregir Acta - ${widget.dignidad}'),
      ),
      body: BlocConsumer<VeedorBloc, VeedorState>(
        listener: (context, state) {
          if (state is OrganizacionesLoaded) {
            setState(() {
              _organizaciones = state.organizaciones;
              for (final org in _organizaciones) {
                final id = org['id'] as String;
                if (!_orgControllers.containsKey(id) &&
                    !_orgControllersNuevos.containsKey(id)) {
                  _orgControllers[id] = TextEditingController();
                }
              }
            });
          }
          if (state is VotosPorActaLoaded) {
            setState(() {
              for (final entry in state.votos.entries) {
                if (_orgControllers.containsKey(entry.key)) {
                  _orgControllers[entry.key]!.text = entry.value.toString();
                }
              }
              _loadingVotos = false;
            });
          }
          if (state is ActaCorregida) {
            setState(() => _processing = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Acta corregida exitosamente'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.of(context).pop();
          }
          if (state is VeedorError) {
            setState(() => _processing = false);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              _loadingVotos
                  ? const Center(child: CircularProgressIndicator())
                  : _buildForm(),
              if (_processing || state is VeedorLoading)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _totalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Sufragantes',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.isEmpty ?? true) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            ..._organizaciones.map((org) {
              final id = org['id'] as String;
              final nombre = org['nombre'] as String;
              final candidato = org['candidato'] as String;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _orgControllers[id],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '$nombre - $candidato',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v?.isEmpty ?? true) ? 'Requerido' : null,
                ),
              );
            }),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nulosController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Votos Nulos',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.isEmpty ?? true) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _blancosController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Votos Blancos',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v?.isEmpty ?? true) ? 'Requerido' : null,
            ),
            const SizedBox(height: 24),
            if (widget.fotoUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const Icon(Icons.image, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text('Foto existente'),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _retomarFoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Cambiar foto'),
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _retomarFoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Tomar foto'),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _processing ? null : _onGuardar,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Guardar Corrección',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
