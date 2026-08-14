import 'package:flutter/material.dart';
import 'package:foodzy/features/alimentos/data/alimentos_locales.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';

void main() => runApp(const FoodzyApp());

class FoodzyApp extends StatelessWidget {
  const FoodzyApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Foodzy',
        theme: ThemeData(colorSchemeSeed: Colors.green),
        home: const PantallaAlimentos(),
      );
}

class PantallaAlimentos extends StatefulWidget {
  const PantallaAlimentos({super.key});

  @override
  State<PantallaAlimentos> createState() => _PantallaAlimentosState();
}

class _PantallaAlimentosState extends State<PantallaAlimentos> {
  // `late final` en el campo: el Future se crea UNA vez.
  late final Future<List<Alimento>> _alimentos = AlimentosLocales().obtenerTodos();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mi Despensa - Foodzy')),
        body: FutureBuilder<List<Alimento>>(
          future: _alimentos,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('No se pudo leer:\n${snapshot.error}'));
            }

            final alimentos = snapshot.data ?? const <Alimento>[];
            return ListView.separated(
              itemCount: alimentos.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final alimento = alimentos[i];
                return ListTile(
                  title: Text(alimento.nombre),
                  subtitle: Text(
                    '${alimento.categoria} · ${alimento.cantidad.valor} ${alimento.cantidad.unidad}\nEstado: ${alimento.estado.etiqueta}',
                  ),
                  trailing: alimento.tieneFotos
                      ? const Icon(Icons.photo_outlined)
                      : null,
                  isThreeLine: true,
                );
              },
            );
          },
        ),
      );
}
