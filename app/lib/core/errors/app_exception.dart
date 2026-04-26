class AppException implements Exception {
  final String message;
  final String? code;
  AppException(this.message, {this.code});

  @override
  String toString() => 'AppException($code): $message';
}

class NetworkException extends AppException {
  NetworkException([super.message = 'Erro de conexão']) : super(code: 'NETWORK');
}

class UnauthorizedException extends AppException {
  UnauthorizedException() : super('Sessão expirada. Faça login novamente.', code: 'UNAUTHORIZED');
}

class NotFoundException extends AppException {
  NotFoundException(String resource) : super('$resource não encontrado', code: 'NOT_FOUND');
}
