import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/alimentos/domain/alimento.dart';
import 'package:foodzy/features/alimentos/domain/cantidad.dart';
import 'package:foodzy/features/alimentos/domain/estado_alimento.dart';
import 'package:foodzy/features/alimentos/presentation/providers/alimentos_provider.dart';
import 'package:intl/intl.dart';

class PantallaEditar extends ConsumerStatefulWidget {
  const PantallaEditar({
    super.key,
    this.alimentoExistente,
  });

  final Alimento? alimentoExistente;

  @override
  ConsumerState<PantallaEditar> createState() => _PantallaEditarState();
}

class _PantallaEditarState extends ConsumerState<PantallaEditar> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombreController;
  late TextEditingController _categoriaController;
  late TextEditingController _cantidadValorController;
  late TextEditingController _cantidadUnidadController;
  
  DateTime _fechaVencimiento = DateTime.now().add(const Duration(days: 7));
  bool _noVence = false;
  FechaOrigen _origen = FechaOrigen.manual;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final alimento = widget.alimentoExistente;
    _nombreController = TextEditingController(text: alimento?.nombre ?? '');
    _categoriaController = TextEditingController(text: alimento?.categoria ?? '');
    _cantidadValorController = TextEditingController(text: alimento?.cantidad.valor.toString() ?? '');
    _cantidadUnidadController = TextEditingController(text: alimento?.cantidad.unidad ?? '');
    
    if (alimento != null) {
      _noVence = alimento.noVence;
      _origen = alimento.origenFecha;
      if (!alimento.noVence && !alimento.sinFechaVencimiento) {
        _fechaVencimiento = alimento.fechaVencimiento;
      }
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _categoriaController.dispose();
    _cantidadValorController.dispose();
    _cantidadUnidadController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaVencimiento,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        _fechaVencimiento = picked;
        _origen = FechaOrigen.manual;
      });
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final valorDouble = double.tryParse(_cantidadValorController.text.replaceAll(',', '.')) ?? 1.0;

    final nuevoAlimento = Alimento(
      id: widget.alimentoExistente?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      nombre: _nombreController.text.trim(),
      categoria: _categoriaController.text.trim(),
      cantidad: Cantidad(
        valor: valorDouble,
        unidad: _cantidadUnidadController.text.trim(),
      ),
      fechaVencimiento: _noVence ? Alimento.nuncaVence : _fechaVencimiento,
      origenFecha: _origen,
      estado: widget.alimentoExistente?.estado ?? Disponible(DateTime.now()),
      fotos: widget.alimentoExistente?.fotos ?? const [],
    );

    if (widget.alimentoExistente == null) {
      await ref.read(alimentosProvider.notifier).agregar(nuevoAlimento);
    } else {
      await ref.read(alimentosProvider.notifier).actualizar(nuevoAlimento);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final esNuevo = widget.alimentoExistente == null;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(esNuevo ? 'Nuevo Alimento' : 'Editar Alimento'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre del alimento',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.fastfood),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoriaController,
              decoration: const InputDecoration(
                labelText: 'Categoría (ej. Lácteos, Carnes, Verduras)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _cantidadValorController,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.scale),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Requerido';
                      if (double.tryParse(val.replaceAll(',', '.')) == null) return 'Inválido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _cantidadUnidadController,
                    decoration: const InputDecoration(
                      labelText: 'Unidad (L, kg, u)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Requerido' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: const Text('Este producto no vence'),
              subtitle: const Text('Sal, azúcar, miel… no recibe avisos de vencimiento'),
              value: _noVence,
              onChanged: (v) => setState(() => _noVence = v),
            ),
            ListTile(
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(4),
              ),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Fecha de Vencimiento'),
              enabled: !_noVence,
              subtitle: Text(_noVence
                  ? 'No aplica'
                  : DateFormat.yMMMMd().format(_fechaVencimiento)),
              onTap: _noVence ? null : _seleccionarFecha,
              trailing: const Icon(Icons.edit),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _guardar,
                child: _isLoading 
                  ? const CircularProgressIndicator() 
                  : Text(esNuevo ? 'Guardar' : 'Actualizar', style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
