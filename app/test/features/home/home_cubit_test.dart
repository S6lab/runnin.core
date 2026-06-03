import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/home/presentation/cubit/home_cubit.dart';

void main() {
  // Smoke tests do HomeCubit. Como o GetHomeDataUseCase usa singletons de
  // datasources (UserRemoteDatasource/PlanRemoteDatasource), full bloc_test
  // exige refactor pra injetar mocks. Aqui validamos só transições básicas
  // do state machine — load() emite Loading + Error quando o use case falha.
  group('HomeCubit — states', () {
    test('HomeInitial é o estado inicial', () {
      final cubit = HomeCubit();
      expect(cubit.state, isA<HomeInitial>());
      cubit.close();
    });

    blocTest<HomeCubit, HomeState>(
      'emite HomeLoading depois HomeError quando o use case lança',
      build: HomeCubit.new,
      act: (cubit) => cubit.load(),
      // Use case real vai estourar (sem rede / Dio sem auth), então a sequência
      // esperada é Loading → Error genérico. Verifica só a forma do erro.
      expect: () => [
        isA<HomeLoading>(),
        predicate<HomeState>(
          (s) => s is HomeError && s.message.toLowerCase().contains('erro'),
          'is HomeError com mensagem de erro',
        ),
      ],
      wait: const Duration(seconds: 3),
    );
  });
}
