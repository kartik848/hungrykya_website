import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_form.dart';
import '../../widgets/common.dart';

class PanelNavItem {
  final IconData icon;
  final String label;
  final int badge;
  const PanelNavItem(this.icon, this.label, {this.badge = 0});
}

/// SaaS-style shell: dark sidebar on desktop, drawer on mobile.
class PanelShell extends StatelessWidget {
  final String roleLabel;
  final List<PanelNavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;
  final Widget body;
  const PanelShell({super.key, required this.roleLabel, required this.items, required this.selected, required this.onSelect, required this.body});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          SizedBox(width: 268, child: _Sidebar(roleLabel: roleLabel, items: items, selected: selected, onSelect: onSelect)),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: PK.sidebar,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Text(items[selected].label, style: AppTheme.body(17, color: Colors.white, weight: FontWeight.w700)),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 6), child: Pill(roleLabel, color: PK.amber)),
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded, size: 20, color: Colors.white70),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Log out?',
                message: 'Are you sure you want to log out of the panel?',
                confirm: 'Log out',
              );
              if (ok && context.mounted) {
                context.read<AuthService>().signOut();
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        width: 280,
        backgroundColor: PK.sidebar,
        child: _Sidebar(
          roleLabel: roleLabel,
          items: items,
          selected: selected,
          onSelect: (i) {
            Navigator.pop(context);
            onSelect(i);
          },
        ),
      ),
      body: body,
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String roleLabel;
  final List<PanelNavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;
  const _Sidebar({required this.roleLabel, required this.items, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Container(
      color: PK.sidebar,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
            child: Row(children: [
              const BrandLogo(size: 40, textColor: Colors.white),
              const Spacer(),
              Pill(roleLabel, color: PK.amber),
            ]),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
              for (var i = 0; i < items.length; i++) _NavTile(item: items[i], selected: i == selected, onTap: () => onSelect(i)),
            ]),
          ),
          Container(height: 1, color: Colors.white10),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: PK.amber,
                child: Text(auth.displayName.isEmpty ? '?' : auth.displayName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(auth.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(13.5, color: Colors.white, weight: FontWeight.w700)),
                  Text(auth.user?.email ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(11.5, color: Colors.white54)),
                ]),
              ),
              IconButton(
                tooltip: 'Log out',
                onPressed: () async {
                  final ok = await confirmDialog(
                    context,
                    title: 'Log out?',
                    message: 'Are you sure you want to log out of the panel?',
                    confirm: 'Log out',
                  );
                  if (ok && context.mounted) {
                    auth.signOut();
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white70, alignment: Alignment.centerLeft),
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('View store'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final PanelNavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Hoverable(
          onTap: onTap,
          builder: (h) => AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? PK.amber.withOpacity(.16) : (h ? Colors.white.withOpacity(.05) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Icon(item.icon, size: 20, color: selected ? PK.amber : Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Text(item.label,
                    style: AppTheme.body(14, color: selected ? PK.amber : Colors.white.withOpacity(.85), weight: selected ? FontWeight.w700 : FontWeight.w500)),
              ),
              if (item.badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: PK.flame, borderRadius: BorderRadius.circular(20)),
                  child: Text('${item.badge}', style: AppTheme.body(11.5, color: Colors.white, weight: FontWeight.w800)),
                ),
            ]),
          ),
        ),
      );
}

/// Scrollable page body with consistent padding and max width.
class PanelPage extends StatelessWidget {
  final List<Widget> children;
  const PanelPage({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final m = isMobile(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(m ? 16 : 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const PageHeader({super.key, required this.title, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          runSpacing: 14,
          spacing: 14,
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: AppTheme.body(isMobile(context) ? 24 : 28, color: PK.ink, weight: FontWeight.w800)),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: AppTheme.body(14, color: PK.muted)),
              ],
            ]),
            if (actions.isNotEmpty) Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ),
      );
}

class PanelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final String? title;
  final Widget? trailing;
  const PanelCard({super.key, required this.child, this.padding = const EdgeInsets.all(22), this.title, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: PK.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PK.line),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.025), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: title == null
            ? child
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(title!, style: AppTheme.body(16, color: PK.ink, weight: FontWeight.w800))),
                  if (trailing != null) trailing!,
                ]),
                const SizedBox(height: 16),
                child,
              ]),
      );
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sub;
  final VoidCallback? onTap;
  const StatCard({super.key, required this.label, required this.value, required this.icon, required this.color, this.sub, this.onTap});

  @override
  Widget build(BuildContext context) => Hoverable(
        onTap: onTap,
        builder: (h) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: PK.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: h && onTap != null ? color.withOpacity(.5) : PK.line),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(h ? .06 : .025), blurRadius: h ? 20 : 12, offset: const Offset(0, 6))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 22),
              ),
              const Spacer(),
              if (onTap != null) Icon(Icons.arrow_outward_rounded, size: 18, color: h ? color : PK.line),
            ]),
            const SizedBox(height: 16),
            Text(value, style: AppTheme.body(26, color: PK.ink, weight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: AppTheme.body(13, color: PK.muted, weight: FontWeight.w600)),
            if (sub != null) ...[
              const SizedBox(height: 6),
              Text(sub!, style: AppTheme.body(12, color: color, weight: FontWeight.w700)),
            ],
          ]),
        ),
      );
}

/// Lays children out in equal-width responsive columns.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  const ResponsiveGrid({super.key, required this.children, this.minItemWidth = 220, this.spacing = 16});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (c, cons) {
        final cols = (cons.maxWidth / minItemWidth).floor().clamp(1, 6);
        final w = (cons.maxWidth - (cols - 1) * spacing) / cols;
        return Wrap(spacing: spacing, runSpacing: spacing, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

class EmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  final Widget? action;
  const EmptyState({super.key, required this.emoji, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 20),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 54)),
          const SizedBox(height: 12),
          Text(title, style: AppTheme.body(19, color: PK.ink, weight: FontWeight.w800), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(body, style: AppTheme.body(14, color: PK.muted), textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      );
}

class PanelLogin extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool allowSignup;
  final Widget? footer;
  final String emailLabel;
  final bool showGoogle;
  const PanelLogin({
    super.key,
    required this.title,
    required this.subtitle,
    this.allowSignup = false,
    this.footer,
    this.emailLabel = 'Email',
    this.showGoogle = true,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PK.bg,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: PK.line),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 40, offset: const Offset(0, 20))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Align(alignment: Alignment.centerLeft, child: InkWell(onTap: () => context.go('/'), child: const BrandLogo(size: 44, textColor: PK.ink))),
                const SizedBox(height: 30),
                AuthForm(title: title, subtitle: subtitle, allowSignup: allowSignup, showGoogle: showGoogle, emailLabel: emailLabel),
                if (footer != null) ...[const SizedBox(height: 10), footer!],
              ]),
            ),
          ),
        ),
      );
}

/// Full-screen status message inside the panel theme.
class PanelMessage extends StatelessWidget {
  final String emoji;
  final String title;
  final String body;
  final List<Widget> actions;
  const PanelMessage({super.key, required this.emoji, required this.title, required this.body, this.actions = const []});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: PK.bg,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: PK.line)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(emoji, style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 14),
                Text(title, textAlign: TextAlign.center, style: AppTheme.body(24, color: PK.ink, weight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(body, textAlign: TextAlign.center, style: AppTheme.body(14.5, color: PK.muted, height: 1.6)),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: actions),
                ],
              ]),
            ),
          ),
        ),
      );
}
