import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/auth_service.dart';
import '../../services/location.dart';
import '../../services/store_data.dart';
import '../../widgets/common.dart';
import '../../widgets/doodles.dart';

/// Add / edit a delivery address. With [autoLocate], asks for location
/// permission as soon as it opens. Returns the saved address.
Future<Address?> showAddressEditor(BuildContext context, {Address? initial, bool autoLocate = false}) {
  final editor = _AddressEditor(initial: initial, autoLocate: autoLocate);
  if (isMobile(context)) {
    return showModalBottomSheet<Address>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom), child: editor),
    );
  }
  return showDialog<Address>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 820), child: editor),
    ),
  );
}

class _AddressEditor extends StatefulWidget {
  final Address? initial;
  final bool autoLocate;
  const _AddressEditor({this.initial, this.autoLocate = false});
  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<_AddressEditor> {
  final _form = GlobalKey<FormState>();
  late final _house = TextEditingController(text: widget.initial?.house);
  late final _area = TextEditingController(text: widget.initial?.area);
  late final _landmark = TextEditingController(text: widget.initial?.landmark);
  late final _city = TextEditingController(text: widget.initial?.city);
  late final _pincode = TextEditingController(text: widget.initial?.pincode);
  late String _label = widget.initial?.label ?? 'Home';
  late double? _lat = widget.initial?.lat;
  late double? _lng = widget.initial?.lng;
  late String _district = widget.initial?.district ?? '';
  bool _locating = false;
  bool _saving = false;
  String? _locError;

  // Area search dropdown
  final _areaFocus = FocusNode();
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  bool _searching = false;
  int _searchSeq = 0;

  // Pincode lookup
  PincodeInfo? _pinInfo;
  bool _pinLoading = false;
  String? _pinError;
  String _lastPin = '';

  @override
  void initState() {
    super.initState();
    _areaFocus.addListener(() {
      // Let a tap on a suggestion land before hiding the list.
      if (!_areaFocus.hasFocus) Future.delayed(const Duration(milliseconds: 250), () => mounted ? setState(() => _suggestions = const []) : null);
    });
    if (widget.autoLocate) WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
    if ((widget.initial?.pincode ?? '').length == 6) _lookupPin(widget.initial!.pincode, fillCity: false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _areaFocus.dispose();
    for (final c in [_house, _area, _landmark, _city, _pincode]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onAreaChanged(String v) {
    _debounce?.cancel();
    if (v.trim().length < 3) {
      setState(() => _suggestions = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final seq = ++_searchSeq;
      setState(() => _searching = true);
      final hint = _city.text.trim().isNotEmpty && !v.toLowerCase().contains(_city.text.trim().toLowerCase()) ? '$v, ${_city.text.trim()}' : v;
      final res = await LocationService.searchPlaces(hint, lat: _lat, lng: _lng);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searching = false;
        _suggestions = res;
      });
    });
  }

  void _pickSuggestion(PlaceSuggestion sg) {
    setState(() {
      _area.text = sg.area;
      if (sg.city.isNotEmpty) _city.text = sg.city;
      if (sg.district.isNotEmpty) _district = sg.district;
      if (sg.lat != null && sg.lng != null) {
        _lat = sg.lat;
        _lng = sg.lng;
      }
      _suggestions = const [];
    });
    _areaFocus.unfocus();
    if (RegExp(r'^\d{6}$').hasMatch(sg.pincode)) {
      _pincode.text = sg.pincode;
      _lookupPin(sg.pincode);
    }
  }

  Future<void> _lookupPin(String pin, {bool fillCity = true}) async {
    if (pin == _lastPin && _pinInfo != null) return;
    _lastPin = pin;
    setState(() {
      _pinLoading = true;
      _pinError = null;
    });
    final info = await LocationService.lookupPincode(pin);
    if (!mounted || pin != _pincode.text.trim()) return;
    setState(() {
      _pinLoading = false;
      _pinInfo = info;
      if (info == null) {
        _pinError = 'Could not verify this pincode with India Post — please double-check it.';
      } else {
        _district = info.district;
        if (fillCity && _city.text.trim().isEmpty) _city.text = info.district;
      }
    });
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      final g = await LocationService.detect();
      _lat = g.lat;
      _lng = g.lng;
      if (g.area.isNotEmpty) _area.text = g.area;
      if (g.city.isNotEmpty) _city.text = g.city;
      if (g.pincode.isNotEmpty) _pincode.text = g.pincode;
      _district = g.district;
      if (g.house.isNotEmpty && _house.text.trim().isEmpty) _house.text = g.house;
      if (g.area.isEmpty && g.city.isEmpty) _locError = 'Got your location but could not read the address — please search your area below.';
    } catch (e) {
      _locError = e.toString();
    }
    if (mounted) setState(() => _locating = false);
    if (RegExp(r'^\d{6}$').hasMatch(_pincode.text.trim())) _lookupPin(_pincode.text.trim());
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final a = Address(
      id: widget.initial?.id ?? Address.newId(),
      label: _label,
      house: _house.text.trim(),
      area: _area.text.trim(),
      landmark: _landmark.text.trim(),
      city: _city.text.trim(),
      district: _district,
      pincode: _pincode.text.trim(),
      lat: _lat,
      lng: _lng,
    );
    try {
      final settings = context.read<StoreData>().settings;
      await context.read<AuthService>().saveAddress(a);
      if (!mounted) return;
      Navigator.pop(context, a);
      if (!settings.serves(a)) {
        showToast(
            context, "Address saved, but we don't deliver to ${a.city.isEmpty ? 'this area' : a.city} yet. We deliver in ${settings.areaSummary}.",
            error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(context, authErrorText(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final located = _lat != null && _lng != null;
    return Form(
      key: _form,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text(widget.initial == null ? 'Add delivery address' : 'Edit address', style: AppTheme.display(26))),
            if (!isMobile(context)) IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
          ]),
          const SizedBox(height: 16),
          // ---- current location ----
          Hoverable(
            onTap: _locating ? null : _locate,
            builder: (h) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: located ? HK.veg.withOpacity(.08) : HK.amber.withOpacity(h ? .16 : .1),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: located ? HK.veg.withOpacity(.5) : HK.amber.withOpacity(.6), width: 1.4),
              ),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(gradient: located ? null : HK.fire, color: located ? HK.veg : null, shape: BoxShape.circle),
                  child: _locating
                      ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : Icon(located ? Icons.check_rounded : Icons.my_location_rounded, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      _locating ? 'Detecting your location…' : (located ? 'Location detected' : 'Use my current location'),
                      style: AppTheme.body(15.5, weight: FontWeight.w800, color: located ? HK.veg : HK.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      located
                          ? 'Pinned at ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)} · tap to refresh'
                          : 'Allow location access when your browser asks',
                      style: AppTheme.body(12.5, color: HK.muted),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          if (_locError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_locError!, style: AppTheme.body(13, color: HK.nonVeg, weight: FontWeight.w600, height: 1.45)),
            ),
          const SizedBox(height: 18),
          Row(children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('or search your address', style: AppTheme.body(12.5, color: HK.muted, weight: FontWeight.w600)),
            ),
            const Expanded(child: Divider()),
          ]),
          const SizedBox(height: 14),
          // ---- area search with dropdown ----
          TextFormField(
            controller: _area,
            focusNode: _areaFocus,
            textCapitalization: TextCapitalization.words,
            onChanged: _onAreaChanged,
            decoration: InputDecoration(
              labelText: 'Search area, street, locality',
              hintText: 'e.g. Sitabuldi, Dharampeth, MG Road…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                  : null,
            ),
            validator: (v) => validateRequired(v, 'Area'),
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: HK.line),
                boxShadow: HK.shadow(1.2),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 52),
                itemBuilder: (c, i) {
                  final sg = _suggestions[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined, color: HK.flame),
                    title: Text(sg.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(14, weight: FontWeight.w700)),
                    subtitle: Text(sg.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(12, color: HK.muted)),
                    onTap: () => _pickSuggestion(sg),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          // ---- pincode → city + area dropdown ----
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextFormField(
                controller: _pincode,
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (v) {
                  final pin = v.trim();
                  if (RegExp(r'^\d{6}$').hasMatch(pin)) {
                    _lookupPin(pin);
                  } else if (_pinInfo != null || _pinError != null) {
                    setState(() {
                      _pinInfo = null;
                      _pinError = null;
                      _lastPin = '';
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Pincode',
                  counterText: '',
                  prefixIcon: const Icon(Icons.pin_drop_outlined),
                  suffixIcon: _pinLoading
                      ? const Padding(
                          padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                      : (_pinInfo != null ? const Icon(Icons.check_circle_rounded, color: HK.veg) : null),
                ),
                validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim()) ? null : '6-digit pincode',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _city,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'City'),
                validator: (v) => validateRequired(v, 'City'),
              ),
            ),
          ]),
          if (_pinError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(_pinError!, style: AppTheme.body(12.5, color: HK.amberDeep, weight: FontWeight.w600)),
            ),
          if (_pinInfo != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text('✓ ${_pinInfo!.district}, ${_pinInfo!.state}', style: AppTheme.body(12.5, color: HK.veg, weight: FontWeight.w700)),
            ),
            if (_pinInfo!.areas.length > 1) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Choose your area in this pincode', prefixIcon: Icon(Icons.map_outlined)),
                items: [for (final a in _pinInfo!.areas) DropdownMenuItem(value: a, child: Text(a))],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    final cur = _area.text.trim();
                    _area.text = cur.isEmpty || _pinInfo!.areas.contains(cur) ? v : (cur.toLowerCase().contains(v.toLowerCase()) ? cur : '$cur, $v');
                  });
                },
              ),
            ],
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _house,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Flat / house no., building', prefixIcon: Icon(Icons.home_outlined)),
            validator: (v) => validateRequired(v, 'House / flat no.'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _landmark,
            textCapitalization: TextCapitalization.sentences,
            decoration:
                const InputDecoration(labelText: 'Landmark (optional)', hintText: 'e.g. Shaniwari Chowk', prefixIcon: Icon(Icons.place_outlined)),
          ),
          const SizedBox(height: 18),
          Text('SAVE AS', style: AppTheme.body(11.5, color: HK.muted, weight: FontWeight.w800).copyWith(letterSpacing: 1.6)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, children: [
            for (final (l, icon) in [('Home', Icons.home_rounded), ('Work', Icons.work_rounded), ('Other', Icons.location_on_rounded)])
              ChoiceChip(
                selected: _label == l,
                showCheckmark: false,
                avatar: Icon(icon, size: 17, color: _label == l ? Colors.black : HK.muted),
                label: Text(l),
                selectedColor: HK.amber,
                backgroundColor: Colors.white,
                side: BorderSide(color: _label == l ? HK.amber : HK.line),
                labelStyle: AppTheme.body(13.5, weight: FontWeight.w700, color: _label == l ? Colors.black : HK.ink),
                onSelected: (_) => setState(() => _label = l),
              ),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const BtnSpinner() : const Text('Save address')),
          ),
        ]),
      ),
    );
  }
}

