// v1.5 — دوران زر + ليصير X عند الفتح (AnimatedRotation) + نفس منطق OverlayEntry
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FabMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const FabMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class AddFabMenu extends StatefulWidget {
  final List<FabMenuItem> items;
  const AddFabMenu({super.key, required this.items});

  @override
  State<AddFabMenu> createState() => _AddFabMenuState();
}

class _AddFabMenuState extends State<AddFabMenu> {
  OverlayEntry? _entry;
  bool _open = false;

  void _close() {
    if (_entry != null) {
      _entry!.remove();
      _entry = null;
    }
    if (mounted) setState(() => _open = false);
  }

  void _openMenu() {
    if (_entry != null) return;
    final theme = Theme.of(context);
    final overlay = Overlay.of(context);

    _entry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            // حاجز يغلق القائمة عند الضغط خارجه
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _close,
                child: Container(color: Colors.transparent),
              ),
            ),
            // العناصر مُوَسَّطة فوق زر الـ FAB
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 86), // فوق زر +
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(widget.items.length, (i) {
                        final it = widget.items[i];
                        return Padding(
                          padding: EdgeInsets.only(bottom: i == widget.items.length - 1 ? 0 : 10),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(40),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _close();
                                // تنفيذ onTap بعد إغلاق الأوفرلاي
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  Future.microtask(it.onTap);
                                });
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // شارة العنوان
                                  Material(
                                    color: theme.colorScheme.surface.withOpacity(0.95),
                                    elevation: 3,
                                    shape: const StadiumBorder(),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      child: Text(it.label),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // زر دائري صغير
                                  Material(
                                    color: theme.colorScheme.primaryContainer,
                                    shape: const CircleBorder(),
                                    elevation: 3,
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Icon(
                                        it.icon,
                                        size: 20,
                                        color: theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_entry!);
    HapticFeedback.lightImpact();
    if (mounted) setState(() => _open = true);
  }

  void _toggle() {
    if (_entry == null) {
      _openMenu();
    } else {
      _close();
    }
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // AnimatedRotation: 45° = 1/8 دورة = 0.125 turns
    return FloatingActionButton(
      onPressed: _toggle,
      child: AnimatedRotation(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutBack,
        turns: _open ? 0.125 : 0.0, // يدور 45° عند الفتح فيصير شكل X
        child: const Icon(Icons.add),
      ),
    );
  }
}
