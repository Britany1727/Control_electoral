import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/deep_links/deep_link_handler.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/presentation/bloc/recovery_bloc.dart';
import 'features/auth/presentation/bloc/verification/verification_bloc.dart';
import 'features/coordinador_provincial/presentation/bloc/provincial_bloc.dart';
import 'features/coordinador_recinto/presentation/bloc/recinto_bloc.dart';
import 'features/veedor/presentation/bloc/veedor_bloc.dart';
import 'features/veedor/presentation/sync/sync_bloc.dart';
import 'injection_container.dart' as di;
import 'injection_container.dart';
import 'router/app_router.dart' as router;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Hive.initFlutter();
  await di.init();
  runApp(const ControlElectoralApp());
}

class ControlElectoralApp extends StatefulWidget {
  const ControlElectoralApp({super.key});

  @override
  State<ControlElectoralApp> createState() => _ControlElectoralAppState();
}

class _ControlElectoralAppState extends State<ControlElectoralApp> {
  late final AuthBloc _authBloc = sl<AuthBloc>();
  late final GoRouter _appRouter = router.createAppRouter(_authBloc);
  late final DeepLinkHandler _deepLinkHandler = DeepLinkHandler();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _deepLinkHandler.init(context);
      }
    });
  }

  @override
  void dispose() {
    _deepLinkHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _authBloc),
        BlocProvider(create: (_) => sl<RecoveryBloc>()),
        BlocProvider(create: (_) => sl<VerificationBloc>()),
        BlocProvider(create: (_) => sl<ProvincialBloc>()),
        BlocProvider(create: (_) => sl<RecintoBloc>()),
        BlocProvider(create: (_) => sl<VeedorBloc>()),
        BlocProvider(create: (_) => sl<SyncBloc>()),
      ],
      child: MaterialApp.router(
        title: 'Control Electoral',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        routerConfig: _appRouter,
      ),
    );
  }
}
