import 'package:flutter/material.dart';

import '../core/theme.dart';

/// White rounded card with an optional icon + title header.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.icon, this.trailing, required this.child});

  final String? title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 14, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: AppColors.successSoft, borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, size: 19, color: AppColors.leaf),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// Big − / + stepper for guest counts.
class CounterField extends StatelessWidget {
  const CounterField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.min = 0,
    this.max = 500,
    this.compact = false,
  });

  final String label;
  final String? hint;
  final int value;
  final int min;
  final int max;
  final bool compact;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 34.0 : 44.0;
    Widget button(IconData icon, bool enabled, int delta) {
      return Material(
        color: enabled ? AppColors.successSoft : const Color(0xFFF1F3F1),
        borderRadius: BorderRadius.circular(compact ? 10 : 14),
        child: InkWell(
          borderRadius: BorderRadius.circular(compact ? 10 : 14),
          onTap: enabled ? () => onChanged(value + delta) : null,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: compact ? 18 : 22, color: enabled ? AppColors.forest : const Color(0xFFB8C0B8)),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: compact ? 13.5 : 15.5, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              if (hint != null) Text(hint!, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            ],
          ),
        ),
        Semantics(label: 'Fewer $label', button: true, child: button(Icons.remove_rounded, value > min, -1)),
        SizedBox(
          width: compact ? 40 : 52,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: compact ? 16 : 20, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
        ),
        Semantics(label: 'More $label', button: true, child: button(Icons.add_rounded, value < max, 1)),
      ],
    );
  }
}

/// Coloured note with an icon (info / success / warning / error).
class Notice extends StatelessWidget {
  const Notice({super.key, required this.text, required this.icon, required this.color, required this.background});

  const Notice.error(this.text, {super.key})
      : icon = Icons.error_outline_rounded,
        color = AppColors.danger,
        background = AppColors.dangerSoft;

  const Notice.success(this.text, {super.key})
      : icon = Icons.check_circle_rounded,
        color = AppColors.success,
        background = AppColors.successSoft;

  const Notice.warning(this.text, {super.key})
      : icon = Icons.warning_amber_rounded,
        color = AppColors.warn,
        background = AppColors.warnSoft;

  final String text;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// Full-width main action that shows a spinner while busy.
class BusyButton extends StatelessWidget {
  const BusyButton({super.key, required this.label, required this.icon, required this.busy, required this.onPressed});

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
            )
          // Shrinks to fit on narrow phones / large text instead of clipping
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(icon, size: 21), const SizedBox(width: 10), Text(label, maxLines: 1)],
              ),
            ),
    );
  }
}

/// Sticky bar under a form: the amount on the left, the main action on the right.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, required this.caption, required this.amount, required this.button});

  final String caption;
  final String amount;
  final Widget button;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: Row(
        children: [
          Flexible(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(caption, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                  Text(amount, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: AppColors.forest)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(flex: 3, child: button),
        ],
      ),
    );
  }
}

/// Tappable box that looks like a text field (used for date pickers).
class PickerField extends StatelessWidget {
  const PickerField({super.key, required this.label, required this.value, required this.icon, this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.leaf),
          suffixIcon: onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          fillColor: onTap == null ? const Color(0xFFF4F6F4) : Colors.white,
        ),
        child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.ink)),
      ),
    );
  }
}

/// Selectable pill (payment type, room preference, booking type).
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({super.key, required this.label, required this.selected, required this.onTap, this.emoji, this.sub});

  final String label;
  final String? emoji;
  final String? sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.successSoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? AppColors.leaf : AppColors.line, width: selected ? 2 : 1.2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emoji != null) Text(emoji!, style: const TextStyle(fontSize: 22)),
                if (emoji != null) const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.forest : AppColors.ink,
                  ),
                ),
                if (sub != null)
                  Text(sub!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void showMessage(BuildContext context, String text, {bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: error ? AppColors.danger : AppColors.forest,
      duration: Duration(seconds: error ? 5 : 3),
    ),
  );
}

/// Label on the left, value on the right.
class KeyValueRow extends StatelessWidget {
  const KeyValueRow(this.label, this.value, {super.key, this.bold = false, this.valueColor});

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: bold ? 16 : 14,
                color: bold ? AppColors.ink : AppColors.muted,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: bold ? 18 : 14.5,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
                color: valueColor ?? (bold ? AppColors.forest : AppColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
