import 'package:flutter/material.dart';
import '../../models/exam_statistics_dto.dart';

/// Виджет для отображения детальной статистики по зданиям с Yetərsay
class BuildingsStatisticsTable extends StatelessWidget {
  final List<ExamStatisticsDto> statistics;

  const BuildingsStatisticsTable({
    Key? key,
    required this.statistics,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (statistics.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              'Məlumat yoxdur',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.business,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Binalar üzrə statistika',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Table
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 20,
                  headingRowColor: MaterialStateColor.resolveWith(
                    (states) => Colors.white.withOpacity(0.05),
                  ),
                  dataRowColor: MaterialStateColor.resolveWith(
                    (states) => Colors.transparent,
                  ),
                  columns: [
                    DataColumn(
                      label: Text(
                        'Bina',
                        style: _headerStyle(),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Ad',
                        style: _headerStyle(),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Nəz. sayı',
                        style: _headerStyle(),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Qeydiyyatlı',
                        style: _headerStyle(),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Otaq sayı',
                        style: _headerStyle(),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Yetərsay',
                        style: _headerStyle(),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'İştirakçı',
                        style: _headerStyle(),
                      ),
                    ),
                  ],
                  rows: statistics.map((stat) => _buildDataRow(stat)).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(ExamStatisticsDto stat) {
    return DataRow(
      cells: [
        // Код здания
        DataCell(
          Text(
            stat.kodBina ?? '-',
            style: _cellStyle(),
          ),
        ),

        // Название здания
        DataCell(
          SizedBox(
            width: 120,
            child: Text(
              stat.adBina ?? '-',
              style: _cellStyle(),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ),

        // Всего супервизоров
        DataCell(
          Text(
            '${stat.supervisorCount ?? 0}',
            style: _cellStyle(),
          ),
        ),

        // Зарегистрированные супервизоры
        DataCell(
          Text(
            '${stat.regSupervisorCount ?? 0}',
            style: _cellStyle(
              color: (stat.regSupervisorCount ?? 0) > 0
                  ? Colors.green.shade300
                  : Colors.white70,
            ),
          ),
        ),

        // Количество залов
        DataCell(
          Text(
            '${stat.hallCount ?? 0}',
            style: _cellStyle(
              color: Colors.blue.shade300,
            ),
          ),
        ),

        // Yetərsay статус
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: stat.yetarsayIsGood
                  ? Colors.green.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: stat.yetarsayIsGood
                    ? Colors.green.withOpacity(0.5)
                    : Colors.red.withOpacity(0.5),
              ),
            ),
            child: Text(
              stat.yetarsayStatus,
              style: TextStyle(
                color: stat.yetarsayIsGood
                    ? Colors.green.shade300
                    : Colors.red.shade300,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        // Участники (зарегистрировано/всего)
        DataCell(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${stat.registeredParticipants}/${stat.totalParticipants}',
                style: _cellStyle(fontSize: 12),
              ),
              if (stat.totalParticipants > 0)
                Text(
                  '${((stat.registeredParticipants / stat.totalParticipants) * 100).toStringAsFixed(1)}%',
                  style: _cellStyle(
                    fontSize: 10,
                    color: Colors.white54,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _headerStyle() {
    return TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
  }

  TextStyle _cellStyle({Color? color, double fontSize = 13}) {
    return TextStyle(
      color: color ?? Colors.white70,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
    );
  }
}
