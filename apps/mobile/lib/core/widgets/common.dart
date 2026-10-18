import 'package:flutter/material.dart';

import '../errors/app_error.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';

class Brand extends StatelessWidget {
  const Brand({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 39,
        height: 42,
        decoration: const BoxDecoration(
          color: Tokens.accent,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(11),
            topRight: Radius.circular(11),
            bottomRight: Radius.circular(11),
            bottomLeft: Radius.circular(3),
          ),
        ),
        child: const Icon(Icons.eco_outlined, color: Tokens.pale, size: 23),
      ),
      if (!compact) ...[
        const SizedBox(width: 10),
        const Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kelompok Tani',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                'Podokoyo',
                style: TextStyle(fontSize: 12, color: Tokens.muted),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.value, {super.key});
  final String value;
  @override
  Widget build(BuildContext context) {
    final warning = value == 'NEEDS_REVIEW';
    final muted = ['VOIDED', 'CANCELLED', 'Nonaktif'].contains(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: warning
            ? Tokens.warning
            : muted
            ? Tokens.disabled
            : Tokens.badge,
        border: Border.all(
          color: warning
              ? Tokens.warningBorder
              : muted
              ? Tokens.disabledBorder
              : Tokens.badgeBorder,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusNames[value] ?? value,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.25,
          color: warning
              ? Tokens.warningText
              : muted
              ? Tokens.disabledText
              : Tokens.badgeText,
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? radius;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: Tokens.panelBorder),
      borderRadius: BorderRadius.circular(
        radius ??
            (MediaQuery.sizeOf(context).width <= 640 ? 11 : Tokens.panelRadius),
      ),
    ),
    child: child,
  );
}

class Notice extends StatelessWidget {
  const Notice(this.message, {super.key, this.error = false, this.action});
  final String message;
  final bool error;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: error ? Tokens.error : const Color(0xffeef7ef),
        border: Border.all(
          color: error ? Tokens.errorBorder : const Color(0xffd8e8dc),
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline : Icons.info_outline,
            size: 19,
            color: error ? Tokens.errorText : Tokens.accent,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: error ? Tokens.errorText : Tokens.ink,
                  ),
                ),
                ?action,
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.error, {super.key, this.retry});
  final Object error;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) {
    final mapped = AppError.from(error);
    return Notice(
      mapped.message,
      error: true,
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final issue in mapped.issues)
            Text(
              '${issue.field}: ${issue.message}',
              style: const TextStyle(color: Tokens.errorText),
            ),
          if (retry != null)
            TextButton(onPressed: retry, child: const Text('Coba lagi →')),
        ],
      ),
    );
  }
}

class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Memuat data…'),
        ],
      ),
    ),
  );
}

class Empty extends StatelessWidget {
  const Empty(this.title, {super.key, this.description, this.action});
  final String title;
  final String? description;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Icon(Icons.inventory_2_outlined, size: 30, color: Tokens.accent),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (description != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              description!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ?action,
      ],
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(
    this.title, {
    super.key,
    this.eyebrow = 'KELOLA OPERASIONAL',
    this.action,
  });
  final String title;
  final String eyebrow;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xff718b7a),
              letterSpacing: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.headlineLarge),
        ],
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 25),
        child: c.maxWidth > 640
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: heading),
                  if (action != null) ...[const SizedBox(width: 20), action!],
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  if (action != null) ...[const SizedBox(height: 22), action!],
                ],
              ),
      );
    },
  );
}

class KeyValue extends StatelessWidget {
  const KeyValue(this.label, this.value, {super.key, this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: strong ? 20 : 13,
            fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.note,
  });
  final String label;
  final String value;
  final String note;
  @override
  Widget build(BuildContext context) {
    final phone = MediaQuery.sizeOf(context).width <= 640;
    return Panel(
      padding: EdgeInsets.all(phone ? 23 : 25),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: phone ? 30 : 29,
              fontWeight: FontWeight.w600,
              letterSpacing: -1.2,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 12),
          Text(note, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final largeText =
            MediaQuery.textScalerOf(context).scale(1) >= 1.4;

        final stacked =
            action != null &&
            (constraints.maxWidth < 320 || largeText);

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: action!,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ?action,
          ],
        );
      },
    ),
  );
}

class QuickLinkCard extends StatelessWidget {
  const QuickLinkCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 118),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Tokens.panelBorder),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 24, color: const Color(0xff508a61)),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(body, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Positioned(
              right: 0,
              top: 0,
              child: Icon(
                Icons.arrow_outward,
                size: 19,
                color: Color(0xff88a18f),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class SettingRow extends StatelessWidget {
  const SettingRow(this.label, this.value, {super.key});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 10,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, color: Tokens.muted),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 14,
          child: Text(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    ),
  );
}

class RowAction extends StatelessWidget {
  const RowAction(this.label, {super.key, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Tokens.rowText,
      side: const BorderSide(color: Tokens.rowBorder),
      minimumSize: const Size(0, 44),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    child: Text(label, textAlign: TextAlign.center),
  );
}

void showSuccess(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
