import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'success_screen.dart';

/// Seat status of one day package on the chosen date.
class _Availability {
  const _Availability({required this.isFull, required this.label, required this.seatsLeft});

  final bool isFull;
  final String label;
  final int? seatsLeft;
}

/// Rooms the website would allocate for a stay.
class _StayPreview {
  const _StayPreview({required this.rooms, required this.totalCapacity, required this.priceAdult, required this.priceChild});

  final List<Map<String, dynamic>> rooms;
  final int totalCapacity;
  final double priceAdult;
  final double priceChild;
}

/// C. Take Enquiry — the website's "New Enquiry" form: day package or stay,
/// date, live availability, guest details.
class EnquiryScreen extends StatefulWidget {
  const EnquiryScreen({super.key});

  @override
  State<EnquiryScreen> createState() => _EnquiryScreenState();
}

class _EnquiryScreenState extends State<EnquiryScreen> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _city = TextEditingController();

  AppConfig? _config;
  bool _stay = false;
  int _adults = 1;
  int _children = 0;

  // Day package
  DateTime? _date;
  Batch? _batch;
  Map<int, _Availability> _availability = const {};
  bool _loadingAvailability = false;

  // Stay
  DateTimeRange? _range;
  String _roomPref = 'both';
  _StayPreview? _preview;
  String? _previewError;
  bool _loadingPreview = false;

  int _requestNo = 0;
  bool _busy = false;
  bool _showErrors = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final config = session.config;
    _config = config;
    if (config != null && !config.dayEnabled && config.stayEnabled) _stay = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _city.dispose();
    super.dispose();
  }

  DateTime get _today => _config?.today ?? dateOnly(DateTime.now());
  int get _nights => _range == null ? 1 : _range!.end.difference(_range!.start).inDays.clamp(1, 60);

  void _setType(bool stay) {
    if (_stay == stay) return;
    setState(() {
      _stay = stay;
      _error = null;
    });
  }

  /* ───────── day package ───────── */

  Future<void> _pickDate() async {
    final config = _config;
    if (config == null) return;
    final last = _today.add(const Duration(days: 365));
    // The picker needs a selectable starting day — skip weekly holidays
    var initial = _date ?? _today;
    var guard = 0;
    while (config.isHoliday(initial) && guard < 14) {
      initial = initial.add(const Duration(days: 1));
      guard++;
    }
    if (config.isHoliday(initial) || initial.isAfter(last)) {
      showMessage(context, 'No open dates are available to book.', error: true);
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: _today,
      lastDate: last,
      helpText: 'Visit date',
      selectableDayPredicate: (d) => !config.isHoliday(d),
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    await _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final date = _date;
    if (date == null) return;
    final no = ++_requestNo;
    setState(() => _loadingAvailability = true);
    try {
      final res = await session.api.get('availability', {'date': ymd(date)});
      if (!mounted || no != _requestNo) return;
      final map = <int, _Availability>{};
      final raw = res['batches'];
      if (raw is Map) {
        raw.forEach((key, value) {
          if (value is Map) {
            map[toInt(key)] = _Availability(
              isFull: value['is_full'] == true,
              label: toStr(value['label']),
              seatsLeft: value['seats_left'] == null ? null : toInt(value['seats_left']),
            );
          }
        });
      }
      setState(() {
        _availability = map;
        if (_batch != null && (map[_batch!.id]?.isFull ?? false)) _batch = null;
      });
    } on ApiException catch (e) {
      if (mounted && !e.unauthorized && no == _requestNo) showMessage(context, e.message, error: true);
    } finally {
      if (mounted && no == _requestNo) setState(() => _loadingAvailability = false);
    }
  }

  /* ───────── stay ───────── */

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: _today,
      lastDate: _today.add(const Duration(days: 365)),
      helpText: 'Check-in and check-out',
      saveText: 'Done',
    );
    if (picked == null || !mounted) return;
    if (!picked.end.isAfter(picked.start)) {
      showMessage(context, 'Check-out must be at least one day after check-in.', error: true);
      return;
    }
    if (picked.end.difference(picked.start).inDays > 60) {
      showMessage(context, 'Stays are limited to 60 nights.', error: true);
      return;
    }
    setState(() => _range = picked);
    await _loadPreview();
  }

  /// Ask the website which rooms it would allocate (it allocates the same way on submit).
  Future<void> _loadPreview() async {
    final range = _range;
    if (range == null) return;
    final no = ++_requestNo;
    setState(() {
      _loadingPreview = true;
      _preview = null;
      _previewError = null;
    });
    try {
      final res = await session.api.get('availability', {
        'checkin': ymd(range.start),
        'checkout': ymd(range.end),
        'adults': '$_adults',
        'children': '$_children',
        'room_pref': _roomPref,
      });
      if (!mounted || no != _requestNo) return;
      if (res['ok'] == true) {
        final rooms = (res['rooms'] is List ? res['rooms'] as List : const []).whereType<Map<String, dynamic>>().toList();
        setState(() {
          _preview = _StayPreview(
            rooms: rooms,
            totalCapacity: toInt(res['total_capacity']),
            priceAdult: toDouble(res['price_adult']),
            priceChild: toDouble(res['price_child']),
          );
        });
      } else {
        final msg = toStr(res['message']);
        setState(() => _previewError = msg.isEmpty ? 'Sorry, accommodation is not available for the selected dates.' : msg);
      }
    } on ApiException catch (e) {
      if (mounted && !e.unauthorized && no == _requestNo) setState(() => _previewError = e.message);
    } finally {
      if (mounted && no == _requestNo) setState(() => _loadingPreview = false);
    }
  }

  void _setGuests({int? adults, int? children}) {
    setState(() {
      _adults = adults ?? _adults;
      _children = children ?? _children;
    });
    if (_stay && _range != null) _loadPreview();
  }

  /* ───────── submit ───────── */

  String? get _nameError => _name.text.trim().length < 2 ? 'Enter the customer\'s name' : null;
  String? get _mobileError => mobilePattern.hasMatch(_mobile.text.trim()) ? null : 'Enter a valid 10-digit mobile number';
  String? get _cityError => _city.text.trim().length < 2 ? 'Enter the city' : null;

  String? _validate() {
    if (_stay) {
      if (_range == null) return 'Please select check-in and check-out dates.';
      if (_loadingPreview) return 'Please wait — checking room availability.';
      if (_preview == null) return _previewError ?? 'Accommodation is not available for the selected dates.';
    } else {
      if (_date == null) return 'Please select a visit date.';
      if (_batch == null) return 'Please select a package.';
    }
    return _nameError ?? _mobileError ?? _cityError;
  }

  double get _estimate {
    if (_stay) {
      final p = _preview;
      return p == null ? 0 : (p.priceAdult * _adults + p.priceChild * _children) * _nights;
    }
    final b = _batch;
    return b == null ? 0 : b.priceAdult * _adults + b.priceChild * _children;
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

    final name = _name.text.trim();
    final mobile = _mobile.text.trim();
    final fields = <String, String>{
      'booking_type': _stay ? 'stay' : 'day_visit',
      'name': name,
      'mobile': mobile,
      'city': _city.text.trim(),
      'adult_count': '$_adults',
      'child_count': '$_children',
    };
    if (_stay) {
      fields['room_preference'] = _roomPref;
      fields['checkin_date'] = ymd(_range!.start);
      fields['checkout_date'] = ymd(_range!.end);
    } else {
      fields['batch_id'] = '${_batch!.id}';
      fields['visit_date'] = ymd(_date!);
    }

    final estimate = _estimate;
    final packageLabel = _stay
        ? '${_preview!.rooms.length} room${_preview!.rooms.length == 1 ? '' : 's'} — ${_preview!.rooms.map((r) => toStr(r['room_no'])).join(', ')}'
        : _batch!.name;
    final dateLabel = _stay
        ? '${prettyDate(_range!.start)} → ${prettyDate(_range!.end)} ($_nights night${_nights == 1 ? '' : 's'})'
        : prettyDate(_date!);
    final guests = '$_adults adult${_adults == 1 ? '' : 's'}${_children > 0 ? ', $_children child${_children == 1 ? '' : 'ren'}' : ''}';

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await session.api.post('enquiry', fields);
      if (!mounted) return;
      final result = BookingResult(
        title: 'Enquiry saved',
        bookingId: toStr(res['booking_id']),
        name: name,
        mobile: mobile,
        ticketUrl: toStr(res['ticket_url']),
        lines: [
          MapEntry('Guest', name),
          MapEntry(_stay ? 'Rooms' : 'Package', packageLabel),
          MapEntry(_stay ? 'Stay' : 'Visit date', dateLabel),
          MapEntry('Guests', guests),
          MapEntry('Estimated total', rupees(estimate)),
          const MapEntry('Status', 'Pending — confirm at check-in'),
          if (res['whatsapp_sent'] == true) const MapEntry('WhatsApp', 'Confirmation sent to guest'),
        ],
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SuccessScreen(
            result: result,
            againLabel: 'Take another enquiry',
            againIcon: Icons.edit_calendar_rounded,
            againBuilder: (_) => const EnquiryScreen(),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted || e.unauthorized) return;
      setState(() => _error = e.data['duplicate'] == true ? 'Duplicate booking — ${e.message}' : e.message);
      // Seats / rooms may have just been taken — show the fresh picture
      if (_stay) {
        _loadPreview();
      } else {
        _loadAvailability();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* ───────── UI ───────── */

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config == null || (!config.dayEnabled && !config.stayEnabled)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Take Enquiry')),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: Notice.warning(
            'Day and Stay packages are both switched off in the website admin, so enquiries cannot be taken right now.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Take Enquiry')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                children: [
                  if (config.dayEnabled && config.stayEnabled)
                    SectionCard(
                      title: 'What is this booking for?',
                      icon: Icons.category_rounded,
                      child: Row(
                        children: [
                          Expanded(
                            child: ChoiceTile(
                              emoji: '🌅',
                              label: 'Day Package',
                              sub: 'Single-day visit',
                              selected: !_stay,
                              onTap: () => _setType(false),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ChoiceTile(
                              emoji: '🌙',
                              label: 'Stay Package',
                              sub: 'Overnight room',
                              selected: _stay,
                              onTap: () => _setType(true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_stay) _stayCard() else _dayCard(config),
                  SectionCard(
                    title: 'Guests',
                    icon: Icons.groups_rounded,
                    trailing: Text(
                      'Total ${_adults + _children}',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.forest, fontSize: 15),
                    ),
                    child: Column(
                      children: [
                        CounterField(label: 'Adults', value: _adults, min: 1, max: 50, onChanged: (v) => _setGuests(adults: v)),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                        CounterField(label: 'Children', value: _children, max: 50, onChanged: (v) => _setGuests(children: v)),
                      ],
                    ),
                  ),
                  _guestCard(),
                  if (_error != null) Notice.error(_error!),
                ],
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _dayCard(AppConfig config) {
    final batches = config.activeDayBatches;
    return SectionCard(
      title: 'Date & package',
      icon: Icons.event_available_rounded,
      trailing: _loadingAvailability
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerField(
            label: 'Visit date',
            value: _date == null ? 'Tap to select date' : prettyDateWithDay(_date!),
            icon: Icons.calendar_month_rounded,
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          if (batches.isEmpty)
            const Text('No day packages are switched on right now.', style: TextStyle(color: AppColors.muted))
          else if (_date == null)
            const Text('Pick a date to see which packages have seats.', style: TextStyle(color: AppColors.muted, fontSize: 13.5))
          else
            for (final b in batches)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _EnquiryBatchTile(
                  batch: b,
                  availability: _availability[b.id],
                  selected: b.id == _batch?.id,
                  onTap: () => setState(() => _batch = b),
                ),
              ),
        ],
      ),
    );
  }

  Widget _stayCard() {
    final preview = _preview;
    return SectionCard(
      title: 'Stay dates & rooms',
      icon: Icons.hotel_rounded,
      trailing: _loadingPreview
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PickerField(
            label: 'Check-in → Check-out',
            value: _range == null
                ? 'Tap to select dates'
                : '${prettyDate(_range!.start)} → ${prettyDate(_range!.end)}  ($_nights night${_nights == 1 ? '' : 's'})',
            icon: Icons.date_range_rounded,
            onTap: _pickRange,
          ),
          const SizedBox(height: 14),
          const Text('Room preference', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final option in const [('both', 'Any', '🏡'), ('ac', 'AC', '❄️'), ('non_ac', 'Non-AC', '🌿')]) ...[
                Expanded(
                  child: ChoiceTile(
                    emoji: option.$3,
                    label: option.$2,
                    selected: _roomPref == option.$1,
                    onTap: () {
                      if (_roomPref == option.$1) return;
                      setState(() => _roomPref = option.$1);
                      if (_range != null) _loadPreview();
                    },
                  ),
                ),
                if (option.$1 != 'non_ac') const SizedBox(width: 8),
              ],
            ],
          ),
          if (_previewError != null) ...[const SizedBox(height: 14), Notice.error(_previewError!)],
          if (preview != null) ...[
            const SizedBox(height: 14),
            for (final room in preview.rooms)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: AppColors.successSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCFE6D2)),
                ),
                child: Row(
                  children: [
                    Text(toStr(room['room_type']) == 'ac' ? '❄️' : '🌿', style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${toStr(room['room_type']) == 'ac' ? 'AC Room' : 'Non-AC Room'} — ${toStr(room['room_no'])}',
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ),
                    Text('${toInt(room['capacity'])} guests', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                  ],
                ),
              ),
            Text(
              '${preview.rooms.length} room${preview.rooms.length == 1 ? '' : 's'} · fits ${preview.totalCapacity} guests · '
              '${rupees(preview.priceAdult)}/adult, ${rupees(preview.priceChild)}/child per night',
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _guestCard() {
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
            maxLength: 10,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Mobile number',
              counterText: '',
              prefixText: '+91 ',
              prefixIcon: const Icon(Icons.phone_rounded, color: AppColors.leaf),
              errorText: _showErrors ? _mobileError : null,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _city,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'City',
              counterText: '',
              prefixIcon: const Icon(Icons.location_on_rounded, color: AppColors.leaf),
              errorText: _showErrors ? _cityError : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final estimate = _estimate;
    return BottomActionBar(
      caption: 'Estimate',
      amount: estimate > 0 ? rupees(estimate) : '—',
      button: BusyButton(label: 'Submit enquiry', icon: Icons.send_rounded, busy: _busy, onPressed: _submit),
    );
  }
}

class _EnquiryBatchTile extends StatelessWidget {
  const _EnquiryBatchTile({required this.batch, required this.availability, required this.selected, required this.onTap});

  final Batch batch;
  final _Availability? availability;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final blocked = availability?.isFull ?? false;
    final seats = availability?.seatsLeft;
    final sub = [
      if (batch.timing.isNotEmpty) batch.timing,
      '${rupees(batch.priceAdult)} adult · ${rupees(batch.priceChild)} child',
    ].join('  •  ');

    return Semantics(
      button: true,
      selected: selected,
      enabled: !blocked,
      child: Opacity(
        opacity: blocked ? 0.6 : 1,
        child: Material(
          color: selected ? AppColors.successSoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: blocked ? null : onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: selected ? AppColors.leaf : AppColors.line, width: selected ? 2 : 1.2),
              ),
              child: Row(
                children: [
                  Icon(
                    blocked
                        ? Icons.block_rounded
                        : (selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded),
                    color: blocked ? AppColors.danger : (selected ? AppColors.leaf : AppColors.muted),
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
                  const SizedBox(width: 8),
                  if (blocked)
                    _Pill(text: availability!.label.isEmpty ? 'NOT AVAILABLE' : availability!.label, color: AppColors.danger, background: AppColors.dangerSoft)
                  else if (seats != null)
                    _Pill(text: '$seats left', color: AppColors.success, background: AppColors.successSoft),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, required this.background});

  final String text;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 110),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.3),
      ),
    );
  }
}
