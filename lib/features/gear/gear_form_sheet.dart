import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/gear.dart';
import 'gear_controller.dart';

/// Form used to create or edit a piece of equipment.
class GearFormSheet extends StatefulWidget {
  /// Creates the gear form.
  const GearFormSheet({super.key, this.gear});

  /// The gear being edited. `null` when a new one is created.
  final Gear? gear;

  /// Shows the form as a modal sheet and returns the saved gear.
  static Future<Gear?> show(BuildContext context, {Gear? gear}) {
    return showModalBottomSheet<Gear>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => GearFormSheet(gear: gear),
    );
  }

  @override
  State<GearFormSheet> createState() => _GearFormSheetState();
}

class _GearFormSheetState extends State<GearFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController =
      TextEditingController(text: widget.gear?.name ?? '');
  late final TextEditingController _brandController =
      TextEditingController(text: widget.gear?.brand ?? '');
  late final TextEditingController _modelController =
      TextEditingController(text: widget.gear?.model ?? '');

  late GearType _type = widget.gear?.type ?? GearType.bicycle;
  late bool _isDefault = widget.gear?.isDefault ?? false;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  /// Validates and stores the gear.
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final controller = context.read<GearController>();
    final now = DateTime.now();
    final existing = widget.gear;

    final gear = Gear(
      id: existing?.id,
      name: _nameController.text.trim(),
      brand: _brandController.text.trim().isEmpty ? null : _brandController.text.trim(),
      model: _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
      type: _type,
      totalDistanceMeters: existing?.totalDistanceMeters ?? 0,
      isDefault: _isDefault,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    await controller.save(gear);

    if (!mounted) return;
    Navigator.of(context).pop(gear);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.gear == null ? 'Add gear' : 'Edit gear',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // --- Type -------------------------------------------------------
              SegmentedButton<GearType>(
                segments: const <ButtonSegment<GearType>>[
                  ButtonSegment<GearType>(
                    value: GearType.bicycle,
                    label: Text('Bicycle'),
                    icon: Icon(Icons.pedal_bike_rounded),
                  ),
                  ButtonSegment<GearType>(
                    value: GearType.shoe,
                    label: Text('Shoes'),
                    icon: Icon(Icons.directions_run_rounded),
                  ),
                ],
                selected: <GearType>{_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              const SizedBox(height: 16),

              // --- Name -------------------------------------------------------
              TextFormField(
                controller: _nameController,
                autofocus: widget.gear == null,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Gravel bike',
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 12),

              // --- Brand / model ---------------------------------------------
              TextFormField(
                controller: _brandController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Brand',
                  hintText: 'Specialized',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _modelController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Model',
                  hintText: 'Diverge E5',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 8),

              // --- Default ----------------------------------------------------
              SwitchListTile(
                value: _isDefault,
                onChanged: (value) => setState(() => _isDefault = value),
                title: const Text('Use as default gear'),
                subtitle: const Text('Pre-selected when you start a recording'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),

              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save gear'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