/// Choose between saved addresses, add, edit or delete.
Future<void> showAddressPicker(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 620),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => const _AddressPicker(),
  );
}

class _AddressPicker extends StatelessWidget {
  const _AddressPicker();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final current = auth.currentAddress;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(24, 0, 24, 28), children: [
        Text('Choose delivery address', style: AppTheme.display(26)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: HK.amberDeep, side: BorderSide(color: HK.amber.withOpacity(.7), width: 1.4)),
          onPressed: () => showAddressEditor(context, autoLocate: true),
          icon: const Icon(Icons.my_location_rounded),
          label: const Text('Use my current location'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => showAddressEditor(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add address manually'),
        ),
        if (auth.addresses.isNotEmpty) ...[
          const SizedBox(height: 22),
          Text('SAVED ADDRESSES', style: AppTheme.body(11.5, color: HK.muted, weight: FontWeight.w800).copyWith(letterSpacing: 1.6)),
          const SizedBox(height: 10),
          for (final a in auth.addresses)
            AddressTile(
              address: a,
              selected: a.id == current?.id,
              onTap: () async {
                await auth.selectAddress(a.id);
                if (context.mounted) Navigator.pop(context);
              },
              onEdit: () => showAddressEditor(context, initial: a),
              onDelete: () async {
                if (await confirmDialog(context, title: 'Delete address?', message: a.line, confirm: 'Delete', destructive: true)) {
                  await auth.deleteAddress(a.id);
                }
              },
            ),
        ],
      ]),
    );
  }
}

