import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'theme_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DateTime sevenDaysAgo = DateTime.now().subtract(
    const Duration(days: 7),
  );

  String _getFormattedDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Time Unknown';
    final DateTime dt = timestamp.toDate();
    final String monthStr = dt.month.toString().padLeft(2, '0');
    final String dayStr = dt.day.toString().padLeft(2, '0');
    final String hourStr = dt.hour.toString().padLeft(2, '0');
    final String minuteStr = dt.minute.toString().padLeft(2, '0');
    return '${dt.year}-$monthStr-$dayStr $hourStr:$minuteStr';
  }

  String _getMonthName(int month) {
    final List<String> months = [
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
      'Jan',
      'Feb',
      'Mar',
    ];
    // Adjust index safely
    return months[(month - 1) % 12];
  }

  // 🗑️ Live Firestore Deletion Handler
  void _confirmDeletion(BuildContext context, String docId, String zoneName) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final cardColor = themeProvider.cardBg;
    final textColor = themeProvider.textColor;
    final subTextColor = themeProvider.subTextColor;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: themeProvider.isDarkMode ? Colors.white10 : Colors.black12,
            ),
          ),
          title: Text(
            'Delete Log Entry?',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: Text(
            'Are you sure you want to permanently delete the cleaning telemetry logs for $zoneName?',
            style: TextStyle(color: subTextColor, fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: subTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                try {
                  await FirebaseFirestore.instance
                      .collection('robots')
                      .doc('LEO_001')
                      .collection('missions')
                      .doc(docId)
                      .delete();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Log entry deleted successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting entry: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

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
                'SPATIAL TELEMETRY LOGS',
                style: TextStyle(
                  color: themeProvider.accentColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cleaning History',
                style: TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('robots')
                      .doc('LEO_001')
                      .collection('missions')
                      .orderBy('timestamp', descending: true)
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
                    final filteredDocs = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final Timestamp? ts = data['timestamp'] as Timestamp?;
                      if (ts == null) return true;
                      return ts.toDate().isAfter(sevenDaysAgo);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Text(
                          'No cleaning cycles logged\nin the last 7 days.',
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
                      itemCount: filteredDocs.length,
                      physics: const BouncingScrollPhysics(),
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final docId = doc.id;
                        final mission = doc.data() as Map<String, dynamic>;

                        final bool success = mission['isSuccess'] ?? true;
                        final Color itemAccentColor = success
                            ? Colors.greenAccent
                            : Colors.redAccent;
                        final String zoneName =
                            mission['zone'] ?? 'Unknown Area';

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () =>
                                _confirmDeletion(context, docId, zoneName),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: itemAccentColor.withOpacity(0.08),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        zoneName,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: itemAccentColor.withOpacity(
                                            0.1,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          success ? 'SUCCESS' : 'FAULT',
                                          style: TextStyle(
                                            color: itemAccentColor,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_getFormattedDate(mission['timestamp'] as Timestamp?)} • ${mission['type'] ?? 'Cycle Run'}',
                                    style: TextStyle(
                                      color: subTextColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Divider(
                                    color: themeProvider.isDarkMode
                                        ? Colors.white10
                                        : Colors.black12,
                                    height: 20,
                                    thickness: 0.5,
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.grid_on_rounded,
                                            color: themeProvider.isDarkMode
                                                ? Colors.white30
                                                : Colors.black38,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            mission['area'] ?? '-- m²',
                                            style: TextStyle(
                                              color: themeProvider.isDarkMode
                                                  ? Colors.white70
                                                  : Colors.black87,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Icon(
                                            Icons.timer_outlined,
                                            color: themeProvider.isDarkMode
                                                ? Colors.white30
                                                : Colors.black38,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            mission['duration'] ?? '-- min',
                                            style: TextStyle(
                                              color: themeProvider.isDarkMode
                                                  ? Colors.white70
                                                  : Colors.black87,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        mission['statusMessage'] ??
                                            'Processing...',
                                        style: TextStyle(
                                          color: success
                                              ? (themeProvider.isDarkMode
                                                    ? Colors.white30
                                                    : Colors.black38)
                                              : Colors.redAccent.withOpacity(
                                                  0.7,
                                                ),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
