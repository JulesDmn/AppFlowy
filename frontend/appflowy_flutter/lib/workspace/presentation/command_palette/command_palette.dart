import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:appflowy/workspace/application/command_palette/command_palette_bloc.dart';
import 'package:appflowy/workspace/presentation/command_palette/widgets/recent_views_list.dart';
import 'package:appflowy/workspace/presentation/command_palette/widgets/search_field.dart';
import 'package:appflowy/workspace/presentation/command_palette/widgets/search_results_list.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CommandPalette extends InheritedWidget {
  CommandPalette({
    super.key,
    required Widget? child,
    required ValueNotifier<bool> toggleNotifier,
  })  : _toggleNotifier = toggleNotifier,
        super(
          child: _CommandPaletteController(
            toggleNotifier: toggleNotifier,
            child: child,
          ),
        );

  final ValueNotifier<bool> _toggleNotifier;

  void toggle() => _toggleNotifier.value = !_toggleNotifier.value;

  static CommandPalette of(BuildContext context) {
    final CommandPalette? result =
        context.dependOnInheritedWidgetOfExactType<CommandPalette>();

    assert(result != null, "CommandPalette could not be found");

    return result!;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

class _ToggleCommandPaletteIntent extends Intent {
  const _ToggleCommandPaletteIntent();
}

class _CommandPaletteController extends StatefulWidget {
  const _CommandPaletteController({
    required this.toggleNotifier,
    required this.child,
  });

  final Widget? child;
  final ValueNotifier<bool> toggleNotifier;

  @override
  State<_CommandPaletteController> createState() =>
      _CommandPaletteControllerState();
}

class _CommandPaletteControllerState extends State<_CommandPaletteController> {
  late final CommandPaletteBloc _commandPaletteBloc;
  late ValueNotifier<bool> _toggleNotifier = widget.toggleNotifier;
  bool _isOpen = false;

  @override
  void didUpdateWidget(covariant _CommandPaletteController oldWidget) {
    if (oldWidget.toggleNotifier != widget.toggleNotifier) {
      _toggleNotifier.removeListener(_onToggle);
      _toggleNotifier.dispose();
      _toggleNotifier = widget.toggleNotifier;

      // If widget is changed, eg. on theme mode hotkey used
      // while modal is shown, set the value before listening
      _toggleNotifier.value = _isOpen;

      _toggleNotifier.addListener(_onToggle);
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  void initState() {
    super.initState();
    _toggleNotifier.addListener(_onToggle);
    _commandPaletteBloc = CommandPaletteBloc();
  }

  @override
  void dispose() {
    _toggleNotifier.removeListener(_onToggle);
    _toggleNotifier.dispose();
    _commandPaletteBloc.close();
    super.dispose();
  }

  void _onToggle() {
    if (widget.toggleNotifier.value && !_isOpen) {
      _isOpen = true;
      FlowyOverlay.show(
        context: context,
        builder: (_) => BlocProvider.value(
          value: _commandPaletteBloc,
          child: CommandPaletteModal(shortcutBuilder: _buildShortcut),
        ),
      ).then((_) {
        _isOpen = false;
        widget.toggleNotifier.value = false;
      });
    } else if (!widget.toggleNotifier.value && _isOpen) {
      FlowyOverlay.pop(context);
      _isOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      _buildShortcut(widget.child ?? const SizedBox.shrink());

  Widget _buildShortcut(Widget child) => FocusableActionDetector(
        actions: {
          _ToggleCommandPaletteIntent:
              CallbackAction<_ToggleCommandPaletteIntent>(
            onInvoke: (intent) =>
                _toggleNotifier.value = !_toggleNotifier.value,
          ),
        },
        shortcuts: {
          LogicalKeySet(
            PlatformExtension.isMacOS
                ? LogicalKeyboardKey.meta
                : LogicalKeyboardKey.control,
            LogicalKeyboardKey.keyP,
          ): const _ToggleCommandPaletteIntent(),
        },
        child: child,
      );
}

class CommandPaletteModal extends StatelessWidget {
  const CommandPaletteModal({super.key, required this.shortcutBuilder});

  final Widget Function(Widget) shortcutBuilder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommandPaletteBloc, CommandPaletteState>(
      builder: (context, state) {
        return FlowyDialog(
          alignment: Alignment.topCenter,
          insetPadding: const EdgeInsets.only(top: 100),
          constraints: const BoxConstraints(maxHeight: 420, maxWidth: 510),
          expandHeight: false,
          child: shortcutBuilder(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchField(query: state.query, isLoading: state.isLoading),
                if ((state.query?.isEmpty ?? true) ||
                    state.isLoading && state.results.isEmpty) ...[
                  const Divider(height: 0),
                  Flexible(
                    child: RecentViewsList(
                      onSelected: () => FlowyOverlay.pop(context),
                    ),
                  ),
                ],
                if (state.results.isNotEmpty) ...[
                  const Divider(height: 0),
                  Flexible(
                    child: SearchResultsList(results: state.results),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