IconData _labelIcon(String l) => switch (l) {
      'Home' => Icons.home_rounded,
      'Work' => Icons.work_rounded,
      _ => Icons.location_on_rounded,
    };

class AddressTile extends StatelessWidget {
  final Address address;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  const AddressTile({super.key, required this.address, this.selected = false, this.onTap, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final a = address;
    final served = context.watch<StoreData>().settings.serves(a);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Hoverable(
        onTap: onTap,
        builder: (h) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? HK.amber.withOpacity(.09) : (h ? HK.cardHi : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? HK.amber : HK.line, width: selected ? 1.6 : 1),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: HK.amber.withOpacity(.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(_labelIcon(a.label), color: HK.amberDeep, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(a.label, style: AppTheme.body(15, weight: FontWeight.w800)),
                  if (a.hasLocation) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.gps_fixed_rounded, size: 14, color: HK.veg),
                  ],
                  if (!served) ...[
                    const SizedBox(width: 8),
                    const Pill('Not serviceable', color: HK.nonVeg)
                  ] else if (selected) ...[
                    const SizedBox(width: 8),
                    const Pill('Delivering here', color: HK.veg)
                  ],
                ]),
                const SizedBox(height: 4),
                Text(a.line, style: AppTheme.body(13.5, color: HK.muted, height: 1.45)),
                Text(
                  [if (a.landmark.isNotEmpty) a.landmark.toLowerCase().startsWith('near') ? a.landmark : 'Near ${a.landmark}', a.pincode].join(' · '),
                  style: AppTheme.body(12.5, color: HK.muted),
                ),
              ]),
            ),
            if (onEdit != null) IconButton(tooltip: 'Edit', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 19)),
            if (onDelete != null)
              IconButton(tooltip: 'Delete', onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded, size: 19, color: HK.nonVeg)),
          ]),
        ),
      ),
    );
  }
}

