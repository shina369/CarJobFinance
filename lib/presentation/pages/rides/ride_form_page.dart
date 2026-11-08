// Ride Form Page - Criar/Editar corrida
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';

class RideFormPage extends ConsumerStatefulWidget {
  const RideFormPage({super.key, this.rideId});

  final String? rideId;

  bool get isEditing => rideId != null;

  @override
  ConsumerState<RideFormPage> createState() => _RideFormPageState();
}

class _RideFormPageState extends ConsumerState<RideFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _dateController = TextEditingController();
  final _earningsController = TextEditingController();
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  // State
  String _selectedPlatform = AppConstants.supportedPlatforms.first;
  String _selectedRideType = AppConstants.rideTypes.first;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _dateController.text = _formatDate(_selectedDate);
    if (widget.isEditing) {
      // TODO: Load existing ride data
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _earningsController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDate(picked);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      // TODO: Save ride
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar Corrida' : 'Nova Corrida'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                // TODO: Show delete confirmation
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Data e Hora
            const _SectionTitle('Data e Hora'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    onTap: _pickDate,
                    decoration: const InputDecoration(
                      labelText: 'Data',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Data é obrigatória';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: TextEditingController(
                      text: '${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}',
                    ),
                    readOnly: true,
                    onTap: _pickTime,
                    decoration: const InputDecoration(
                      labelText: 'Hora',
                      prefixIcon: Icon(Icons.access_time),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Plataforma
            const _SectionTitle('Plataforma'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedPlatform,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.apps),
              ),
              items: AppConstants.supportedPlatforms.map((platform) {
                return DropdownMenuItem(value: platform, child: Text(platform));
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedPlatform = value);
              },
            ),
            const SizedBox(height: 24),

            // Tipo de Corrida
            const _SectionTitle('Tipo de Corrida'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedRideType,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.star_outline),
              ),
              items: AppConstants.rideTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedRideType = value);
              },
            ),
            const SizedBox(height: 24),

            // Ganhos
            const _SectionTitle('Ganhos'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _earningsController,
              decoration: const InputDecoration(
                labelText: 'Valor ganho',
                prefixText: 'R\$ ',
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Valor é obrigatório';
                }
                if (double.tryParse(value.replaceAll(',', '.')) == null) {
                  return 'Valor inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Distância e Duração
            const _SectionTitle('Distância e Duração'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _distanceController,
                    decoration: const InputDecoration(
                      labelText: 'Distância (km)',
                      prefixIcon: Icon(Icons.straighten),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      final km = double.tryParse(value.replaceAll(',', '.'));
                      if (km == null || km > AppConstants.maxKmPerRide) {
                        return 'Distância inválida';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _durationController,
                    decoration: const InputDecoration(
                      labelText: 'Duração (min)',
                      prefixIcon: Icon(Icons.timer),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (int.tryParse(value) == null) {
                        return 'Duração inválida';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Origem e Destino
            const _SectionTitle('Origem e Destino (Opcional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _originController,
              decoration: const InputDecoration(
                labelText: 'Origem',
                prefixIcon: Icon(Icons.my_location),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Destino',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 32),

            // Botões
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(widget.isEditing ? 'Salvar Alterações' : 'Salvar Corrida'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}