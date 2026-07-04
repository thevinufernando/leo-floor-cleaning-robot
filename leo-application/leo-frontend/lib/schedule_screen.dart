import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    final backgroundColor = themeProvider.scaffoldBg;
    final cardColor = themeProvider.cardBg;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MISSION ROUTINES',
                style: TextStyle(
                  color: themeProvider.accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Automated Schedules',
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('robots')
                      .doc('LEO_001')
                      .collection('routines')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: themeProvider.accentColor,
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'No automated routines scheduled.\nLEO will only run on manual dispatches.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: subTextColor,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final item = doc.data() as Map<String, dynamic>;
                        final docId = doc.id;
                        final bool isActive = item['isActive'] ?? false;
                        final String timeStr = item['time'] ?? '00:00 AM';
                        final String daysStr = _formatDays(item['days']);
                        final String modeStr = item['mode'] ?? 'Standard Clean';

                        return Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive
                                  ? themeProvider.accentColor.withOpacity(0.15)
                                  : (themeProvider.isDarkMode
                                        ? Colors.white.withOpacity(0.02)
                                        : Colors.black.withOpacity(0.05)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time_filled_rounded,
                                color: isActive
                                    ? themeProvider.accentColor
                                    : const Color(0xFF5A6E85),
                                size: 24,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$daysStr • $modeStr',
                                      style: const TextStyle(
                                        color: Color(0xFF8E9AA6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: isActive,
                                activeColor: themeProvider.accentColor,
                                activeTrackColor: themeProvider.accentColor
                                    .withOpacity(0.2),
                                inactiveThumbColor: const Color(0xFF5A6E85),
                                inactiveTrackColor: themeProvider.isDarkMode
                                    ? const Color(0xFF101922)
                                    : const Color(0xFFCBD5E1),
                                onChanged: (value) async {
                                  await FirebaseFirestore.instance
                                      .collection('robots')
                                      .doc('LEO_001')
                                      .collection('routines')
                                      .doc(docId)
                                      .update({'isActive': value});
                                },
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent.withOpacity(0.6),
                                  size: 20,
                                ),
                                onPressed: () async {
                                  await FirebaseFirestore.instance
                                      .collection('robots')
                                      .doc('LEO_001')
                                      .collection('routines')
                                      .doc(docId)
                                      .delete();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => _showAddNewRoutinePanel(
                    context,
                    themeProvider,
                    cardColor,
                  ),
                  icon: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'Schedule New Mission',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDays(dynamic days) {
    if (days is String) return days;
    if (days is List) {
      if (days.isEmpty) return 'No Days';
      if (days.length == 7) return 'Everyday';
      final weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final List<int> sortedDays = List<int>.from(days)..sort();
      return sortedDays
          .map((d) {
            if (d >= 1 && d <= 7) return weekdayNames[d - 1];
            return '';
          })
          .where((s) => s.isNotEmpty)
          .join(', ');
    }
    return 'Everyday';
  }

  void _showAddNewRoutinePanel(
    BuildContext context,
    ThemeProvider themeProvider,
    Color cardColor,
  ) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _AddScheduleSheet(
          themeProvider: themeProvider,
          cardColor: cardColor,
        );
      },
    );

    if (result != null) {
      if (!mounted) return;
      await FirebaseFirestore.instance
          .collection('robots')
          .doc('LEO_001')
          .collection('routines')
          .add(result);
    }
  }
}

class _AddScheduleSheet extends StatefulWidget {
  final ThemeProvider themeProvider;
  final Color cardColor;

  const _AddScheduleSheet({
    required this.themeProvider,
    required this.cardColor,
  });

  @override
  State<_AddScheduleSheet> createState() => _AddScheduleSheetState();
}

class _AddScheduleSheetState extends State<_AddScheduleSheet> {
  TimeOfDay _selectedTime = TimeOfDay.now();
  final Set<int> _selectedDays = {};
  String _selectedMode = 'Auto Mode';

  final List<String> _weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final textColor = widget.themeProvider.textColor;
    final accentColor = widget.themeProvider.accentColor;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule New Mission',
              style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'TIME',
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.dark(
                          primary: accentColor,
                          onPrimary: Colors.white,
                          surface: widget.cardColor,
                          onSurface: widget.themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    _selectedTime = picked;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.themeProvider.isDarkMode
                      ? const Color(0xFF14202C)
                      : Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedTime.format(context),
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Icon(Icons.edit_calendar_rounded, color: accentColor),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'REPEAT DAYS',
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final dayVal = index + 1;
                final isSelected = _selectedDays.contains(dayVal);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedDays.remove(dayVal);
                      } else {
                        _selectedDays.add(dayVal);
                      }
                    });
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? accentColor
                          : (widget.themeProvider.isDarkMode
                                ? const Color(0xFF14202C)
                                : Colors.grey[200]),
                      border: Border.all(
                        color: isSelected ? accentColor : Colors.white10,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _weekdayLabels[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            Text(
              'SELECT CLEANING MODE',
              style: TextStyle(
                color: accentColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['Auto Mode', 'Eco Mode', 'Max Suction'].map((mode) {
                final isSelected = _selectedMode == mode;
                return ChoiceChip(
                  label: Text(
                    mode,
                    style: TextStyle(
                      color: isSelected ? Colors.white : textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: accentColor,
                  backgroundColor: widget.themeProvider.isDarkMode
                      ? const Color(0xFF14202C)
                      : Colors.grey[200],
                  checkmarkColor: Colors.white,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedMode = mode;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  final List<int> daysList = _selectedDays.toList()..sort();
                  Navigator.pop(context, {
                    'time': _selectedTime.format(context),
                    'days': daysList.isEmpty ? [1, 2, 3, 4, 5, 6, 7] : daysList,
                    'mode': _selectedMode,
                    'isActive': true,
                  });
                },
                child: const Text(
                  'Add Schedule',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
