import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/booking_calc.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'success_screen.dart';

/// The website's booking popup, used two ways:
///  • check-in  — review / edit a scanned booking and confirm the check-in;
///                pops with a [BookingResult] once saved
///  • walk-in   — B. Walk-in Booking, a brand-new confirmed booking
class BookingFormScreen extends StatefulWidget {
  const BookingFormScreen.walkin({super.key}) : ticket = null;

  const BookingFormScreen.checkin({super.key, required Ticket this.ticket});

  final Ticket? ticket;

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _city = TextEditingController();
  final _timing = TextEditingController();
  final _priceAdult = TextEditingController();
  final _priceChild = TextEditingController();
  final _cash = TextEditingController();
  final _online = TextEditingController();

  AppConfig? _config;
  List<Batch> _batches = const [];
  Batch? _batch;
  late DateTime _date;
  int _adults = 1;
  int _children = 0;
  Map<String, MealChoice> _meals = {};
  String? _payment;
  bool _busy = false;
  bool _showErrors = false;
  String? _error;

  Ticket? get _ticket => widget.ticket;
  bool get _isWalkin => widget.ticket == null;
  bool get _isStay => _ticket?.isStay ?? false;
  bool get _paidOnline => _ticket?.isPaidOnline ?? false;
  Map<String, int> get _plan => _batch?.mealPlan ?? const {};

