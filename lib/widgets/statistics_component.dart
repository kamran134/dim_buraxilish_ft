import 'package:flutter/material.dart';
import '../widgets/statistics_card.dart';

class StatisticsComponent extends StatelessWidget {
  final int allMan;
  final int allWoman;
  final int regMan;
  final int regWoman;
  final int allSupervisors;
  final int registeredSupervisors;

  const StatisticsComponent({
    Key? key,
    required this.allMan,
    required this.allWoman,
    required this.regMan,
    required this.regWoman,
    required this.allSupervisors,
    required this.registeredSupervisors,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Вычисляем общие статистики
    final totalParticipants = allMan + allWoman;
    final totalRegisteredParticipants = regMan + regWoman;
    final totalUnregisteredParticipants =
        totalParticipants - totalRegisteredParticipants;
    final unregisteredSupervisors = allSupervisors - registeredSupervisors;
    final unregisteredMen = allMan - regMan;
    final unregisteredWomen = allWoman - regWoman;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Общая статистика
          StatisticsCard(
            title: 'Ümumi statistika',
            icon: Icons.bar_chart,
            backgroundColor: const Color(0xFF677EEA).withOpacity(0.9),
            items: [
              StatisticItem(
                icon: Icons.supervisor_account,
                label: 'Nəzarətçilər',
                value: allSupervisors,
              ),
              StatisticItem(
                icon: Icons.group,
                label: 'İmtahan iştirakçıları',
                value: totalParticipants,
                subItems: [
                  StatisticItem(
                    icon: Icons.person,
                    label: 'Kişi',
                    value: allMan,
                  ),
                  StatisticItem(
                    icon: Icons.person_outline,
                    label: 'Qadın',
                    value: allWoman,
                  ),
                ],
              ),
            ],
          ),

          // Зарегистрированные
          StatisticsCard(
            title: 'Qeydiyyatdan keçənlər',
            icon: Icons.check_circle,
            backgroundColor: const Color(0xFF4CAF50).withOpacity(0.8),
            items: [
              StatisticItem(
                icon: Icons.supervisor_account,
                label: 'Nəzarətçilər',
                value: registeredSupervisors,
              ),
              StatisticItem(
                icon: Icons.group,
                label: 'İmtahan iştirakçıları',
                value: totalRegisteredParticipants,
                subItems: [
                  StatisticItem(
                    icon: Icons.person,
                    label: 'Kişi',
                    value: regMan,
                  ),
                  StatisticItem(
                    icon: Icons.person_outline,
                    label: 'Qadın',
                    value: regWoman,
                  ),
                ],
              ),
            ],
          ),

          // Незарегистрированные
          StatisticsCard(
            title: 'Qeydiyyatdan keçməyənlər',
            icon: Icons.cancel,
            backgroundColor: const Color(0xFFF44336).withOpacity(0.9),
            items: [
              StatisticItem(
                icon: Icons.supervisor_account,
                label: 'Nəzarətçilər',
                value: unregisteredSupervisors,
              ),
              StatisticItem(
                icon: Icons.group,
                label: 'İmtahan iştirakçıları',
                value: totalUnregisteredParticipants,
                subItems: [
                  StatisticItem(
                    icon: Icons.person,
                    label: 'Kişi',
                    value: unregisteredMen,
                  ),
                  StatisticItem(
                    icon: Icons.person_outline,
                    label: 'Qadın',
                    value: unregisteredWomen,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
