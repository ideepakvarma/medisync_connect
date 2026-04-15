import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // The charting library

class StatsChart extends StatelessWidget {
  final int lowCount;
  final int medCount;
  final int highCount;

  const StatsChart({
    super.key, 
    required this.lowCount, 
    required this.medCount, 
    required this.highCount
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 10, // Max height of the bars
          barGroups: [
            // Creating bars for Low, Medium, and High
            makeGroupData(0, lowCount.toDouble(), Colors.green, "Low"),
            makeGroupData(1, medCount.toDouble(), Colors.orange, "Med"),
            makeGroupData(2, highCount.toDouble(), Colors.red, "High"),
          ],
        ),
      ),
    );
  }

  // Helper function to style the bars
  BarChartGroupData makeGroupData(int x, double y, Color color, String label) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(toY: y, color: color, width: 25, borderRadius: BorderRadius.circular(4)),
      ],
    );
  }
}