  @override
  void initState() {
    super.initState();
    final config = session.config;
    _config = config;
    _date = config?.today ?? dateOnly(DateTime.now());
    if (config == null) return;

    final t = _ticket;
    if (t == null) {
      // Walk-in: day packages that are switched on
      _batches = config.activeDayBatches;
      if (_batches.isNotEmpty) _applyBatch(_batches.first);
    } else {
      _batch = config.batchById(t.batchId);
      _batches = t.isStay
          ? [?_batch]
          : config.batches.where((b) => !b.isStay && (b.isActive || b.id == t.batchId)).toList();
      _name.text = t.name;
      _mobile.text = t.mobile;
      _city.text = t.city;
      _date = parseYmd(t.visitDate) ?? _date;
      _adults = t.adults < 1 ? 1 : t.adults;
      _children = t.children < 0 ? 0 : t.children;
      _timing.text = t.timing.isNotEmpty ? t.timing : (_batch?.timing ?? '');
      _priceAdult.text = _money(t.priceAdult);
      _priceChild.text = _money(t.priceChild);
      _meals = BookingCalc.mealsFromTicket(t, _plan);
      _payment = const ['cash', 'online', 'split'].contains(t.paymentType) ? t.paymentType : null;
      if (_payment == 'split') {
        _cash.text = _money(t.cashAmount);
        _online.text = _money(t.onlineAmount);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _mobile, _city, _timing, _priceAdult, _priceChild, _cash, _online]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _money(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  /// Picking a package loads its rates, time slot and included meals.
  void _applyBatch(Batch b) {
    _batch = b;
    _priceAdult.text = _money(b.priceAdult);
    _priceChild.text = _money(b.priceChild);
    _timing.text = b.timing;
    _meals = BookingCalc.defaultMeals(b.mealPlan, _adults, _children);
  }

  /// Guest count changed → every included meal goes back to "all guests".
  void _setGuests({int? adults, int? children}) {
    setState(() {
      _adults = adults ?? _adults;
      _children = children ?? _children;
      for (final entry in _meals.entries) {
        final mult = _plan[entry.key] ?? 0;
        entry.value.adultQty = _adults * mult;
        entry.value.childQty = _children * mult;
      }
      _syncSplit();
    });
  }

  PriceBreakdown get _price => BookingCalc.price(
        adults: _adults,
        children: _children,
        priceAdult: _num(_priceAdult),
        priceChild: _num(_priceChild),
        plan: _plan,
        meals: _meals,
        rates: _config?.mealRates ?? const {},
        nights: _isStay ? (_ticket?.nights ?? 1) : 1,
      );

  /// Keep "cash + online = total" as the total changes.
  void _syncSplit({bool editedOnline = false}) {
    if (_payment != 'split') return;
    final total = _price.total;
    if (editedOnline) {
      final online = _num(_online).clamp(0, total).toDouble();
      _cash.text = _money(total - online);
    } else {
      final cash = _num(_cash).clamp(0, total).toDouble();
      _online.text = _money(total - cash);
    }
  }

  void _selectPayment(String type) {
    setState(() {
      _payment = type;
      if (type == 'split' && _cash.text.isEmpty && _online.text.isEmpty) {
        _cash.text = _money(_price.total);
        _online.text = '0';
      }
      _syncSplit();
    });
  }

  Future<void> _pickDate() async {
    final today = _config?.today ?? dateOnly(DateTime.now());
    final first = today.subtract(const Duration(days: 30));
    final last = today.add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _date.isBefore(first) ? _date : first,
      lastDate: _date.isAfter(last) ? _date : last,
      helpText: 'Visit date',
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  String? get _nameError => _name.text.trim().length < 2 ? 'Enter the customer\'s name' : null;
  String? get _mobileError => mobilePattern.hasMatch(_mobile.text.trim()) ? null : 'Enter a valid 10-digit mobile number';
  String? get _cityError => _city.text.trim().length < 2 ? 'Enter the city' : null;
  bool get _splitMismatch => _payment == 'split' && (_price.total - _num(_cash) - _num(_online)).abs() >= 1;

  String? _validate() {
    if (_batch == null) return 'Please select a package.';
    if (_nameError != null) return _nameError;
    if (_isWalkin && _mobileError != null) return _mobileError;
    if (_isWalkin && _cityError != null) return _cityError;
    if (!_paidOnline && _payment == null) return 'Please select a payment type.';
    if (_splitMismatch) return 'Cash + Online must add up to the total (${rupees(_price.total)}).';
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final problem = _validate();
    if (problem != null) {
      setState(() {
        _showErrors = true;
        _error = problem;
      });
      return;
    }
    FocusScope.of(context).unfocus();
    final price = _price;
    final batch = _batch!;
    final t = _ticket;

    // Same field names the website's popup posts
    final fields = <String, String>{
      'name': _name.text.trim(),
      'adult_count': '$_adults',
      'child_count': '$_children',
      'visit_date': t != null && t.isStay ? t.visitDate : ymd(_date),
      'batch_id': '${batch.id}',
      'timing': _timing.text.trim(),
      'price_adult': _money(_num(_priceAdult)),
      'price_child': _money(_num(_priceChild)),
      'total_amount': price.total.toStringAsFixed(2),
      'payment_type': _paidOnline ? '' : (_payment ?? ''),
    };
    if (!_paidOnline && _payment == 'split') {
      fields['cash_amount'] = _money(_num(_cash));
      fields['online_amount'] = _money(_num(_online));
    }
    for (final entry in _meals.entries) {
      if (entry.value.on) fields[entry.key] = '1';
      fields['meal_${entry.key}_adult_qty'] = '${entry.value.adultQty}';
      fields['meal_${entry.key}_child_qty'] = '${entry.value.childQty}';
    }
    if (t == null) {
      fields['mobile'] = _mobile.text.trim();
      fields['city'] = _city.text.trim();
    } else {
      fields['id'] = '${t.id}';
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await session.api.post(t == null ? 'walkin' : 'ticket/checkin', fields);
      if (!mounted) return;

      final enquiry = res['enquiry'] is Map<String, dynamic> ? res['enquiry'] as Map<String, dynamic> : const <String, dynamic>{};
      final bookingId = t == null ? toStr(res['booking_id']) : (toStr(enquiry['booking_id']).isEmpty ? t.bookingId : toStr(enquiry['booking_id']));
      final ticketUrl = toStr(res['ticket_url']).isNotEmpty ? toStr(res['ticket_url']) : toStr(enquiry['ticket_url']);
      final guests = '$_adults adult${_adults == 1 ? '' : 's'}${_children > 0 ? ', $_children child${_children == 1 ? '' : 'ren'}' : ''}';

      final result = BookingResult(
        title: t == null ? 'Walk-in booked' : 'Checked in',
        bookingId: bookingId,
        name: fields['name']!,
        mobile: t == null ? fields['mobile']! : t.mobile,
        ticketUrl: ticketUrl,
        lines: [
          MapEntry('Guest', fields['name']!),
          MapEntry('Package', batch.name),
          MapEntry(
            t != null && t.isStay ? 'Stay' : 'Visit date',
            t != null && t.isStay ? _stayLabel(t) : prettyDate(_date),
          ),
          if (fields['timing']!.isNotEmpty) MapEntry('Timing', fields['timing']!),
          MapEntry('Guests', guests),
          MapEntry('Total', rupees(price.total)),
          MapEntry('Payment', _paidOnline ? 'Paid online' : _paymentLabel(_payment)),
        ],
      );
      if (t != null) {
        // The scanner opened this form and shows the result itself
        Navigator.of(context).pop(result);
        return;
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SuccessScreen(
            result: result,
            againLabel: 'New walk-in booking',
            againIcon: Icons.person_add_alt_1_rounded,
            againBuilder: (_) => const BookingFormScreen.walkin(),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted && !e.unauthorized) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _paymentLabel(String? type) {
    switch (type) {
      case 'cash':
        return 'Cash';
      case 'online':
        return 'Online';
      case 'split':
        return 'Split (cash + online)';
      default:
        return '—';
    }
  }

  static String _stayLabel(Ticket t) {
    final ci = parseYmd(t.checkinDate);
    final co = parseYmd(t.checkoutDate);
    if (ci == null || co == null) return t.visitDate;
    return '${prettyDate(ci)} → ${prettyDate(co)} (${t.nights} night${t.nights == 1 ? '' : 's'})';
  }

  @override
  Widget build(BuildContext context) {
    final t = _ticket;
    final title = t == null ? 'Walk-in Booking' : 'Check-in · ${t.bookingId}';

    if (_config == null || _batches.isEmpty || _batch == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Notice.warning(
            t == null
                ? 'No day packages are switched on right now. Turn one on in the website admin (Batch & Package Management), then pull down on the home screen to refresh.'
                : 'This booking\'s package could not be loaded. Go back, pull down on the home screen to refresh, and scan again.',
          ),
        ),
      );
    }

    final price = _price;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                children: [
                  if (t != null && t.isCheckedIn)
                    Notice.success(
                      'Already checked in${t.checkinAt.isNotEmpty ? ' at ${t.checkinAt}' : ''}'
                      '${t.checkinBy.isNotEmpty ? ' by ${t.checkinBy}' : ''}. You can still update and re-confirm below.',
                    ),
                  _guestCard(t),
                  _visitCard(t),
                  _guestsCard(),
                  _ratesCard(),
                  _mealsCard(),
                  _billCard(price),
                  _paymentCard(t, price),
                  if (_error != null) Notice.error(_error!),
                ],
              ),
            ),
            _bottomBar(t, price),
          ],
        ),
      ),
    );
  }

  Widget _guestCard(Ticket? t) {
    return SectionCard(
      title: 'Guest details',
      icon: Icons.person_rounded,
      child: Column(
        children: [
          TextField(
            controller: _name,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Customer name',
              counterText: '',
              prefixIcon: const Icon(Icons.badge_rounded, color: AppColors.leaf),
              errorText: _showErrors ? _nameError : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mobile,
            readOnly: t != null,
            maxLength: 10,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Mobile number',
              counterText: '',
              prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.leaf),
              prefixText: t == null ? '+91 ' : null,
              fillColor: t == null ? Colors.white : const Color(0xFFF4F6F4),
              errorText: _showErrors && t == null ? _mobileError : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            readOnly: t != null,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'City',
              counterText: '',
              prefixIcon: const Icon(Icons.location_on_rounded, color: AppColors.leaf),
              fillColor: t == null ? Colors.white : const Color(0xFFF4F6F4),
              errorText: _showErrors && t == null ? _cityError : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _visitCard(Ticket? t) {
    final stay = t != null && t.isStay;
    return SectionCard(
      title: 'Package & date',
      icon: Icons.event_available_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerField(
            label: stay ? 'Stay dates' : 'Visit date',
            value: stay ? _stayLabel(t) : prettyDateWithDay(_date),
            icon: Icons.calendar_month_rounded,
            onTap: stay ? null : _pickDate,
          ),
          const SizedBox(height: 12),
          for (final b in _batches)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _BatchTile(
                batch: b,
                selected: b.id == _batch?.id,
                onTap: () {
                  if (b.id == _batch?.id) return;
                  setState(() {
                    _applyBatch(b);
                    _syncSplit();
                  });
                },
              ),
            ),
          const SizedBox(height: 4),
          TextField(
            controller: _timing,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Timing',
              hintText: 'e.g. 09:00 AM – 02:00 PM',
              counterText: '',
              prefixIcon: Icon(Icons.schedule_rounded, color: AppColors.leaf),
            ),
          ),
        ],
      ),
    );
  }

  Widget _guestsCard() {
    return SectionCard(
      title: 'Guests',
      icon: Icons.groups_rounded,
      trailing: Text(
        'Total ${_adults + _children}',
        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.forest, fontSize: 15),
      ),
      child: Column(
        children: [
          CounterField(label: 'Adults', value: _adults, min: 1, onChanged: (v) => _setGuests(adults: v)),
          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
          CounterField(label: 'Children', value: _children, onChanged: (v) => _setGuests(children: v)),
        ],
      ),
    );
  }

  Widget _ratesCard() {
    Widget rate(String label, TextEditingController c) {
      return Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
          onChanged: (_) => setState(_syncSplit),
          decoration: InputDecoration(labelText: label, prefixText: 'Rs. '),
        ),
      );
    }

    return SectionCard(
      title: _isStay ? 'Rate per person, per night' : 'Rate per person',
      icon: Icons.sell_rounded,
      child: Row(children: [rate('Adult', _priceAdult), const SizedBox(width: 12), rate('Child', _priceChild)]),
    );
  }

  Widget _mealsCard() {
    final rates = _config?.mealRates ?? const <String, MealRate>{};
    return SectionCard(
      title: 'Meals included',
      icon: Icons.restaurant_rounded,
      child: _meals.isEmpty
          ? const Text('No meals included for this package / time slot.', style: TextStyle(color: AppColors.muted))
          : Column(
              children: [
                for (final entry in _meals.entries)
                  _MealTile(
                    meal: entry.key,
                    choice: entry.value,
                    mult: _plan[entry.key] ?? 1,
                    adults: _adults,
                    children: _children,
                    rate: rates[entry.key] ?? const MealRate(0, 0),
                    onChanged: () => setState(_syncSplit),
                  ),
              ],
            ),
    );
  }

  Widget _billCard(PriceBreakdown price) {
    final nights = _isStay ? (_ticket?.nights ?? 1) : 1;
    final pa = _num(_priceAdult);
    final pc = _num(_priceChild);
    final per = nights > 1 ? ' × $nights nights' : '';
    return SectionCard(
      title: 'Bill',
      icon: Icons.calculate_rounded,
      child: Column(
        children: [
          KeyValueRow('Adults: $_adults × ${rupees(pa)}$per', rupees(_adults * pa * nights)),
          if (_children > 0) KeyValueRow('Children: $_children × ${rupees(pc)}$per', rupees(_children * pc * nights)),
          for (final line in price.mealLines)
            if (line.deduction > 0)
              KeyValueRow(
                line.on
                    ? '${mealLabels[line.meal]} — ${line.full - line.taken} of ${line.full} not taken'
                    : '${mealLabels[line.meal]} — not taken',
                '− ${rupees(line.deduction)}',
                valueColor: AppColors.danger,
              ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider()),
          KeyValueRow('Final total', rupees(price.total), bold: true),
        ],
      ),
    );
  }

  Widget _paymentCard(Ticket? t, PriceBreakdown price) {
    if (_paidOnline) {
      final via = (t?.paymentGateway ?? '').isEmpty ? '' : ' via ${t!.paymentGateway}';
      return SectionCard(
        title: 'Payment',
        icon: Icons.payments_rounded,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              const Icon(Icons.verified_rounded, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Paid online$via — nothing to collect',
                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget amount(String label, TextEditingController c, bool isOnline) {
      return Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
          onChanged: (_) => setState(() => _syncSplit(editedOnline: isOnline)),
          decoration: InputDecoration(labelText: label, prefixText: 'Rs. '),
        ),
      );
    }

    return SectionCard(
      title: 'How is the guest paying?',
      icon: Icons.payments_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: ChoiceTile(emoji: '💵', label: 'Cash', selected: _payment == 'cash', onTap: () => _selectPayment('cash'))),
              const SizedBox(width: 8),
              Expanded(child: ChoiceTile(emoji: '📱', label: 'Online', selected: _payment == 'online', onTap: () => _selectPayment('online'))),
              const SizedBox(width: 8),
              Expanded(child: ChoiceTile(emoji: '🔀', label: 'Split', selected: _payment == 'split', onTap: () => _selectPayment('split'))),
            ],
          ),
          if (_showErrors && _payment == null)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Please select a payment type.', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
          if (_payment == 'split') ...[
            const SizedBox(height: 14),
            Row(children: [amount('Cash', _cash, false), const SizedBox(width: 12), amount('Online', _online, true)]),
            const SizedBox(height: 8),
            Text(
              _splitMismatch
                  ? 'Cash + Online must add up to ${rupees(price.total)}'
                  : 'Cash + Online = ${rupees(price.total)} ✓',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _splitMismatch ? AppColors.danger : AppColors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar(Ticket? t, PriceBreakdown price) {
    return BottomActionBar(
      caption: 'Total',
      amount: rupees(price.total),
      button: BusyButton(
        label: t == null ? 'Save booking' : (t.isCheckedIn ? 'Update check-in' : 'Confirm check-in'),
        icon: t == null ? Icons.check_circle_rounded : Icons.how_to_reg_rounded,
        busy: _busy,
        onPressed: _submit,
      ),
    );
  }
}

class _BatchTile extends StatelessWidget {
  const _BatchTile({required this.batch, required this.selected, required this.onTap});

  final Batch batch;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (batch.timing.isNotEmpty) batch.timing,
      '${rupees(batch.priceAdult)} adult · ${rupees(batch.priceChild)} child',
      if (!batch.isActive) 'inactive',
    ].join('  •  ');
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.successSoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? AppColors.leaf : AppColors.line, width: selected ? 2 : 1.2),
            ),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.leaf : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(batch.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text(sub, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One included meal: on/off, and how many adults / children are taking it.
class _MealTile extends StatelessWidget {
  const _MealTile({
    required this.meal,
    required this.choice,
    required this.mult,
    required this.adults,
    required this.children,
    required this.rate,
    required this.onChanged,
  });

  final String meal;
  final MealChoice choice;
  final int mult;
  final int adults;
  final int children;
  final MealRate rate;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final fullAdult = adults * mult;
    final fullChild = children * mult;
    final hasRate = rate.adult > 0 || rate.child > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 10),
      decoration: BoxDecoration(
        color: choice.on ? const Color(0xFFF7FBF7) : const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: choice.on ? const Color(0xFFCFE6D2) : AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(mealIcons[meal] ?? '🍽️', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${mealLabels[meal] ?? meal}${mult > 1 ? ' (×$mult per person)' : ''}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                    if (hasRate)
                      Text(
                        'If not taken: − ${rupees(rate.adult)}/adult, − ${rupees(rate.child)}/child',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                  ],
                ),
              ),
              Switch(
                value: choice.on,
                onChanged: (v) {
                  choice.on = v;
                  onChanged();
                },
              ),
            ],
          ),
          if (choice.on) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: CounterField(
                compact: true,
                label: 'Adults taking this',
                hint: 'of $fullAdult',
                value: choice.adultQty.clamp(0, fullAdult),
                max: fullAdult,
                onChanged: (v) {
                  choice.adultQty = v;
                  onChanged();
                },
              ),
            ),
            if (fullChild > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 6),
                child: CounterField(
                  compact: true,
                  label: 'Children taking this',
                  hint: 'of $fullChild',
                  value: choice.childQty.clamp(0, fullChild),
                  max: fullChild,
                  onChanged: (v) {
                    choice.childQty = v;
                    onChanged();
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}
