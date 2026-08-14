import 'package:foodzy/features/alimentos/domain/alimento.dart';

/// Lo que la aplicación necesita saber de los alimentos.
abstract interface class AlimentosRepository {
  Future<List<Alimento>> obtenerTodos();

  Future<Alimento?> obtenerPorId(String id);
  
  Future<List<Alimento>> obtenerDisponibles();
}
