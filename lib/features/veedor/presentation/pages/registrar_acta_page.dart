import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/utils/gps_helper.dart';
import '../../../../core/utils/image_quality_checker.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../bloc/veedor_bloc.dart';
import '../bloc/veedor_event.dart';
import '../bloc/veedor_state.dart';

class RegistrarActaPage extends StatefulWidget {
  const RegistrarActaPage({super.key});

  @override
  State<RegistrarActaPage> createState() => _RegistrarActaPageState();
}

class _RegistrarActaPageState extends State<RegistrarActaPage> {
  int _step = 0;
  String? _selectedMesaId;
  Map<String, dynamic>? _selectedMesa;

  final _formKey = GlobalKey<FormState>();
  final _totalController = TextEditingController();
  final _nulosController = TextEditingController();
  final _blancosController = TextEditingController();
  final Map<String, TextEditingController> _orgControllers = {};

  List<Map<String, dynamic>> _mesas = [];
  List<Map<String, dynamic>> _organizaciones = [];

  bool _gpsObtained = false;
  double _gpsLat = 0;
  double _gpsLng = 0;
  bool _processing = false;

  File? _imageFile;
  bool _isChecking = false;

  static const _dignidades = ['alcalde', 'prefecto'];

  String get _currentDignidad => _dignidades[_step - 1];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context
          .read<VeedorBloc>()
          .add(LoadMesasVeedor(veedorId: authState.usuario.id));
      context.read<VeedorBloc>().add(const LoadOrganizaciones());
    }
  }

  Future<void> _obtenerGps() async {
    final enabled = await GpsHelper.isGpsEnabled();
    if (!enabled) return;

    final permission = await GpsHelper.checkPermission();
    if (permission == LocationPermission.denied) {
      await GpsHelper.requestPermission();
    }

    final position = await GpsHelper.getCurrentPosition();
    if (position != null && mounted) {
      setState(() {
        _gpsObtained = true;
        _gpsLat = position.latitude;
        _gpsLng = position.longitude;
      });
    }
  }

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (photo == null) return;

    setState(() => _isChecking = true);

    final file = File(photo.path);
    final isSharp = await ImageQualityChecker.isSharp(file);

    setState(() => _isChecking = false);

    if (!isSharp) {
      if (mounted) {
        final retry = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Foto Borrosa'),
            content: const Text(
              'La foto no tiene la nitidez suficiente. '
              'Por favor, toma otra foto con mejor enfoque.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Tomar de nuevo'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Omitir'),
              ),
            ],
          ),
        );
        if (retry == true) {
          _tomarFoto();
        }
      }
      return;
    }

    setState(() => _imageFile = file);
    await _obtenerGps();
  }

  bool _validarActa() {
    final total = int.tryParse(_totalController.text) ?? 0;
    final nulos = int.tryParse(_nulosController.text) ?? 0;
    final blancos = int.tryParse(_blancosController.text) ?? 0;

    int sumaOrg = 0;
    for (final c in _orgControllers.values) {
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
            'La suma de votos (organizaciones + nulos + blancos) debe ser igual al total de sufragantes',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes tomar una foto del acta'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_gpsObtained) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Obteniendo ubicación GPS...'),
          backgroundColor: Colors.orange,
        ),
      );
      _obtenerGps();
      return;
    }

    final authState = context.read<AuthBloc>().state;
    String registradoPor = '';
    if (authState is AuthAuthenticated) {
      registradoPor = authState.usuario.id;
    }

    final votosPorOrganizacion = <String, int>{};
    for (final org in _organizaciones) {
      final orgId = org['id'] as String;
      final controller = _orgControllers[orgId];
      if (controller != null) {
        votosPorOrganizacion[orgId] = int.tryParse(controller.text) ?? 0;
      }
    }

    setState(() => _processing = true);

    context.read<VeedorBloc>().add(
          RegistrarActa(
            mesaId: _selectedMesaId!,
            dignidad: _currentDignidad,
            totalSufragantes: int.parse(_totalController.text),
            votosNulos: int.parse(_nulosController.text),
            votosBlancos: int.parse(_blancosController.text),
            gpsLatitud: _gpsLat,
            gpsLongitud: _gpsLng,
            registradoPor: registradoPor,
            votosPorOrganizacion: votosPorOrganizacion,
          ),
        );
  }

  void _subirFoto(String actaId) {
    context.read<VeedorBloc>().add(
          SubirFotoActa(
            filePath: _imageFile!.path,
            actaId: actaId,
          ),
        );
  }

  Future<void> _avanzarSiguiente() async {
    if (_step < 2) {
      setState(() {
        _step++;
        _limpiarFormulario();
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ambas actas registradas exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _limpiarFormulario() {
    _totalController.clear();
    _nulosController.clear();
    _blancosController.clear();
    for (final c in _orgControllers.values) {
      c.clear();
    }
    _imageFile = null;
    _gpsObtained = false;
    _gpsLat = 0;
    _gpsLng = 0;
    _obtenerGps();
  }

  @override
  void dispose() {
    _totalController.dispose();
    _nulosController.dispose();
    _blancosController.dispose();
    for (final c in _orgControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isAlcaldeRegistered {
    return _actasRegistradasEnSesion.contains('alcalde');
  }

  bool get _isPrefectoRegistered {
    return _actasRegistradasEnSesion.contains('prefecto');
  }

  final Set<String> _actasRegistradasEnSesion = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Acta')),
      body: BlocConsumer<VeedorBloc, VeedorState>(
        listener: (context, state) async {
          if (state is ActaRegistrada) {
            _subirFoto(state.acta.id);
          }
          if (state is FotoSubida) {
            setState(() => _processing = false);
            _actasRegistradasEnSesion.add(_currentDignidad);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Acta de $_currentDignidad registrada correctamente',
                ),
                backgroundColor: Colors.green,
              ),
            );
            await _avanzarSiguiente();
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
          if (state is MesasVeedorLoaded) {
            setState(() => _mesas = state.mesas);
            _obtenerGps();
          }
          if (state is OrganizacionesLoaded) {
            setState(() {
              _organizaciones = state.organizaciones;
              for (final org in _organizaciones) {
                final id = org['id'] as String;
                if (!_orgControllers.containsKey(id)) {
                  _orgControllers[id] = TextEditingController();
                }
              }
            });
          }
        },
        builder: (context, state) {
          return Stack(
            children: [
              _buildBody(),
              if (_processing || _isChecking || state is VeedorLoading)
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

  Widget _buildBody() {
    if (_mesas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_step == 0) {
      return _buildMesaSelection();
    }

    return _buildFormulario();
  }

  void _onMesaSeleccionada(String mesaId) {
    setState(() {
      _selectedMesaId = mesaId;
      _selectedMesa = null;
      _actasRegistradasEnSesion.clear();
      for (final item in _mesas) {
        if (item['mesa_id'] == mesaId) {
          _selectedMesa = item['mesa'] as Map<String, dynamic>;
          final actas = item['actas'] as List;
          for (final a in actas) {
            final d = (a as Map<String, dynamic>)['dignidad'] as String;
            _actasRegistradasEnSesion.add(d);
          }
          break;
        }
      }
      if (_isAlcaldeRegistered && _isPrefectoRegistered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esta mesa ya tiene ambas actas registradas'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      _step = _isAlcaldeRegistered ? 2 : 1;
      _obtenerGps();
    });
  }

  Widget _buildMesaSelection() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Selecciona una mesa',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._mesas.map((item) {
          final mesa = item['mesa'] as Map<String, dynamic>;
          final recinto = item['recinto'] as Map<String, dynamic>;
          final actas = item['actas'] as List;
          final tieneAlcalde = actas.any(
            (a) => (a as Map<String, dynamic>)['dignidad'] == 'alcalde',
          );
          final tienePrefecto = actas.any(
            (a) => (a as Map<String, dynamic>)['dignidad'] == 'prefecto',
          );
          final completa = tieneAlcalde && tienePrefecto;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: completa ? Colors.green.shade50 : null,
            child: ListTile(
              title: Text('JRV ${mesa['numero_jrv'] ?? item['mesa_id']}'),
              subtitle: Text(recinto['nombre'] as String? ?? ''),
              trailing: completa
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : const Icon(Icons.chevron_right),
              onTap: completa
                  ? null
                  : () =>
                      _onMesaSeleccionada(item['mesa_id'] as String),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildFormulario() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: _step / _dignidades.length,
              minHeight: 4,
            ),
            const SizedBox(height: 12),
            Text(
              '${_currentDignidad.toUpperCase()} — JRV ${_selectedMesa!['numero_jrv'] ?? _selectedMesaId}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.5),
                    1: FlexColumnWidth(2.5),
                    2: FlexColumnWidth(1.5),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Organización',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Candidato',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                        Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Votos',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ],
                    ),
                    ..._organizaciones.map((org) {
                      final id = org['id'] as String;
                      final nombre = org['nombre'] as String;
                      final candidato = org['candidato'] as String;
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(nombre,
                                style: const TextStyle(fontSize: 12)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(candidato,
                                style: const TextStyle(fontSize: 12)),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(4),
                            child: TextFormField(
                              controller: _orgControllers[id],
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(),
                              ),
                              style: const TextStyle(fontSize: 14),
                              validator: (v) =>
                                  (v?.isEmpty ?? true) ? '' : null,
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nulosController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Nulos',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v?.isEmpty ?? true) ? '' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _blancosController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Blancos',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v?.isEmpty ?? true) ? '' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _totalController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Total',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v?.isEmpty ?? true) ? '' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Foto del Acta',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_imageFile != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _imageFile!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              GestureDetector(
                onTap: _tomarFoto,
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt,
                            size: 40, color: Colors.grey),
                        SizedBox(height: 4),
                        Text(
                          'Presiona para tomar foto',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(
                          'Debe ser nítida y legible',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (_imageFile != null)
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  const Text('Foto válida',
                      style: TextStyle(
                          color: Colors.green, fontSize: 12)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _tomarFoto,
                    icon: const Icon(Icons.camera_alt, size: 16),
                    label: const Text('Retomar',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _tomarFoto,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Tomar Foto'),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _gpsObtained ? Icons.location_on : Icons.location_off,
                  color: _gpsObtained ? Colors.green : Colors.grey,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  _gpsObtained
                      ? 'GPS: $_gpsLat, $_gpsLng'
                      : 'Obteniendo GPS...',
                  style: TextStyle(
                    fontSize: 11,
                    color: _gpsObtained ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _processing ? null : _onGuardar,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Guardar Acta',
                style: TextStyle(fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
