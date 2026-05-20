import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class TimePickerButton extends StatefulWidget {
  final String label;
  final String displayValue;
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay> onTimeSelected;

  const TimePickerButton({
    super.key,
    required this.label,
    required this.displayValue,
    required this.initialTime,
    required this.onTimeSelected,
  });

  @override
  State<TimePickerButton> createState() => _TimePickerButtonState();
}

class _TimePickerButtonState extends State<TimePickerButton> {
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    _time = widget.initialTime;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: context.runninType.labelCaps.copyWith(
            color: FigmaColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: _time,
            );
            if (time != null) {
              setState(() => _time = time);
              widget.onTimeSelected(time);
            }
          },
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          child: Text(
            widget.displayValue,
            style: context.runninType.dataSm.copyWith(
              color: FigmaColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
