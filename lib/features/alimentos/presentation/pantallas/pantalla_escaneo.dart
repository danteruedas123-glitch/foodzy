import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/scanner_service.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class PantallaEscaneo extends ConsumerStatefulWidget {
  const PantallaEscaneo({
    super.key,
    required this.imageFile,
  });

  final XFile imageFile;

  @override
  ConsumerState<PantallaEscaneo> createState() => _PantallaEscaneoState();
}

class _PantallaEscaneoState extends ConsumerState<PantallaEscaneo> {
  List<Alimento>? _alimentosDetectados;
  bool _isProcessing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _procesarImagen();
  }

  Future<void> _procesarImagen() async {
    try {
      final scanner = ref.read(scannerServiceProvider);
      final detectados = await scanner.analizarImagen(widget.imageFile);
      setState(() {
        _alimentosDetectados = detectados;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  bool _faltaFecha(Alimento a) => a.fechaVencimiento == DateTime(1970, 1, 1);

  bool _todosListos() {
    if (_alimentosDetectados == null || _alimentosDetectados!.isEmpty) return false;
    return !_alimentosDetectados!.any(_faltaFecha);
  }

  Future<void> _pedirFecha(int index) async {
    final alimento = _alimentosDetectados![index];
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      helpText: 'Selecciona fecha para: ${alimento.nombre}',
    );

    if (picked != null) {
      setState(() {
        _alimentosDetectados![index] = alimento.copyWith(
          // No podemos usar copyWith para cambiar fecha de vencimiento directamente 
          // ya que copyWith actual no permite cambiarla en la firma. 
          // Recrearemos el objeto Alimento temporalmente.
        );
      });
      // Espera, el modelo de alimento restringe la copia de identidad y fecha de vencimiento.
      // Vamos a recrearlo.
      setState(() {
        _alimentosDetectados![index] = Alimento(
          id: alimento.id,
          nombre: alimento.nombre,
          categoria: alimento.categoria,
          cantidad: alimento.cantidad,
          fechaVencimiento: picked,
          estado: alimento.estado,
          fotos: alimento.fotos,
        );
      });
    }
  }

  Future<void> _guardarTodos() async {
    final notifier = ref.read(alimentosProvider.notifier);
    
    // Mostramos un dialog de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    for (final a in _alimentosDetectados!) {
      // Le generamos un ID real final
      final aFinal = Alimento(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        nombre: a.nombre,
        categoria: a.categoria,
        cantidad: a.cantidad,
        fechaVencimiento: a.fechaVencimiento,
        estado: a.estado,
        fotos: [widget.imageFile.path], // Guardamos la foto para todos
      );
      await notifier.agregar(aFinal);
      await Future.delayed(const Duration(milliseconds: 10)); // Evitar colisión de IDs
    }

    if (mounted) {
      Navigator.of(context).pop(); // Cierra loading
      Navigator.of(context).pop(); // Vuelve a la lista
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisión Inteligente'),
      ),
      body: Column(
        children: [
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: kIsWeb 
                    ? NetworkImage(widget.imageFile.path) 
                    : FileImage(File(widget.imageFile.path)) as ImageProvider,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),
            ),
          ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      bottomNavigationBar: _alimentosDetectados != null && _alimentosDetectados!.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: _todosListos() ? _guardarTodos : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Guardar Todos', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildContent() {
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('La IA está analizando los alimentos...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error: $_error', style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (_alimentosDetectados == null || _alimentosDetectados!.isEmpty) {
      return const Center(
        child: Text('No se detectó ningún alimento en la foto.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _alimentosDetectados!.length,
      itemBuilder: (context, index) {
        final a = _alimentosDetectados![index];
        final falta = _faltaFecha(a);

        return Card(
          elevation: falta ? 4 : 1,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: falta ? Colors.red : Colors.green.shade300,
              width: falta ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: Icon(
              falta ? Icons.warning_amber_rounded : Icons.check_circle_outline,
              color: falta ? Colors.red : Colors.green,
              size: 32,
            ),
            title: Text(a.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${a.categoria} - ${a.cantidad.valor} ${a.cantidad.unidad}'),
                const SizedBox(height: 4),
                if (falta)
                  const Text('¡Falta fecha de vencimiento! Toca para ingresarla.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
                else
                  Text('Vence: ${DateFormat.yMd().format(a.fechaVencimiento)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: falta ? ElevatedButton(
              onPressed: () => _pedirFecha(index),
              child: const Text('Completar'),
            ) : IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _pedirFecha(index),
            ),
            onTap: falta ? () => _pedirFecha(index) : null,
          ),
        );
      },
    );
  }
}
