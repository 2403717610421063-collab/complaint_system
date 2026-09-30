import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/app_localizations.dart';

class AnalyticsDashboardScreen extends StatelessWidget {
  const AnalyticsDashboardScreen({super.key});

  static const Color primaryPurple = Color(0xFF4A148C);
  static const Color bgColor = Color(0xFFF6F7FB);

  // ================= PDF =================
  void _showPrintPreview(
      BuildContext context,
      int total,
      int resolved,
      int classified,
      Map<String, int> categoryCounts,
      ) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async {
        final pdf = pw.Document();

        pdf.addPage(
          pw.Page(
            pageFormat: format,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Header(level: 0, text: "City Complaint Analysis Report"),
                  pw.SizedBox(height: 12),
                  pw.Text(
                      "Official summary of public complaints and resolution status."),
                  pw.SizedBox(height: 20),

                  pw.Text("Executive Summary",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 18)),
                  pw.Divider(),
                  pw.Bullet(text: "Total Complaints: $total"),
                  pw.Bullet(text: "Resolved Successfully: $resolved"),
                  pw.Bullet(text: "Classified/Restricted: $classified"),
                  pw.Bullet(
                      text:
                      "Resolution Rate: ${total == 0 ? 0 : (resolved / total * 100).toStringAsFixed(1)}%"),
                  pw.SizedBox(height: 20),

                  pw.Text("Category Breakdown",
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold, fontSize: 18)),
                  pw.Table.fromTextArray(
                    context: context,
                    headerDecoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                    headerStyle:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    data: <List<String>>[
                      ['Category', 'Count'],
                      ...categoryCounts.entries
                          .map((e) => [e.key, e.value.toString()])
                    ],
                  ),
                  pw.Spacer(),
                  pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                        "Generated on: ${DateTime.now().toString()}"),
                  )
                ],
              );
            },
          ),
        );
        return pdf.save();
      },
    );
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
      FirebaseFirestore.instance.collection('complaints').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text("Error loading analytics")),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = snapshot.data!.docs;

        // ===== DATA PROCESSING (UNCHANGED) =====
        Map<String, int> categoryCounts = {};
        int resolved = 0;
        int inProgress = 0;
        int assigned = 0;
        int classified = 0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          String category = data['category'] ?? 'General';
          String status =
          (data['status'] ?? 'submitted').toString().toLowerCase();

          categoryCounts[category] =
              (categoryCounts[category] ?? 0) + 1;

          if (status == 'resolved') {
            resolved++;
          } else if (status == 'pending' || status == 'in progress') {
            inProgress++;
          } else if (status == 'classified') {
            classified++;
          } else {
            assigned++;
          }
        }

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)?.translate('analytics') ?? "City Analytics"),
            backgroundColor: primaryPurple,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: docs.isEmpty
                    ? null
                    : () => _showPrintPreview(
                  context,
                  docs.length,
                  resolved,
                  classified,
                  categoryCounts,
                ),
              ),
            ],
          ),
          body: docs.isEmpty
              ? const Center(child: Text("No data available"))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ===== SUMMARY CARDS =====
                Row(
                  children: [
                    _summaryTile(
                        "Total Complaints", docs.length, Icons.list),
                    _summaryTile(
                        "Resolved", resolved, Icons.check_circle),
                    _summaryTile("Classified", classified,
                        Icons.warning_amber),
                  ],
                ),
                const SizedBox(height: 20),

                // ===== BAR CHART =====
                _sectionCard(
                  title: AppLocalizations.of(context)?.translate('category') ?? "Complaints by Category",
                  child: SizedBox(
                    height: 260,
                    child: _buildBarChart(categoryCounts),
                  ),
                ),

                const SizedBox(height: 20),

                // ===== PIE CHART =====
                _sectionCard(
                  title: "Resolution Status",
                  child: SizedBox(
                    height: 260,
                    child: _buildPieChart(
                      resolved,
                      inProgress,
                      assigned,
                      classified,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ===== RATE =====
                _resolutionRateCard(docs.length, resolved),
              ],
            ),
          ),
        );
      },
    );
  }

  // ================= COMPONENTS =================
  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _summaryTile(String title, int value, IconData icon) {
    return Expanded(
      child: Card(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icon, color: primaryPurple),
              const SizedBox(height: 6),
              Text(title,
                  style: const TextStyle(color: Colors.grey)),
              Text(
                value.toString(),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryPurple),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resolutionRateCard(int total, int resolved) {
    double rate = total == 0 ? 0 : (resolved / total) * 100;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("Resolution Rate",
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("${rate.toStringAsFixed(1)}%",
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: primaryPurple)),
          ],
        ),
      ),
    );
  }

  // ================= CHARTS (UNCHANGED LOGIC) =================
  Widget _buildBarChart(Map<String, int> data) {
    List<String> categories = data.keys.toList();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: data.isEmpty
            ? 10
            : data.values.reduce((a, b) => a > b ? a : b) + 1,
        barGroups: List.generate(categories.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: data[categories[index]]!.toDouble(),
                color: primaryPurple,
                width: 20,
                borderRadius: BorderRadius.circular(6),
              )
            ],
          );
        }),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= categories.length) {
                  return const Text("");
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(categories[value.toInt()],
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true)),
          topTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
          const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }

  Widget _buildPieChart(
      int resolved, int progress, int assigned, int classified) {
    return PieChart(
      PieChartData(
        sections: [
          PieChartSectionData(
              value: resolved.toDouble(),
              color: Colors.green,
              title: 'Done'),
          PieChartSectionData(
              value: progress.toDouble(),
              color: Colors.orange,
              title: 'Active'),
          PieChartSectionData(
              value: assigned.toDouble(),
              color: Colors.blue,
              title: 'New'),
          PieChartSectionData(
              value: classified.toDouble(),
              color: Colors.redAccent,
              title: 'Classified'),
        ],
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }
}
