import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:runnin/core/analytics/analytics_service.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/health_sync_service.dart';
import 'package:runnin/shared/widgets/figma/figma_device_card.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:url_launcher/url_launcher.dart';

class HealthDevicesPage extends StatefulWidget {
  const HealthDevicesPage({super.key});

  @override
  State<HealthDevicesPage> createState() => _HealthDevicesPageState();
}

class _HealthDevicesPageState extends State<HealthDevicesPage>
    with WidgetsBindingObserver {
  // Connection state local — combina:
  //   (a) profile.hasWearable persistido no perfil (set pelo onboarding step e
  //       pelo _connectViaHealthBridge abaixo),
  //   (b) healthSyncService.hasPermissions() best-effort (unreliable em iOS).
  // Quando qualquer um dos dois indica conectado, a plataforma compatível com
  // a plataforma do device é marcada como conectada. Sem isso, o card sempre
  // mostra "Conectar" mesmo após sync bem-sucedido.
  bool _appleHealthConnected = false;
  bool _googleHealthConnected = false;
  final _userRemote = UserRemoteDatasource();

  /// Resultado do último click em "VERIFICAR". null = nunca foi solicitado;
  /// vazio = "verificando..."; preenchido = mostra checklist.
  Map<String, bool>? _permissionsCache;
  bool _permissionsLoading = false;

  /// Quando user clica "SOLICITAR NOVAMENTE" e a gente abre Health Connect
  /// Settings, ele perde o contexto do app. Quando volta (app resume), a
  /// gente re-checa permissões + dispara sync automaticamente — sem isso
  /// o user veria a UI parada e teria que clicar "VERIFICAR DE NOVO".
  bool _awaitingHcReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshConnectionState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // SEMPRE re-checa conexão ao voltar do background — user pode ter
    // pareado Wear OS app, mudado permissão em Ajustes, etc. Sem isso o
    // ícone "Conectado" ficava stale (parceiro relatou: pareou Wear OS,
    // voltou pra app, ícone ainda mostrava desconectado).
    _refreshConnectionState();
    if (_awaitingHcReturn) {
      _awaitingHcReturn = false;
      // Voltou do Health Connect Settings: re-checa permissões + sync.
      _checkPermissions();
      unawaited(healthSyncService.syncSince());
    }
  }

  Future<void> _refreshConnectionState() async {
    if (kIsWeb) return;
    try {
      final results = await Future.wait([
        _userRemote.getMe(),
        healthSyncService.hasPermissions(),
      ]);
      final profile = results[0] as UserProfile?;
      final pluginOk = results[1] as bool;
      final connected = (profile?.hasWearable ?? false) || pluginOk;
      if (!mounted) return;
      setState(() {
        if (Platform.isIOS) _appleHealthConnected = connected;
        if (Platform.isAndroid) _googleHealthConnected = connected;
      });
    } catch (_) {
      // Falha silenciosa — usuário ainda pode clicar em conectar.
    }
  }

  Future<void> _checkPermissions() async {
    if (_permissionsLoading) return;
    setState(() => _permissionsLoading = true);
    analytics.logEvent('wearable_permissions_check_tapped', params: const {});
    try {
      final Map<String, bool> result;
      if (!kIsWeb && Platform.isAndroid) {
        // Android: hasPermissions() consulta o Health Connect diretamente e
        // retorna o status real das permissões. permissionsBreakdownFromSamples()
        // é um workaround pra iOS (que sempre retorna null/false pra reads) e
        // no Android devolve false pra TODOS os tipos quando não há dados nos
        // últimos 7d — mesmo com permissões corretamente concedidas.
        result = await healthSyncService.permissionsBreakdown();
      } else {
        // iOS: hasPermissions() sempre retorna null/false pra read permissions
        // (privacidade Apple). Proxy via query: se existe dado nos últimos 7d
        // = permissão concedida.
        result = await healthSyncService.permissionsBreakdownFromSamples();
      }
      if (!mounted) return;
      setState(() {
        _permissionsCache = result;
        _permissionsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _permissionsLoading = false);
    }
  }

  Future<void> _requestMissingPermissions() async {
    analytics.logEvent('wearable_permissions_request_again_tapped', params: const {});
    if (!kIsWeb && Platform.isAndroid) {
      // Android: depois de 2+ recusas, Health Connect aplica rate-limiting e
      // requestAuthorization não abre mais o diálogo (retorna false em silêncio).
      // Caminho real: abre as configurações do Health Connect pra o user
      // conceder manualmente. Marca _awaitingHcReturn pra didChangeAppLifecycle
      // re-checar permissões + disparar sync quando o user voltar pro app.
      _awaitingHcReturn = true;
      await _openHealthConnectSettings();
      return;
    }
    await healthSyncService.ensureAuthorizations();
    // Reverificar depois pra UI refletir o que o user concedeu agora.
    await _checkPermissions();
    // Best-effort: puxa o que o user acabou de liberar pra HealthKit começar
    // a alimentar imediatamente em vez de só no próximo boot/sync agendado.
    unawaited(healthSyncService.syncSince());
  }

  Future<void> _openIOSSettings() async {
    analytics.logEvent('wearable_permissions_open_settings_tapped', params: const {});
    final uri = Uri.parse('app-settings:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Apple não permite deep link direto pra "Ajustes → Saúde → Acesso a
  /// Dados → Runnin". Tenta abrir Settings.app via `App-prefs:` (URL scheme
  /// não-documentado mas histórico aceito) e, se falhar, mostra dialog com
  /// caminho manual.
  Future<void> _openHealthInstructions() async {
    analytics.logEvent('wearable_health_app_tapped', params: const {});
    final settingsUri = Uri.parse('App-prefs:');
    var opened = false;
    try {
      if (await canLaunchUrl(settingsUri)) {
        opened = await launchUrl(settingsUri);
      }
    } catch (_) {/* fall through */}
    if (!opened && mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: FigmaColors.surfaceCard,
          title: Text(
            'Abrir Saúde',
            style: context.runninType.bodyMd.copyWith(
              fontWeight: FontWeight.w500,
              color: FigmaColors.textPrimary,
            ),
          ),
          content: Text(
            'O iOS não permite abrir essa página direto.\n\n'
            'Vai em: Ajustes → Saúde → Dados → Runnin\n\n'
            'Ative os tipos que aparecem com ✗ no painel.',
            style: context.runninType.bodySm.copyWith(
              height: 1.5,
              color: FigmaColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'OK',
                style: context.runninType.labelMd.copyWith(
                  color: context.runninPalette.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _persistHasWearable() async {
    try {
      await _userRemote.patchMe(hasWearable: true);
    } catch (_) {/* best-effort */}
  }

  bool _providerConnected(_ProviderSpec p) {
    if (p.name == 'Apple Health') return _appleHealthConnected;
    if (p.name == 'Google Health Connect') return _googleHealthConnected;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final anyConnected = _appleHealthConnected || _googleHealthConnected;
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: Column(
        children: [
          const FigmaTopNav(
            breadcrumb: 'SAÚDE',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xxl),
                  _FieldLabel(label: 'CONECTADAS'),
                  const SizedBox(height: AppSpacing.md),
                  if (anyConnected)
                    ..._kCompatibleProviders
                        .where(_providerConnected)
                        .map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: FigmaCompatibleDeviceCard(
                              icon: p.icon,
                              deviceName: p.name,
                              dataLabel: p.metrics,
                              isConnected: true,
                            ),
                          ),
                        )
                  else
                    const _EmptyConnectedState(),
                  const SizedBox(height: AppSpacing.xxl),
                  // STATUS DE PERMISSÕES — só mostra em iOS/Android (não web).
                  // User pediu pra ter como verificar exatamente quais tipos
                  // de saúde o app está conseguindo ler (debug do caso "sono
                  // não aparece em lugar nenhum").
                  if (healthSyncService.isSupported) ...[
                    _FieldLabel(label: 'STATUS DE PERMISSÕES'),
                    const SizedBox(height: AppSpacing.md),
                    _PermissionsPanel(
                      data: _permissionsCache,
                      loading: _permissionsLoading,
                      onCheck: _checkPermissions,
                      onRequestAgain: _requestMissingPermissions,
                      onOpenSettings: Platform.isIOS ? _openIOSSettings : null,
                      onOpenHealth: Platform.isIOS ? _openHealthInstructions : null,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                  _FieldLabel(label: 'PLATAFORMAS DE SAÚDE'),
                  const SizedBox(height: AppSpacing.md),
                  const _PlatformsHelperText(),
                  const SizedBox(height: AppSpacing.md),
                  ..._kCompatibleProviders
                      .where((p) => _isAvailableNow(p) && !_providerConnected(p))
                      .map(
                        (p) {
                          // Plataforma do OUTRO sistema operacional aparece
                          // com cadeado: Health Connect não existe no iPhone
                          // nem Apple Health no Android. Antes o tap pedia
                          // permissão do HealthKit e marcava o provider
                          // errado como conectado.
                          final locked = _isLockedOnThisPlatform(p);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: FigmaCompatibleDeviceCard(
                              icon: p.icon,
                              deviceName: p.name,
                              dataLabel: locked
                                  ? '${p.metrics} · ${p.name == 'Apple Health' ? 'disponível no iPhone' : 'disponível no Android'}'
                                  : p.metrics,
                              locked: locked,
                              onConnect: locked
                                  ? null
                                  : () => _onConnectProvider(context, p),
                            ),
                          );
                        },
                      ),
                  const SizedBox(height: AppSpacing.xxl),
                  _FieldLabel(label: 'INTEGRAÇÕES DIRETAS (EM BREVE)'),
                  const SizedBox(height: AppSpacing.md),
                  ..._kCompatibleProviders
                      .where((p) => !_isAvailableNow(p))
                      .map(
                        (p) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: FigmaCompatibleDeviceCard(
                            icon: p.icon,
                            deviceName: p.name,
                            dataLabel: p.metrics,
                            onConnect: () => _onConnectProvider(context, p),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Apple Health (iOS) + Google Health Connect (Android) já estão integrados
  /// via plugin `health`. Cards de marcas (Garmin, Polar, etc.) ficam em
  /// "INTEGRAÇÕES DIRETAS (EM BREVE)" porque exigem OAuth próprio do fabricante
  /// — não vão pelas plataformas de saúde do SO.
  bool _isAvailableNow(_ProviderSpec p) =>
      p.name == 'Apple Health' || p.name == 'Google Health Connect';

  /// Plataforma do outro SO: Health Connect num iPhone (ou Apple Health num
  /// Android) aparece com cadeado — não dá pra conectar deste device.
  /// Web: ambas travadas (plugin health não roda no browser).
  bool _isLockedOnThisPlatform(_ProviderSpec p) {
    if (kIsWeb) return true;
    if (p.name == 'Google Health Connect') return Platform.isIOS;
    if (p.name == 'Apple Health') return Platform.isAndroid;
    return false;
  }

  void _onConnectProvider(BuildContext context, _ProviderSpec p) {
    analytics.logEvent('wearable_connect_tapped', params: {
      'provider': p.name,
      'available_now': _isAvailableNow(p),
    });
    if (_isAvailableNow(p) && healthSyncService.isSupported) {
      _connectViaHealthBridge(context, p);
      return;
    }
    _showProviderDialog(context, p);
  }

  Future<void> _connectViaHealthBridge(BuildContext context, _ProviderSpec p) async {
    analytics.logEvent('wearable_connect_started', params: {'provider': p.name});
    final granted = await healthSyncService.requestPermissions();
    if (!context.mounted) return;
    if (!granted) {
      analytics.logEvent('wearable_connect_denied', params: {'provider': p.name});
      _showPermissionDeniedDialog(context, p);
      return;
    }
    analytics.logEvent('wearable_connect_granted', params: {'provider': p.name});
    // State local: marca conectado imediatamente pra UI refletir antes do sync.
    if (mounted) {
      setState(() {
        if (p.name == 'Apple Health') _appleHealthConnected = true;
        if (p.name == 'Google Health Connect') _googleHealthConnected = true;
      });
    }
    // Persiste hasWearable=true no perfil (PATCH /v1/users/me). Sem isso, na
    // próxima reabertura da página o card volta pra "Conectar" porque o
    // plugin (iOS) sempre retorna null em hasPermissions e o profile manda
    // hasWearable=false como source de verdade. Best-effort — falha não
    // bloqueia a UX local.
    unawaited(_persistHasWearable());
    // Permissão OK → sincroniza últimos 7d em background.
    healthSyncService.syncSince().then((count) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count amostras sincronizadas de ${p.name}.'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Conectado a ${p.name}. Sincronizando dados…'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showPermissionDeniedDialog(BuildContext context, _ProviderSpec p) {
    final isApple = p.name == 'Apple Health';
    // No Android, Health Connect tem rate-limit: depois de 2 negações o
    // requestAuthorization vira no-op (retorna false sem abrir sheet).
    // Por isso o caminho real é o user ir nas Configurações do Health
    // Connect e marcar manualmente — "Tentar de novo" só re-disparava
    // o mesmo dialog em loop. Em iOS, o caminho é Ajustes > Saúde.
    final body = isApple
        ? 'Pra ler seus dados do ${p.name}, libere o acesso em '
            'Ajustes > Privacidade e Segurança > Saúde > runnin. '
            'Depois reabra esta tela.'
        : 'Pra ler seus dados do ${p.name}, abra o Health Connect '
            'e libere as permissões pro runnin. Depois reabra esta tela.';
    showDialog(
      context: context,
      // bgBase é sólido (0xFF050510). surfaceCard antigo era 3% opacidade
      // branca — sobre o backdrop escuro o dialog ficava quase invisível.
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FigmaColors.bgBase,
        title: Text(
          'Permissão negada',
          style: context.runninType.bodyMd.copyWith(
            fontWeight: FontWeight.w500,
            color: FigmaColors.textPrimary,
          ),
        ),
        content: Text(
          body,
          style: context.runninType.bodySm.copyWith(
            height: 1.5,
            color: FigmaColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancelar',
              style: context.runninType.labelMd.copyWith(
                color: FigmaColors.textSecondary,
              ),
            ),
          ),
          // Android: deeplink direto pra tela de permissões do Health Connect
          // via WorkoutRealtimePlugin.kt. iOS não tem deeplink — usuário
          // segue a instrução do body manualmente.
          if (!isApple)
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final opened = await _openHealthConnectSettings();
                if (!context.mounted) return;
                if (!opened) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Não foi possível abrir o Health Connect. '
                        'Instale ou atualize pela Play Store.',
                      ),
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
              child: Text(
                'Abrir Health Connect',
                style: context.runninType.labelMd.copyWith(
                  color: context.runninPalette.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Bridge pro method nativo Android `openHealthConnectSettings` no
  /// [WorkoutRealtimePlugin.kt]. Tenta deeplink HC instalado, depois HC
  /// builtin (Android 14+), depois Play Store. Retorna `true` se abriu
  /// qualquer um.
  static const _nativeChannel = MethodChannel('runnin/workout_realtime');
  Future<bool> _openHealthConnectSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final result =
          await _nativeChannel.invokeMethod<bool>('openHealthConnectSettings');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  void _showProviderDialog(BuildContext context, _ProviderSpec p) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FigmaColors.surfaceCard,
        title: Text(
          'Em breve: ${p.name}',
          style: context.runninType.bodyMd.copyWith(
            fontWeight: FontWeight.w500,
            color: FigmaColors.textPrimary,
          ),
        ),
        content: Text(
          'A integração direta com ${p.name} (via OAuth do fabricante) ainda '
          'está em desenvolvimento. Enquanto isso, se o seu dispositivo '
          'sincroniza dados com a Apple Health ou Google Health Connect, '
          'você já pode importar BPM, sono e passos por essas plataformas.',
          style: context.runninType.bodySm.copyWith(
            height: 1.5,
            color: FigmaColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'OK',
              style: context.runninType.labelMd.copyWith(
                color: context.runninPalette.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: context.runninType.labelCaps.copyWith(
        color: FigmaColors.textMuted,
        fontWeight: FontWeight.w500,
        letterSpacing: FigmaDimensions.borderUniversal,
      ),
    );
  }
}

class _EmptyConnectedState extends StatelessWidget {
  const _EmptyConnectedState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(
          color: FigmaColors.borderDefault,
          width: 1.041,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.health_and_safety_outlined,
                size: 22,
                color: FigmaColors.textMuted,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Text(
                  'NENHUMA PLATAFORMA',
                  style: context.runninType.labelMd.copyWith(
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w500,
                    color: FigmaColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Conecte a Apple Health (iOS) ou o Google Health Connect (Android) '
            'abaixo para importar BPM, sono e passos do seu relógio ou celular.',
            style: context.runninType.bodyXs.copyWith(
              height: 1.5,
              color: FigmaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Painel "STATUS DE PERMISSÕES" da página perfil/saúde/wearable.
/// Estados:
///   - data == null && !loading: estado inicial; mostra só botão "VERIFICAR"
///   - loading: spinner
///   - data != null: lista com per-type ✓/✗ + CTAs "Solicitar novamente" e
///     (iOS) "Abrir Configurações"
class _PermissionsPanel extends StatelessWidget {
  final Map<String, bool>? data;
  final bool loading;
  final Future<void> Function() onCheck;
  final Future<void> Function() onRequestAgain;
  final Future<void> Function()? onOpenSettings;
  /// Botão separado pra abrir Saúde (instruções) — quando iOS, mostra dialog
  /// com caminho manual porque Apple não permite deep link direto.
  final Future<void> Function()? onOpenHealth;

  const _PermissionsPanel({
    required this.data,
    required this.loading,
    required this.onCheck,
    required this.onRequestAgain,
    required this.onOpenSettings,
    required this.onOpenHealth,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (!kIsWeb && Platform.isAndroid)
                ? 'Verifica as permissões concedidas ao app no Health Connect. '
                    'Tipos com ✗ não foram autorizados — toque em SOLICITAR NOVAMENTE.'
                : 'Verifica quais tipos de dados o app conseguiu LER nos últimos '
                    '7 dias. Tipos com ✗ podem estar sem permissão OU apenas sem '
                    'dado disponível no período (ambíguo, limitação da Apple).',
            style: context.runninType.bodyXs.copyWith(
              height: 1.5,
              color: FigmaColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (data == null && !loading)
            _PermissionsCtaButton(
              label: 'VERIFICAR',
              onTap: onCheck,
              primary: true,
            )
          else if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator(strokeWidth: 1.5)),
            )
          else
            ..._buildResultList(context, palette),
        ],
      ),
    );
  }

  List<Widget> _buildResultList(BuildContext context, dynamic palette) {
    final entries = data!.entries.toList();
    final granted = entries.where((e) => e.value).length;
    final missing = entries.length - granted;
    final allOk = missing == 0;

    return [
      // Resumo agregado: 1 linha grande, sem listar item por item.
      Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: allOk
              ? palette.primary.withValues(alpha: 0.08)
              : FigmaColors.borderDefault,
          border: Border.all(
            color: allOk ? palette.primary : FigmaColors.borderDefault,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              allOk ? Icons.check_circle_outline : Icons.error_outline,
              size: 20,
              color: allOk ? palette.primary : FigmaColors.textPrimary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allOk
                        ? 'Permissões em dia'
                        : '$missing ${missing == 1 ? "permissão pendente" : "permissões pendentes"}',
                    style: context.runninType.bodyMd.copyWith(
                      color: FigmaColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    allOk
                        ? '$granted/${entries.length} tipos liberados'
                        : 'Toque em SOLICITAR NOVAMENTE pra liberar os faltantes',
                    style: context.runninType.bodyXs.copyWith(
                      color: FigmaColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      if (!allOk) ...[
        _PermissionsCtaButton(
          label: 'SOLICITAR NOVAMENTE',
          onTap: onRequestAgain,
          primary: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        // Row de 2 botões secundários: Saúde (instruções) + Ajustes do app.
        if (onOpenHealth != null || onOpenSettings != null)
          Row(
            children: [
              if (onOpenHealth != null)
                Expanded(
                  child: _PermissionsCtaButton(
                    label: 'ABRIR SAÚDE',
                    onTap: onOpenHealth!,
                    primary: false,
                  ),
                ),
              if (onOpenHealth != null && onOpenSettings != null)
                const SizedBox(width: AppSpacing.sm),
              if (onOpenSettings != null)
                Expanded(
                  child: _PermissionsCtaButton(
                    label: 'AJUSTES DO APP',
                    onTap: onOpenSettings!,
                    primary: false,
                  ),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
      _PermissionsCtaButton(
        label: 'VERIFICAR DE NOVO',
        onTap: onCheck,
        primary: false,
      ),
    ];
  }
}

class _PermissionsCtaButton extends StatelessWidget {
  final String label;
  final Future<void> Function() onTap;
  final bool primary;

  const _PermissionsCtaButton({
    required this.label,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: () => onTap(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: primary ? palette.primary : FigmaColors.borderDefault,
            width: 1,
          ),
          color: primary ? Colors.transparent : Colors.transparent,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: context.runninType.labelCaps.copyWith(
            color: primary ? palette.primary : FigmaColors.textPrimary,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}

class _PlatformsHelperText extends StatelessWidget {
  const _PlatformsHelperText();

  @override
  Widget build(BuildContext context) {
    return Text(
      'A sincronização acontece pela plataforma de saúde do seu sistema — '
      'não conectamos diretamente ao relógio. Apple Health lê dados de Apple '
      'Watch e iPhone; Google Health Connect lê de Galaxy Watch, Mi Band e '
      'outros wearables compatíveis com Health Connect.',
      style: context.runninType.bodyXs.copyWith(
        height: 1.5,
        color: FigmaColors.textMuted,
      ),
    );
  }
}

class _ProviderSpec {
  final String name;
  final String metrics;
  final IconData icon;

  const _ProviderSpec({
    required this.name,
    required this.metrics,
    required this.icon,
  });
}

const _kCompatibleProviders = <_ProviderSpec>[
  // Plataformas de saúde — integração disponível hoje via plugin `health`
  // (HealthKit no iOS, Health Connect no Android). Lê dados dos relógios/
  // celulares que sincronizam com essas plataformas, não conecta direto.
  _ProviderSpec(
    name: 'Apple Health',
    metrics: 'iPhone, Apple Watch · BPM · Sono · Passos · HRV',
    icon: Icons.health_and_safety_outlined,
  ),
  _ProviderSpec(
    name: 'Google Health Connect',
    metrics: 'Galaxy, Mi Band e Android · BPM · Sono · Passos',
    icon: Icons.health_and_safety_outlined,
  ),
  // Integrações diretas (cloud-to-cloud via OAuth do fabricante) — em
  // desenvolvimento. Por enquanto, esses dispositivos só chegam se forem
  // sincronizados via Health Connect/Apple Health.
  _ProviderSpec(
    name: 'Garmin Connect',
    metrics: 'BPM · Sono · Passos · HRV (via OAuth)',
    icon: Icons.track_changes_outlined,
  ),
];