/// "Deliver to: Home · Area ▾" chip for the top bar.
class DeliverToChip extends StatelessWidget {
  final bool compact;
  const DeliverToChip({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (!auth.signedIn) return const SizedBox.shrink();
    final a = auth.currentAddress;
    void open() => a == null ? showAddressEditor(context, autoLocate: true) : showAddressPicker(context);
    if (compact) {
      return IconButton(
        tooltip: a == null ? 'Set delivery location' : 'Deliver to ${a.label}',
        onPressed: open,
        icon: Icon(a == null ? Icons.add_location_alt_rounded : Icons.location_on_rounded, color: HK.amberDeep),
      );
    }
    return Hoverable(
      onTap: open,
      builder: (h) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: h ? HK.cardHi : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: a == null ? HK.amber : HK.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(a == null ? Icons.add_location_alt_rounded : Icons.location_on_rounded, color: HK.flame, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(a == null ? 'Set location' : 'Deliver to ${a.label}',
                  style: AppTheme.body(11, color: HK.muted, weight: FontWeight.w700).copyWith(letterSpacing: .3)),
              Text(a == null ? 'Allow location access' : a.short,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(13.5, weight: FontWeight.w800)),
            ]),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        ]),
      ),
    );
  }
}

/// Shown right after sign-up: ask for location and save the first address.
class LocationOnboardingPage extends StatefulWidget {
  final String next;
  const LocationOnboardingPage({super.key, required this.next});
  @override
  State<LocationOnboardingPage> createState() => _LocationOnboardingPageState();
}

class _LocationOnboardingPageState extends State<LocationOnboardingPage> {
  bool _autoRedirected = false;

  void _done() {
    if (mounted) context.go(widget.next);
  }

  /// Leaves automatically (once) when there's nothing to ask.
  void _autoLeave() {
    if (_autoRedirected) return;
    _autoRedirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _done());
  }

  Future<void> _add({required bool locate}) async {
    final a = await showAddressEditor(context, autoLocate: locate);
    if (a != null) _done();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (auth.ready && !auth.signedIn) _autoLeave();
    // Returning customers who already have an address skip straight through.
    if (auth.profile != null && auth.addresses.isNotEmpty) _autoLeave();
    final loading = !auth.ready || (auth.signedIn && auth.profile == null);
    final name = auth.displayName.split(' ').first;

    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(
          child: DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [HK.tint, HK.bg]))),
        ),
        const Positioned.fill(child: Doodles(seed: 17, opacity: .10, spacing: 120)),
        Center(
          child: loading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32), boxShadow: HK.shadow(1.5)),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: Stack(alignment: Alignment.center, children: [
                          for (var i = 0; i < 3; i++)
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: HK.flame.withOpacity(.35), width: 2)),
                            )
                                .animate(onPlay: (c) => c.repeat(), delay: (i * 600).ms)
                                .scaleXY(begin: .35, end: 1, duration: 1800.ms, curve: Curves.easeOut)
                                .fadeOut(duration: 1800.ms),
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(gradient: HK.fire, shape: BoxShape.circle, boxShadow: HK.shadow(1.2)),
                            child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 44),
                          ).animate(onPlay: (c) => c.repeat(reverse: true)).moveY(begin: -4, end: 4, duration: 1200.ms, curve: Curves.easeInOut),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      if (name.isNotEmpty) Text('Welcome, $name! 🎉', style: AppTheme.script(30)),
                      const SizedBox(height: 6),
                      Text('Where should we deliver?', textAlign: TextAlign.center, style: AppTheme.display(30)),
                      const SizedBox(height: 10),
                      Text(
                        'Allow location access so we can find your address automatically and get your food to you hot and fast.',
                        textAlign: TextAlign.center,
                        style: AppTheme.body(14.5, color: HK.muted, height: 1.6),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton.icon(
                          onPressed: () => _add(locate: true),
                          icon: const Icon(Icons.my_location_rounded),
                          label: const Text('Use my current location'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: () => _add(locate: false),
                          icon: const Icon(Icons.edit_location_alt_outlined),
                          label: const Text('Enter address manually'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _done, child: const Text('Skip for now')),
                    ]),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: .08),
                ),
        ),
      ]),
    );
  }
}
