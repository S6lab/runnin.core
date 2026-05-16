import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/admin/data/admin_file_picker.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _auth = FirebaseAuth.instance;
  final _storage = FirebaseStorage.instance;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _coachPromptCtrl = TextEditingController();
  final _coachVoiceCtrl = TextEditingController();
  final _coachLanguageCtrl = TextEditingController();
  final _coachSpeakingRateCtrl = TextEditingController();
  final _elevenLabsModelCtrl = TextEditingController();
  final _elevenLabsOutputCtrl = TextEditingController();
  final _elevenLabsBrunoCtrl = TextEditingController();
  final _elevenLabsClaraCtrl = TextEditingController();
  final _elevenLabsLunaCtrl = TextEditingController();

  static const _ragRootPath = 'rag/uploads';

  late final StreamSubscription<User?> _authSub;
  User? _user;
  AdminSession? _session;
  CoachAdminConfig? _coachConfig;
  List<RagStorageFile> _files = const [];
  bool _loadingSession = true;
  bool _loadingCoachConfig = false;
  bool _savingCoachConfig = false;
  bool _loadingFiles = false;
  bool _signingIn = false;
  bool _uploading = false;
  double? _uploadProgress;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    _authSub = _auth.authStateChanges().listen((user) {
      _user = user;
      unawaited(_loadSession());
    });
    unawaited(_loadSession());
  }

  @override
  void dispose() {
    _authSub.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _coachPromptCtrl.dispose();
    _coachVoiceCtrl.dispose();
    _coachLanguageCtrl.dispose();
    _coachSpeakingRateCtrl.dispose();
    _elevenLabsModelCtrl.dispose();
    _elevenLabsOutputCtrl.dispose();
    _elevenLabsBrunoCtrl.dispose();
    _elevenLabsClaraCtrl.dispose();
    _elevenLabsLunaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSession({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    setState(() {
      _loadingSession = true;
      _error = null;
      _message = null;
    });

    try {
      if (user == null || user.isAnonymous) {
        setState(() {
          _session = null;
          _files = const [];
        });
        return;
      }

      final token = await user.getIdTokenResult(forceRefresh);
      final session = AdminSession.fromClaims(user, token.claims ?? {});
      setState(() => _session = session);

      if (session.canRead) {
        await Future.wait([_loadFiles(), _loadCoachConfig()]);
      } else {
        setState(() => _files = const []);
      }
    } catch (_) {
      setState(() => _error = 'Nao foi possivel validar sua permissao.');
    } finally {
      if (mounted) setState(() => _loadingSession = false);
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.length < 6) {
      setState(
        () => _error = 'Informe e-mail e senha com pelo menos 6 caracteres.',
      );
      return;
    }

    setState(() {
      _signingIn = true;
      _error = null;
      _message = null;
    });

    try {
      if (_auth.currentUser?.isAnonymous == true) {
        await _auth.signOut();
      }

      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _loadSession(forceRefresh: true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } catch (_) {
      setState(() => _error = 'Nao foi possivel entrar agora.');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _signingIn = true;
      _error = null;
      _message = null;
    });

    try {
      if (_auth.currentUser?.isAnonymous == true) {
        await _auth.signOut();
      }

      if (kIsWeb) {
        await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        setState(() {
          _error = 'Login Google do admin esta disponivel no web app.';
        });
        return;
      }

      await _loadSession(forceRefresh: true);
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } catch (_) {
      setState(() => _error = 'Nao foi possivel entrar com Google agora.');
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    setState(() {
      _session = null;
      _files = const [];
      _message = null;
      _error = null;
    });
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loadingFiles = true;
      _error = null;
    });

    try {
      final root = _storage.ref(_ragRootPath);
      final result = await root.listAll();
      final files = <RagStorageFile>[];

      for (final item in result.items) {
        try {
          final metadata = await item.getMetadata();
          files.add(RagStorageFile.fromMetadata(item, metadata));
        } catch (_) {
          files.add(RagStorageFile(path: item.fullPath, name: item.name));
        }
      }

      files.sort((a, b) {
        final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      if (mounted) setState(() => _files = files);
    } on FirebaseException catch (e) {
      setState(() => _error = _storageError(e));
    } catch (_) {
      setState(() => _error = 'Nao foi possivel listar os arquivos.');
    } finally {
      if (mounted) setState(() => _loadingFiles = false);
    }
  }

  Future<void> _loadCoachConfig() async {
    setState(() => _loadingCoachConfig = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('coach')
          .get();
      final config = CoachAdminConfig.fromFirestore(doc.data());
      _coachPromptCtrl.text = config.livePrompt;
      _coachVoiceCtrl.text = config.ttsVoiceName;
      _coachLanguageCtrl.text = config.ttsLanguageCode;
      _coachSpeakingRateCtrl.text = config.ttsSpeakingRate.toStringAsFixed(2);
      _elevenLabsModelCtrl.text = config.elevenLabsModelId;
      _elevenLabsOutputCtrl.text = config.elevenLabsOutputFormat;
      _elevenLabsBrunoCtrl.text =
          config.elevenLabsVoiceIds['coach-bruno'] ?? '';
      _elevenLabsClaraCtrl.text =
          config.elevenLabsVoiceIds['coach-clara'] ?? '';
      _elevenLabsLunaCtrl.text = config.elevenLabsVoiceIds['coach-luna'] ?? '';
      if (mounted) {
        setState(() => _coachConfig = config);
      }
    } catch (e, st) {
      debugPrint('Error loading coach config: $e\n$st');
      if (mounted) {
        setState(() => _error = 'Nao foi possivel carregar o prompt do coach: $e');
      }
    } finally {
      if (mounted) setState(() => _loadingCoachConfig = false);
    }
  }

  Future<void> _saveCoachConfig(CoachTtsAdminDraft ttsDraft) async {
    final session = _session;
    if (session == null) {
      setState(() => _error = 'Sesao expirada. Faca login novamente.');
      return;
    }
    if (!session.canUpload) {
      setState(() => _error = 'Voce nao tem permissao para editar configuracoes.');
      return;
    }

    final prompt = _coachPromptCtrl.text.trim();
    if (prompt.isEmpty) {
      setState(() => _error = 'O prompt do coach nao pode ficar vazio.');
      return;
    }

    final speakingRate =
        double.tryParse(
          _coachSpeakingRateCtrl.text.trim().replaceAll(',', '.'),
        ) ??
        1.08;

    setState(() {
      _savingCoachConfig = true;
      _error = null;
      _message = null;
    });

    try {
      final data = {
        'livePrompt': prompt,
        'ttsEnabled': ttsDraft.ttsEnabled,
        'ttsProvider': ttsDraft.ttsProvider,
        'ttsVoiceName': _coachVoiceCtrl.text.trim().isEmpty
            ? 'pt-BR-Neural2-B'
            : _coachVoiceCtrl.text.trim(),
        'ttsLanguageCode': _coachLanguageCtrl.text.trim().isEmpty
            ? 'pt-BR'
            : _coachLanguageCtrl.text.trim(),
        'ttsSpeakingRate': speakingRate.clamp(0.25, 2.0),
        'elevenLabsModelId': _elevenLabsModelCtrl.text.trim().isEmpty
            ? 'eleven_multilingual_v2'
            : _elevenLabsModelCtrl.text.trim(),
        'elevenLabsOutputFormat': _elevenLabsOutputCtrl.text.trim().isEmpty
            ? 'mp3_44100_128'
            : _elevenLabsOutputCtrl.text.trim(),
        'elevenLabsVoiceIds': {
          'coach-bruno': _elevenLabsBrunoCtrl.text.trim(),
          'coach-clara': _elevenLabsClaraCtrl.text.trim(),
          'coach-luna': _elevenLabsLunaCtrl.text.trim(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedByUid': session.uid,
        'updatedByEmail': session.email,
      };
      await FirebaseFirestore.instance
          .collection('app_config')
          .doc('coach')
          .set(data, SetOptions(merge: true));
      await _loadCoachConfig();
      setState(() => _message = 'Prompt do coach atualizado.');
    } on FirebaseException catch (e) {
      debugPrint('Firestore save error: ${e.code} - ${e.message}');
      setState(() => _error = 'Erro ao salvar: ${e.message}');
    } catch (e, st) {
      debugPrint('Save coach config error: $e\n$st');
      setState(() => _error = 'Erro ao salvar configuracao: $e');
    } finally {
      if (mounted) setState(() => _savingCoachConfig = false);
    }
  }

  Future<void> _uploadFile() async {
    final session = _session;
    if (session == null) {
      setState(() => _error = 'Sesao expirada. Faca login novamente.');
      return;
    }
    if (!session.canUpload) {
      setState(() => _error = 'Voce nao tem permissao para fazer upload de arquivos.');
      return;
    }

    const allowedExtensions = [
      'pdf',
      'txt',
      'md',
      'csv',
      'json',
      'doc',
      'docx',
    ];

    final file = await pickAdminFile(allowedExtensions);
    if (file == null) return;

    final extension = file.extension;
    if (!allowedExtensions.contains(extension)) {
      setState(() => _error = 'Formato de arquivo nao suportado.');
      return;
    }

    final bytes = file.bytes;
    final safeName = _safeStorageName(file.name);
    final now = DateTime.now().toUtc();
    final path =
        '$_ragRootPath/${now.toIso8601String().replaceAll(':', '-')}_$safeName';
    final ref = _storage.ref(path);

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
      _error = null;
      _message = null;
    });

    try {
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(
          contentType: _contentTypeFor(file.extension),
          customMetadata: {
            'originalName': file.name,
            'uploadedByUid': session.uid,
            'uploadedByEmail': session.email ?? '',
            'uploadedByRole': session.role,
            'ragStatus': 'pending',
            'source': 'admin-panel',
          },
        ),
      );

      uploadTask.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        if (total <= 0) return;
        if (mounted) {
          setState(() => _uploadProgress = snapshot.bytesTransferred / total);
        }
      });

      await uploadTask;
      await _writeOptionalIndex(path, file.name, file.size, session);
      await _loadFiles();

      setState(() => _message = 'Arquivo enviado para a base RAG.');
    } on FirebaseException catch (e) {
      debugPrint('Firebase upload error: ${e.code} - ${e.message}');
      setState(() => _error = _storageError(e));
    } catch (e, st) {
      debugPrint('Upload error: $e\n$st');
      setState(() => _error = 'Falha ao fazer upload: $e');
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _deleteFile(RagStorageFile file) async {
    final session = _session;
    if (session == null || !session.canDelete) return;

    setState(() {
      _error = null;
      _message = null;
    });

    try {
      await _storage.ref(file.path).delete();
      await FirebaseFirestore.instance
          .collection('rag_documents')
          .doc(file.path.replaceAll('/', '__'))
          .delete()
          .catchError((_) {});
      await _loadFiles();
      setState(() => _message = 'Arquivo removido.');
    } on FirebaseException catch (e) {
      setState(() => _error = _storageError(e));
    } catch (_) {
      setState(() => _error = 'Nao foi possivel remover o arquivo.');
    }
  }

  Future<void> _writeOptionalIndex(
    String path,
    String name,
    int size,
    AdminSession session,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('rag_documents')
          .doc(path.replaceAll('/', '__'))
          .set({
            'path': path,
            'name': name,
            'size': size,
            'status': 'pending',
            'uploadedByUid': session.uid,
            'uploadedByEmail': session.email,
            'uploadedByRole': session.role,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      // O Storage e seus metadados continuam sendo a fonte minima para o RAG.
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'O e-mail informado nao e valido.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha invalidos.';
      case 'popup-closed-by-user':
        return 'Login cancelado.';
      case 'operation-not-allowed':
        return 'Habilite este metodo de login no Firebase Auth.';
      default:
        return 'Nao foi possivel autenticar este usuario.';
    }
  }

  String _storageError(FirebaseException e) {
    if (e.code == 'unauthorized') {
      return 'Seu usuario nao tem permissao para acessar estes arquivos.';
    }
    if (e.code == 'object-not-found') return 'Arquivo nao encontrado.';
    return 'Erro do Firebase Storage: ${e.code}.';
  }

  String _safeStorageName(String name) {
    final normalized = name.trim().replaceAll(RegExp(r'\s+'), '_');
    final safe = normalized.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-');
    return safe.isEmpty ? 'documento' : safe;
  }

  String _contentTypeFor(String? extension) {
    switch (extension?.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'md':
        return 'text/markdown';
      case 'csv':
        return 'text/csv';
      case 'json':
        return 'application/json';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final session = _session;
    final needsLogin = _user == null || _user?.isAnonymous == true;
    final blocked = !needsLogin && session != null && !session.canRead;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AdminHeader(
                    session: session,
                    loading: _loadingSession,
                    onRefreshClaims: () => _loadSession(forceRefresh: true),
                    onSignOut: _signOut,
                  ),
                  const SizedBox(height: 18),
                  if (_error != null)
                    _Notice(text: _error!, tone: _NoticeTone.error),
                  if (_message != null)
                    _Notice(text: _message!, tone: _NoticeTone.success),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: needsLogin
                          ? _LoginPanel(
                              key: const ValueKey('login'),
                              emailCtrl: _emailCtrl,
                              passwordCtrl: _passwordCtrl,
                              loading: _signingIn,
                              onEmailLogin: _signInWithEmail,
                              onGoogleLogin: _signInWithGoogle,
                            )
                          : _loadingSession && session == null
                          ? const Center(child: CircularProgressIndicator())
                          : blocked
                          ? _BlockedPanel(
                              key: const ValueKey('blocked'),
                              email: _user?.email,
                              onSignOut: _signOut,
                              onRefresh: () => _loadSession(forceRefresh: true),
                            )
                          : _DrivePanel(
                              key: const ValueKey('drive'),
                              coachConfig: _coachConfig,
                              coachPromptCtrl: _coachPromptCtrl,
                              coachVoiceCtrl: _coachVoiceCtrl,
                              coachLanguageCtrl: _coachLanguageCtrl,
                              coachSpeakingRateCtrl: _coachSpeakingRateCtrl,
                              elevenLabsModelCtrl: _elevenLabsModelCtrl,
                              elevenLabsOutputCtrl: _elevenLabsOutputCtrl,
                              elevenLabsBrunoCtrl: _elevenLabsBrunoCtrl,
                              elevenLabsClaraCtrl: _elevenLabsClaraCtrl,
                              elevenLabsLunaCtrl: _elevenLabsLunaCtrl,
                              session: session!,
                              files: _files,
                              loadingCoachConfig: _loadingCoachConfig,
                              savingCoachConfig: _savingCoachConfig,
                              loadingFiles: _loadingFiles,
                              uploading: _uploading,
                              uploadProgress: _uploadProgress,
                              onReloadCoachConfig: _loadCoachConfig,
                              onSaveCoachConfig: _saveCoachConfig,
                              onUpload: _uploadFile,
                              onRefresh: _loadFiles,
                              onDelete: _deleteFile,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminSession {
  final String uid;
  final String? email;
  final String role;
  final bool canRead;
  final bool canUpload;
  final bool canDelete;

  const AdminSession({
    required this.uid,
    required this.email,
    required this.role,
    required this.canRead,
    required this.canUpload,
    required this.canDelete,
  });

  factory AdminSession.fromClaims(User user, Map<String, dynamic> claims) {
    final rawRole = claims['role'] ?? claims['adminRole'];
    final roles = claims['roles'];
    final hasAdminFlag = claims['admin'] == true;
    final role = rawRole is String
        ? rawRole
        : hasAdminFlag
        ? 'admin'
        : roles is Iterable && roles.contains('editor')
        ? 'editor'
        : roles is Iterable && roles.contains('admin')
        ? 'admin'
        : 'none';

    final normalized = role.toLowerCase();
    final isAdmin = hasAdminFlag || normalized == 'admin';
    final isEditor = normalized == 'editor';

    return AdminSession(
      uid: user.uid,
      email: user.email,
      role: isAdmin
          ? 'admin'
          : isEditor
          ? 'editor'
          : normalized,
      canRead: isAdmin || isEditor,
      canUpload: isAdmin || isEditor,
      canDelete: isAdmin,
    );
  }
}

class RagStorageFile {
  final String path;
  final String name;
  final int? size;
  final String? contentType;
  final DateTime? updatedAt;
  final String? uploadedByEmail;
  final String? ragStatus;

  const RagStorageFile({
    required this.path,
    required this.name,
    this.size,
    this.contentType,
    this.updatedAt,
    this.uploadedByEmail,
    this.ragStatus,
  });

  factory RagStorageFile.fromMetadata(Reference ref, FullMetadata metadata) {
    return RagStorageFile(
      path: ref.fullPath,
      name: metadata.customMetadata?['originalName'] ?? ref.name,
      size: metadata.size,
      contentType: metadata.contentType,
      updatedAt: metadata.updated,
      uploadedByEmail: metadata.customMetadata?['uploadedByEmail'],
      ragStatus: metadata.customMetadata?['ragStatus'],
    );
  }
}

class CoachAdminConfig {
  final String livePrompt;
  final bool ttsEnabled;
  final String ttsProvider;
  final String ttsVoiceName;
  final String ttsLanguageCode;
  final double ttsSpeakingRate;
  final String elevenLabsModelId;
  final String elevenLabsOutputFormat;
  final Map<String, String> elevenLabsVoiceIds;

  const CoachAdminConfig({
    required this.livePrompt,
    required this.ttsEnabled,
    required this.ttsProvider,
    required this.ttsVoiceName,
    required this.ttsLanguageCode,
    required this.ttsSpeakingRate,
    required this.elevenLabsModelId,
    required this.elevenLabsOutputFormat,
    required this.elevenLabsVoiceIds,
  });

  factory CoachAdminConfig.fromFirestore(Map<String, dynamic>? data) {
    return CoachAdminConfig(
      livePrompt: _stringValue(data?['livePrompt']) ?? _defaultCoachPrompt,
      ttsEnabled: data?['ttsEnabled'] is bool
          ? data!['ttsEnabled'] as bool
          : true,
      ttsProvider: data?['ttsProvider'] == 'elevenlabs'
          ? 'elevenlabs'
          : 'google',
      ttsVoiceName: _stringValue(data?['ttsVoiceName']) ?? 'pt-BR-Neural2-B',
      ttsLanguageCode: _stringValue(data?['ttsLanguageCode']) ?? 'pt-BR',
      ttsSpeakingRate: data?['ttsSpeakingRate'] is num
          ? (data!['ttsSpeakingRate'] as num).toDouble()
          : 1.08,
      elevenLabsModelId:
          _stringValue(data?['elevenLabsModelId']) ?? 'eleven_multilingual_v2',
      elevenLabsOutputFormat:
          _stringValue(data?['elevenLabsOutputFormat']) ?? 'mp3_44100_128',
      elevenLabsVoiceIds: _stringMap(data?['elevenLabsVoiceIds']),
    );
  }
}

class CoachTtsAdminDraft {
  final bool ttsEnabled;
  final String ttsProvider;

  const CoachTtsAdminDraft({
    required this.ttsEnabled,
    required this.ttsProvider,
  });
}

const _defaultCoachPrompt =
    'Você é o Coach.AI do runnin: um personal trainer de corrida experiente, presente e direto.\n'
    'Use todo o contexto disponível: perfil, objetivo, plano, histórico recente, sessão atual, pace e frequência cardíaca quando houver.\n'
    'Antes da corrida, prepare o atleta para executar o treino do dia com foco claro.\n'
    'Durante a corrida, guie como um treinador ao lado: incentive, corrija pace, observe BPM quando disponível e ajuste a orientação ao objetivo.\n'
    'Tom humano, firme, motivador e prático. Máximo 2 frases curtas. Sem emojis. A resposta deve caber em até 10 segundos de áudio.';

String? _stringValue(Object? value) {
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

Map<String, String> _stringMap(Object? value) {
  if (value is! Map) return const {};
  return value.map(
    (key, item) => MapEntry(key.toString(), item?.toString() ?? ''),
  );
}

class _AdminHeader extends StatelessWidget {
  final AdminSession? session;
  final bool loading;
  final VoidCallback onRefreshClaims;
  final VoidCallback onSignOut;

  const _AdminHeader({
    required this.session,
    required this.loading,
    required this.onRefreshClaims,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'RUNNIN ADMIN',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Arquivos de conhecimento para RAG',
                style: TextStyle(color: palette.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        if (session != null) ...[
          _RolePill(role: session!.role),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Atualizar permissoes',
            onPressed: loading ? null : onRefreshClaims,
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ],
    );
  }
}

class _LoginPanel extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool loading;
  final VoidCallback onEmailLogin;
  final VoidCallback onGoogleLogin;

  const _LoginPanel({
    super.key,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.loading,
    required this.onEmailLogin,
    required this.onGoogleLogin,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Acesso administrativo',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'E-mail'),
                onSubmitted: (_) => onEmailLogin(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(labelText: 'Senha'),
                onSubmitted: (_) => onEmailLogin(),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: loading ? null : onEmailLogin,
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open),
                  label: const Text('ENTRAR'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: loading ? null : onGoogleLogin,
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('GOOGLE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedPanel extends StatelessWidget {
  final String? email;
  final VoidCallback onSignOut;
  final VoidCallback onRefresh;

  const _BlockedPanel({
    super.key,
    required this.email,
    required this.onSignOut,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border.all(color: palette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.admin_panel_settings_outlined, size: 44),
              const SizedBox(height: 14),
              Text(
                'Sem permissao para o painel',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                email ?? 'Usuario autenticado',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.muted),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.sync),
                    label: const Text('ATUALIZAR'),
                  ),
                  TextButton.icon(
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('SAIR'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrivePanel extends StatelessWidget {
  final CoachAdminConfig? coachConfig;
  final TextEditingController coachPromptCtrl;
  final TextEditingController coachVoiceCtrl;
  final TextEditingController coachLanguageCtrl;
  final TextEditingController coachSpeakingRateCtrl;
  final TextEditingController elevenLabsModelCtrl;
  final TextEditingController elevenLabsOutputCtrl;
  final TextEditingController elevenLabsBrunoCtrl;
  final TextEditingController elevenLabsClaraCtrl;
  final TextEditingController elevenLabsLunaCtrl;
  final AdminSession session;
  final List<RagStorageFile> files;
  final bool loadingCoachConfig;
  final bool savingCoachConfig;
  final bool loadingFiles;
  final bool uploading;
  final double? uploadProgress;
  final VoidCallback onReloadCoachConfig;
  final ValueChanged<CoachTtsAdminDraft> onSaveCoachConfig;
  final VoidCallback onUpload;
  final VoidCallback onRefresh;
  final ValueChanged<RagStorageFile> onDelete;

  const _DrivePanel({
    super.key,
    required this.coachConfig,
    required this.coachPromptCtrl,
    required this.coachVoiceCtrl,
    required this.coachLanguageCtrl,
    required this.coachSpeakingRateCtrl,
    required this.elevenLabsModelCtrl,
    required this.elevenLabsOutputCtrl,
    required this.elevenLabsBrunoCtrl,
    required this.elevenLabsClaraCtrl,
    required this.elevenLabsLunaCtrl,
    required this.session,
    required this.files,
    required this.loadingCoachConfig,
    required this.savingCoachConfig,
    required this.loadingFiles,
    required this.uploading,
    required this.uploadProgress,
    required this.onReloadCoachConfig,
    required this.onSaveCoachConfig,
    required this.onUpload,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PromptsConsoleEntry(canRead: session.canRead),
        const SizedBox(height: 8),
        _CoachPromptPanel(
          config: coachConfig,
          promptCtrl: coachPromptCtrl,
          voiceCtrl: coachVoiceCtrl,
          languageCtrl: coachLanguageCtrl,
          speakingRateCtrl: coachSpeakingRateCtrl,
          elevenLabsModelCtrl: elevenLabsModelCtrl,
          elevenLabsOutputCtrl: elevenLabsOutputCtrl,
          elevenLabsBrunoCtrl: elevenLabsBrunoCtrl,
          elevenLabsClaraCtrl: elevenLabsClaraCtrl,
          elevenLabsLunaCtrl: elevenLabsLunaCtrl,
          loading: loadingCoachConfig,
          saving: savingCoachConfig,
          canEdit: session.canUpload,
          onReload: onReloadCoachConfig,
          onSave: onSaveCoachConfig,
        ),
        const SizedBox(height: 14),
        Expanded(
          child: _FilesSection(
            files: files,
            session: session,
            loadingFiles: loadingFiles,
            uploading: uploading,
            uploadProgress: uploadProgress,
            onUpload: onUpload,
            onRefresh: onRefresh,
            onDelete: onDelete,
          ),
        ),
      ],
    );
  }
}

// ───────────────────────────── Prompts console entry ──────────────────────

class _PromptsConsoleEntry extends StatelessWidget {
  final bool canRead;
  const _PromptsConsoleEntry({required this.canRead});

  @override
  Widget build(BuildContext context) {
    if (!canRead) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: ListTile(
        leading: const Icon(Icons.tune),
        title: const Text('Prompts & Personas'),
        subtitle: const Text('Editar prompts dos 7 momentos LLM, personas do coach, knobs do decision layer'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => GoRouter.of(context).push('/admin/prompts'),
      ),
    );
  }
}

// ───────────────────────────── Files (Drive-style) ─────────────────────────

class _FilesSection extends StatefulWidget {
  final List<RagStorageFile> files;
  final AdminSession session;
  final bool loadingFiles;
  final bool uploading;
  final double? uploadProgress;
  final VoidCallback onUpload;
  final VoidCallback onRefresh;
  final ValueChanged<RagStorageFile> onDelete;

  const _FilesSection({
    required this.files,
    required this.session,
    required this.loadingFiles,
    required this.uploading,
    required this.uploadProgress,
    required this.onUpload,
    required this.onRefresh,
    required this.onDelete,
  });

  @override
  State<_FilesSection> createState() => _FilesSectionState();
}

class _FilesSectionState extends State<_FilesSection> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<RagStorageFile> get _filtered {
    if (_query.isEmpty) return widget.files;
    final q = _query.toLowerCase();
    return widget.files
        .where((f) =>
            f.name.toLowerCase().contains(q) ||
            (f.uploadedByEmail ?? '').toLowerCase().contains(q) ||
            (f.ragStatus ?? '').toLowerCase().contains(q))
        .toList();
  }

  int get _totalBytes =>
      widget.files.fold<int>(0, (acc, f) => acc + (f.size ?? 0));

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final filtered = _filtered;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          // Toolbar header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, color: palette.primary, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Base RAG',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${widget.files.length} ${widget.files.length == 1 ? "arquivo" : "arquivos"} · ${_formatBytes(_totalBytes)}',
                  style: TextStyle(color: palette.muted, fontSize: 12),
                ),
                const Spacer(),
                SizedBox(
                  width: 240,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                      hintText: 'Filtrar por nome, autor, status…',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Atualizar lista',
                  onPressed: widget.loadingFiles ? null : widget.onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
                const SizedBox(width: 4),
                ElevatedButton.icon(
                  onPressed:
                      widget.uploading || !widget.session.canUpload ? null : widget.onUpload,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('UPLOAD'),
                ),
              ],
            ),
          ),
          if (widget.uploading)
            LinearProgressIndicator(value: widget.uploadProgress, minHeight: 2),
          Divider(height: 1, color: palette.border),
          // List or empty
          Expanded(
            child: widget.loadingFiles && widget.files.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : widget.files.isEmpty
                    ? _EmptyFiles(onUpload: widget.onUpload)
                    : filtered.isEmpty
                        ? _NoSearchResults(query: _query)
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                Divider(height: 1, color: palette.border),
                            itemBuilder: (context, index) {
                              final file = filtered[index];
                              return _FileRow(
                                file: file,
                                canDelete: widget.session.canDelete,
                                onDelete: () => widget.onDelete(file),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int? size) {
  if (size == null) return '—';
  if (size < 1024) return '$size B';
  if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
  if (size < 1024 * 1024 * 1024) {
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

class _NoSearchResults extends StatelessWidget {
  final String query;
  const _NoSearchResults({required this.query});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off, size: 36, color: palette.muted),
          const SizedBox(height: 8),
          Text(
            'Nenhum arquivo encontrado para "$query"',
            style: TextStyle(color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _CoachPromptPanel extends StatefulWidget {
  final CoachAdminConfig? config;
  final TextEditingController promptCtrl;
  final TextEditingController voiceCtrl;
  final TextEditingController languageCtrl;
  final TextEditingController speakingRateCtrl;
  final TextEditingController elevenLabsModelCtrl;
  final TextEditingController elevenLabsOutputCtrl;
  final TextEditingController elevenLabsBrunoCtrl;
  final TextEditingController elevenLabsClaraCtrl;
  final TextEditingController elevenLabsLunaCtrl;
  final bool loading;
  final bool saving;
  final bool canEdit;
  final VoidCallback onReload;
  final ValueChanged<CoachTtsAdminDraft> onSave;

  const _CoachPromptPanel({
    required this.config,
    required this.promptCtrl,
    required this.voiceCtrl,
    required this.languageCtrl,
    required this.speakingRateCtrl,
    required this.elevenLabsModelCtrl,
    required this.elevenLabsOutputCtrl,
    required this.elevenLabsBrunoCtrl,
    required this.elevenLabsClaraCtrl,
    required this.elevenLabsLunaCtrl,
    required this.loading,
    required this.saving,
    required this.canEdit,
    required this.onReload,
    required this.onSave,
  });

  @override
  State<_CoachPromptPanel> createState() => _CoachPromptPanelState();
}

class _CoachPromptPanelState extends State<_CoachPromptPanel> {
  late bool _ttsEnabled = widget.config?.ttsEnabled ?? true;
  late String _ttsProvider = widget.config?.ttsProvider ?? 'google';

  @override
  void didUpdateWidget(covariant _CoachPromptPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config?.ttsEnabled != widget.config?.ttsEnabled) {
      _ttsEnabled = widget.config?.ttsEnabled ?? true;
    }
    if (oldWidget.config?.ttsProvider != widget.config?.ttsProvider) {
      _ttsProvider = widget.config?.ttsProvider ?? 'google';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.primary.withValues(alpha: 0.28)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Coach ao vivo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Recarregar prompt',
                onPressed: widget.loading ? null : widget.onReload,
                icon: const Icon(Icons.refresh),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: widget.saving || !widget.canEdit
                    ? null
                    : () => widget.onSave(
                        CoachTtsAdminDraft(
                          ttsEnabled: _ttsEnabled,
                          ttsProvider: _ttsProvider,
                        ),
                      ),
                icon: widget.saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('SALVAR'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'O prompt do coach ao vivo agora é editado em Prompts & Personas → live-coach. Este painel mantém apenas as configurações de TTS.',
                    style: TextStyle(fontSize: 12, color: palette.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _ttsProvider,
                  items: const [
                    DropdownMenuItem(
                      value: 'google',
                      child: Text('Google TTS'),
                    ),
                    DropdownMenuItem(
                      value: 'elevenlabs',
                      child: Text('ElevenLabs'),
                    ),
                  ],
                  onChanged: widget.canEdit
                      ? (value) =>
                            setState(() => _ttsProvider = value ?? 'google')
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Provedor de voz',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: _ttsEnabled,
                    onChanged: widget.canEdit
                        ? (value) => setState(() => _ttsEnabled = value)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  Text('TTS', style: context.runninType.labelCaps),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: widget.voiceCtrl,
                  enabled: widget.canEdit,
                  decoration: const InputDecoration(
                    labelText: 'Voz Google TTS',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.languageCtrl,
                  enabled: widget.canEdit,
                  decoration: const InputDecoration(labelText: 'Idioma'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.speakingRateCtrl,
                  enabled: widget.canEdit,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Velocidade'),
                ),
              ),
            ],
          ),
          if (_ttsProvider == 'elevenlabs') ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.elevenLabsModelCtrl,
                    enabled: widget.canEdit,
                    decoration: const InputDecoration(
                      labelText: 'Modelo ElevenLabs',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.elevenLabsOutputCtrl,
                    enabled: widget.canEdit,
                    decoration: const InputDecoration(
                      labelText: 'Formato de audio',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.elevenLabsBrunoCtrl,
                    enabled: widget.canEdit,
                    decoration: const InputDecoration(
                      labelText: 'Voice ID Bruno',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.elevenLabsClaraCtrl,
                    enabled: widget.canEdit,
                    decoration: const InputDecoration(
                      labelText: 'Voice ID Clara',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: widget.elevenLabsLunaCtrl,
                    enabled: widget.canEdit,
                    decoration: const InputDecoration(
                      labelText: 'Voice ID Luna',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FileRow extends StatefulWidget {
  final RagStorageFile file;
  final bool canDelete;
  final VoidCallback onDelete;

  const _FileRow({
    required this.file,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _hover = false;
  bool _busy = false;

  Future<void> _copyPath() async {
    await Clipboard.setData(ClipboardData(text: widget.file.path));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Caminho copiado'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _openInTab() async {
    setState(() => _busy = true);
    try {
      final url = await FirebaseStorage.instance.ref(widget.file.path).getDownloadURL();
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL de download copiada (cole no navegador)')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao gerar URL.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover arquivo?'),
        content: Text(
          '${widget.file.name}\n\nEsta ação não pode ser desfeita. Os chunks já indexados continuarão no RAG até a próxima rebuild.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: context.runninPalette.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final file = widget.file;
    final fileKind = _fileKindOf(file.contentType, file.name);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        color: _hover ? palette.surfaceAlt.withValues(alpha: 0.5) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            _FileIcon(kind: fileKind),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (file.ragStatus != null) _StatusPill(status: file.ragStatus!),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitleLine(file),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Inline actions — só visíveis no hover
            AnimatedOpacity(
              opacity: _hover ? 1 : 0.0,
              duration: const Duration(milliseconds: 120),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Copiar caminho do Storage',
                    onPressed: _copyPath,
                    icon: const Icon(Icons.link, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: 'Obter URL de download',
                    onPressed: _busy ? null : _openInTab,
                    icon: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          )
                        : const Icon(Icons.open_in_new, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (widget.canDelete)
                    IconButton(
                      tooltip: 'Remover arquivo',
                      onPressed: _confirmDelete,
                      icon: Icon(Icons.delete_outline, size: 18, color: palette.error),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitleLine(RagStorageFile file) {
    final parts = <String>[
      _formatBytes(file.size),
      if (file.updatedAt != null) _formatDate(file.updatedAt!),
      if (file.uploadedByEmail?.isNotEmpty == true) file.uploadedByEmail!,
    ].whereType<String>().toList();
    return parts.join(' · ');
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inHours < 1) return '${diff.inMinutes}min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }
}

enum _FileKind { pdf, doc, sheet, json, markdown, text, generic }

_FileKind _fileKindOf(String? contentType, String name) {
  final lower = name.toLowerCase();
  if (contentType == 'application/pdf' || lower.endsWith('.pdf')) return _FileKind.pdf;
  if (lower.endsWith('.doc') || lower.endsWith('.docx')) return _FileKind.doc;
  if (lower.endsWith('.csv')) return _FileKind.sheet;
  if (lower.endsWith('.json')) return _FileKind.json;
  if (lower.endsWith('.md') || lower.endsWith('.markdown')) return _FileKind.markdown;
  if (lower.endsWith('.txt')) return _FileKind.text;
  return _FileKind.generic;
}

class _FileIcon extends StatelessWidget {
  final _FileKind kind;
  const _FileIcon({required this.kind});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final (color, icon, label) = switch (kind) {
      _FileKind.pdf =>
        (const Color(0xFFEF4444), Icons.picture_as_pdf_outlined, 'PDF'),
      _FileKind.doc =>
        (const Color(0xFF3B82F6), Icons.description_outlined, 'DOC'),
      _FileKind.sheet =>
        (const Color(0xFF22C55E), Icons.table_chart_outlined, 'CSV'),
      _FileKind.json =>
        (palette.primary, Icons.data_object, 'JSON'),
      _FileKind.markdown =>
        (const Color(0xFF8B5CF6), Icons.notes_outlined, 'MD'),
      _FileKind.text =>
        (palette.muted, Icons.text_snippet_outlined, 'TXT'),
      _FileKind.generic =>
        (palette.muted, Icons.insert_drive_file_outlined, ''),
    };

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          if (label.isNotEmpty)
            Positioned(
              bottom: 1,
              right: 2,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final (color, label) = switch (status.toLowerCase()) {
      'pending' => (const Color(0xFFFB923C), 'PENDENTE'),
      'processed' || 'indexed' || 'done' || 'ready' =>
        (const Color(0xFF22C55E), 'INDEXADO'),
      'error' || 'failed' => (palette.error, 'ERRO'),
      _ => (palette.muted, status.toUpperCase()),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _EmptyFiles extends StatelessWidget {
  final VoidCallback onUpload;

  const _EmptyFiles({required this.onUpload});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    const formats = ['PDF', 'DOCX', 'DOC', 'TXT', 'MD', 'CSV', 'JSON'];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.10),
                border: Border.all(
                  color: palette.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.cloud_upload_outlined,
                size: 44,
                color: palette.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Base RAG vazia',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Faça upload de papers, protocolos ou guias.\nO Coach.AI usa esse conhecimento em todas as respostas.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.muted, height: 1.5),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: formats
                  .map((f) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: palette.surfaceAlt,
                          border: Border.all(color: palette.border),
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: palette.muted,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file),
              label: const Text('SELECIONAR ARQUIVO'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String role;

  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: palette.primary),
        color: palette.surfaceAlt,
      ),
      child: Text(
        role.toUpperCase(),
        style: TextStyle(
          color: palette.primary,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

enum _NoticeTone { error, success }

class _Notice extends StatelessWidget {
  final String text;
  final _NoticeTone tone;

  const _Notice({required this.text, required this.tone});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final color = tone == _NoticeTone.error ? palette.error : palette.success;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
